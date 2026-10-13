import AppKit
import Carbon.HIToolbox
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let desktop = DesktopSettings()
    private let defaults = UserDefaults.standard
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let toggleItem = NSMenuItem(title: "", action: #selector(toggle), keyEquivalent: "")
    private let widgetsItem = NSMenuItem(title: "Widgets ebenfalls ausblenden", action: #selector(toggleWidgets), keyEquivalent: "")
    private let thoroughItem = NSMenuItem(title: "Vollständig ausblenden (Finder-Neustart)", action: #selector(toggleThorough), keyEquivalent: "")
    private let loginItem = NSMenuItem(title: "Beim Anmelden starten", action: #selector(toggleLogin), keyEquivalent: "")
    private let termination = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
    private var hotkey = Hotkey(defaults: .standard)
    private var hotKeyRef: EventHotKeyRef?
    private var onboarding: Onboarding?
    private var poweringOff = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        menu.delegate = self
        let hotkeyItem = NSMenuItem(title: "Tastenkürzel ändern …", action: #selector(recordHotkey), keyEquivalent: "")
        let onboardingItem = NSMenuItem(title: "Einführung anzeigen", action: #selector(showOnboarding), keyEquivalent: "")
        let quitItem = NSMenuItem(title: "DeskHide beenden", action: #selector(NSApplication.terminate), keyEquivalent: "q")
        thoroughItem.toolTip = "Hält die Symbole auch bei „Schreibtisch einblenden“ und aktiven Ecken verborgen. "
            + "Dafür startet der Finder bei jedem Umschalten kurz neu."
        for item in [toggleItem, .separator(), widgetsItem, thoroughItem, hotkeyItem, loginItem,
                     .separator(), onboardingItem, quitItem] {
            if item !== quitItem { item.target = self }
            menu.addItem(item)
        }
        statusItem.menu = menu

        // A plain `kill` would skip applicationWillTerminate and leave the icons hidden.
        signal(SIGTERM, SIG_IGN)
        termination.setEventHandler { NSApp.terminate(nil) }
        termination.resume()
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.willPowerOffNotification, object: nil,
                                                          queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.poweringOff = true }
        }

        installHotkeyHandler()
        registerHotkey()
        refreshStatus()
        if !defaults.bool(forKey: "onboardingShown") { showOnboarding() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        let finderChanged = desktop.setHidden(false, includingWidgets: false)
        // At logout Finder is on its way out anyway and picks the icons up again at the next login.
        if finderChanged, !poweringOff { _ = Finder.relaunch() }
    }

    // The settings can also be changed elsewhere, so the menu re-reads them each time it opens.
    // The login item status costs a round trip to another process, which is why it is read
    // here and not on every press of the shortcut.
    func menuWillOpen(_ menu: NSMenu) {
        refreshStatus()
        toggleItem.keyEquivalent = hotkey.key
        toggleItem.keyEquivalentModifierMask = hotkey.modifiers
        widgetsItem.state = defaults.bool(forKey: "includeWidgets") ? .on : .off
        thoroughItem.state = defaults.bool(forKey: "thorough") ? .on : .off
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    private func refreshStatus() {
        let hidden = desktop.iconsHidden
        statusItem.button?.image = NSImage(systemSymbolName: hidden ? "eye.slash" : "eye",
                                           accessibilityDescription: "Schreibtischsymbole")
        toggleItem.title = hidden ? "Schreibtischsymbole einblenden" : "Schreibtischsymbole ausblenden"
    }

    @objc private func toggle() {
        setHidden(!desktop.iconsHidden, viaFinder: defaults.bool(forKey: "thorough"))
    }

    @objc private func toggleWidgets() {
        defaults.set(!defaults.bool(forKey: "includeWidgets"), forKey: "includeWidgets")
        setHidden(desktop.iconsHidden, viaFinder: desktop.finderDesktopRemoved)
    }

    @objc private func toggleThorough() {
        setThorough(!defaults.bool(forKey: "thorough"))
    }

    @objc private func toggleLogin() {
        setLaunchAtLogin(SMAppService.mainApp.status != .enabled)
    }

    private func setThorough(_ thorough: Bool) {
        defaults.set(thorough, forKey: "thorough")
        if desktop.iconsHidden { setHidden(true, viaFinder: thorough) }
    }

    /// Returns whether the app is a login item afterwards.
    @discardableResult
    private func setLaunchAtLogin(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            alert("Anmeldeobjekt konnte nicht geändert werden", error.localizedDescription)
        }
        return SMAppService.mainApp.status == .enabled
    }

    /// Applies the wanted state and, should Finder refuse to restart, puts the previous one back.
    private func setHidden(_ hidden: Bool, viaFinder: Bool) {
        let before = (hidden: desktop.iconsHidden, viaFinder: desktop.finderDesktopRemoved)
        let widgets = defaults.bool(forKey: "includeWidgets")
        if desktop.setHidden(hidden, includingWidgets: widgets, viaFinder: viaFinder), !Finder.relaunch() {
            desktop.setHidden(before.hidden, includingWidgets: widgets, viaFinder: before.viaFinder)
            alert("Der Finder ließ sich nicht neu starten",
                  "Vermutlich läuft dort gerade ein Kopiervorgang. Die Schreibtischsymbole bleiben unverändert – "
                  + "versuch es danach noch einmal.")
        }
        refreshStatus()
    }

    @objc private func showOnboarding() {
        defaults.set(true, forKey: "onboardingShown")
        if let onboarding { return onboarding.show() }
        let onboarding = Onboarding(icon: NSApp.applicationIconImage, hotkey: hotkey.description,
                                    thorough: defaults.bool(forKey: "thorough"),
                                    launchAtLogin: SMAppService.mainApp.status == .enabled)
        onboarding.onThorough = { [weak self] in self?.setThorough($0) }
        onboarding.onLaunchAtLogin = { [weak self] in self?.setLaunchAtLogin($0) ?? false }
        // Shown once in most sessions, so the window is not kept around after it closes.
        onboarding.onClose = { [weak self] in DispatchQueue.main.async { self?.onboarding = nil } }
        self.onboarding = onboarding
        onboarding.show()
    }

    // MARK: - Hotkey

    // Carbon hotkeys work system-wide without the Accessibility permission an event tap would need.
    private func installHotkeyHandler() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
            let delegate = Unmanaged<AppDelegate>.fromOpaque(context!).takeUnretainedValue()
            MainActor.assumeIsolated { delegate.toggle() }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), nil)
    }

    private func registerHotkey() {
        unregisterHotkey()
        let id = EventHotKeyID(signature: OSType(0x4453_4B48), id: 1)  // 'DSKH'
        let status = RegisterEventHotKey(hotkey.keyCode, hotkey.carbonModifiers, id, GetApplicationEventTarget(), 0, &hotKeyRef)
        if status != noErr {
            alert("Tastenkürzel nicht verfügbar",
                  "\(hotkey.description) wird bereits von einem anderen Programm verwendet. "
                  + "Wähle über „Tastenkürzel ändern …“ eine andere Kombination.")
        }
    }

    private func unregisterHotkey() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil
    }

    @objc private func recordHotkey() {
        unregisterHotkey()  // otherwise pressing the current combination would toggle instead of being recorded
        let prompt = NSAlert()
        prompt.messageText = "Neues Tastenkürzel"
        prompt.informativeText = "Drücke die gewünschte Kombination – mit mindestens zwei der Tasten ⌃ ⌥ ⇧ ⌘."
        prompt.addButton(withTitle: "Abbrechen")
        let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let recorded = Hotkey(keyCode: Int(event.keyCode), modifiers: event.modifierFlags,
                                        key: event.charactersIgnoringModifiers ?? "") else { return event }
            self?.hotkey = recorded
            NSApp.stopModal()
            return nil
        }
        NSApp.activate(ignoringOtherApps: true)
        prompt.runModal()
        if let monitor { NSEvent.removeMonitor(monitor) }
        hotkey.save(to: defaults)
        registerHotkey()
    }

    private func alert(_ title: String, _ text: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}

let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
