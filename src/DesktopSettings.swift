import Foundation

/// Two ways of hiding the desktop icons, neither of which touches the files themselves:
/// - instantly, via the system setting "Desktop & Dock › Show Items: On Desktop", which
///   WindowManager observes live but lifts again whenever the desktop is revealed;
/// - via Finder, which then draws no desktop at all, but only notices at its next launch.
struct DesktopSettings {
    var domain = "com.apple.WindowManager"
    var finderDomain = "com.apple.finder"
    var store = UserDefaults.standard

    private static let clickToShowKey = "EnableStandardClickToShowDesktop"
    private static let finderDesktopKey = "CreateDesktop"

    // Stage Manager keeps its own pair of keys and hides desktop items by default.
    private var stageManager: Bool { bool("GloballyEnabled", default: false) }
    private var iconsKey: String { stageManager ? "HideDesktop" : "StandardHideDesktopIcons" }
    private var widgetsKey: String { stageManager ? "StageManagerHideWidgets" : "StandardHideWidgets" }

    var finderDesktopRemoved: Bool { !bool(Self.finderDesktopKey, in: finderDomain, default: true) }

    /// Whether the icons are actually off screen, which outside Stage Manager takes both keys.
    var iconsHidden: Bool {
        if finderDesktopRemoved { return true }
        guard bool(iconsKey, default: stageManager) else { return false }
        return stageManager || bool(Self.clickToShowKey, default: true)
    }

    var widgetsHidden: Bool { bool(widgetsKey, default: false) }

    /// Returns whether Finder has to be relaunched before the change shows.
    @discardableResult
    func setHidden(_ hidden: Bool, includingWidgets: Bool, viaFinder: Bool = false) -> Bool {
        let instantly = hidden && !viaFinder
        set(iconsKey, instantly)
        // macOS ignores the hide setting unless "Click wallpaper to reveal desktop" is set to
        // "Always" – it only hides items it can still bring back on a click.
        override(Self.clickToShowKey, with: true, while: instantly && !stageManager, default: true)
        override(widgetsKey, with: true, while: hidden && includingWidgets, default: false)

        let removeDesktop = hidden && viaFinder
        guard removeDesktop != finderDesktopRemoved else { return false }
        let value: CFBoolean? = removeDesktop ? kCFBooleanFalse : nil
        CFPreferencesSetAppValue(Self.finderDesktopKey as CFString, value, finderDomain as CFString)
        CFPreferencesAppSynchronize(finderDomain as CFString)
        return true
    }

    /// Forces `key` to `value` while `active` and afterwards puts back what the user had –
    /// but only if this app changed it, so settings the user chose themselves stay untouched.
    private func override(_ key: String, with value: Bool, while active: Bool, default fallback: Bool) {
        let marker = "overrode." + key
        if active, bool(key, default: fallback) != value {
            set(key, value)
            store.set(true, forKey: marker)
        } else if !active, store.bool(forKey: marker) {
            set(key, !value)
            store.removeObject(forKey: marker)
        }
    }

    private func bool(_ key: String, in domain: String? = nil, default fallback: Bool) -> Bool {
        let domain = (domain ?? self.domain) as CFString
        CFPreferencesAppSynchronize(domain)
        var exists: DarwinBoolean = false
        let value = CFPreferencesGetAppBooleanValue(key as CFString, domain, &exists)
        return exists.boolValue ? value : fallback
    }

    private func set(_ key: String, _ value: Bool) {
        CFPreferencesSetAppValue(key as CFString, value ? kCFBooleanTrue : kCFBooleanFalse, domain as CFString)
        CFPreferencesAppSynchronize(domain as CFString)
    }
}
