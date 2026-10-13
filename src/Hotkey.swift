import AppKit
import Carbon.HIToolbox

/// The global shortcut as kept in the preferences.
struct Hotkey: Equatable {
    static let standard = Hotkey(keyCode: kVK_ANSI_D, modifiers: [.control, .option, .command], key: "d")!

    let keyCode: UInt32
    let modifiers: NSEvent.ModifierFlags
    /// The key as a menu key equivalent, which is also what gets displayed.
    let key: String

    /// A shortcut registered system-wide is taken away from every other app, so anything short
    /// of two modifiers – ⌘Q, or a bare letter – is refused.
    init?(keyCode: Int, modifiers: NSEvent.ModifierFlags, key: String) {
        let pressed = Self.symbols.map(\.flag).filter(modifiers.contains)
        guard pressed.count >= 2, (0...0x7F).contains(keyCode) else { return nil }
        self.keyCode = UInt32(keyCode)
        self.modifiers = NSEvent.ModifierFlags(pressed)
        self.key = String(key.prefix(1)).lowercased()
    }

    /// Preferences can be edited from outside the app, so whatever does not validate is
    /// replaced by the standard shortcut instead of being registered.
    init(defaults: UserDefaults) {
        let modifiers = NSEvent.ModifierFlags(rawValue: UInt(bitPattern: defaults.integer(forKey: "hotkeyModifiers")))
        self = Hotkey(keyCode: defaults.integer(forKey: "hotkeyCode"), modifiers: modifiers,
                      key: defaults.string(forKey: "hotkeyKey") ?? "") ?? .standard
    }

    func save(to defaults: UserDefaults) {
        defaults.set(Int(keyCode), forKey: "hotkeyCode")
        defaults.set(Int(bitPattern: modifiers.rawValue), forKey: "hotkeyModifiers")
        defaults.set(key, forKey: "hotkeyKey")
    }

    var carbonModifiers: UInt32 {
        Self.symbols.filter { modifiers.contains($0.flag) }.reduce(0) { $0 | UInt32($1.carbon) }
    }

    /// Reads the way the menu shows it, e.g. "⌃⌥⌘D".
    var description: String {
        let keyName = Self.keyNames[Int(keyCode)] ?? key.uppercased()
        return Self.symbols.filter { modifiers.contains($0.flag) }.map(\.symbol).joined() + keyName
    }

    private static let symbols: [(flag: NSEvent.ModifierFlags, carbon: Int, symbol: String)] = [
        (.control, controlKey, "⌃"), (.option, optionKey, "⌥"), (.shift, shiftKey, "⇧"), (.command, cmdKey, "⌘"),
    ]

    // Keys whose key equivalent is not a printable character.
    private static let keyNames: [Int: String] = [
        kVK_Space: "Leertaste", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫", kVK_Escape: "⎋",
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
    ]
}
