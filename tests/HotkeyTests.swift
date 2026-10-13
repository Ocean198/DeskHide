import AppKit
import Carbon.HIToolbox

/// Covers what keeps a stored or recorded shortcut from being registered system-wide when it
/// should not be. Uses a scratch preferences suite; no fixtures needed.
enum HotkeyTests {
    static let suite = "com.sebastianscholz.DeskHide.tests.hotkey"

    static func run() {
        testCase("the standard shortcut is ⌃⌥⌘D") {
            expect(Hotkey.standard.description == "⌃⌥⌘D")
            expect(Hotkey.standard.carbonModifiers == UInt32(controlKey | optionKey | cmdKey))
        }
        testCase("fewer than two modifiers are refused") {
            expect(Hotkey(keyCode: kVK_ANSI_Q, modifiers: [.command], key: "q") == nil)
            expect(Hotkey(keyCode: kVK_ANSI_D, modifiers: [], key: "d") == nil)
            expect(Hotkey(keyCode: kVK_ANSI_D, modifiers: [.capsLock, .function, .shift], key: "d") == nil)
        }
        testCase("key codes outside the keyboard range are refused") {
            expect(Hotkey(keyCode: -1, modifiers: [.control, .option], key: "x") == nil)
            expect(Hotkey(keyCode: 0x80, modifiers: [.control, .option], key: "x") == nil)
        }
        testCase("flags other than the four modifiers are dropped") {
            let hotkey = Hotkey(keyCode: kVK_ANSI_H, modifiers: [.shift, .command, .capsLock, .numericPad], key: "Hx")
            expect(hotkey?.modifiers == [.shift, .command] && hotkey?.key == "h")
            expect(hotkey?.description == "⇧⌘H")
        }
        testCase("keys without a printable character get a name") {
            expect(Hotkey(keyCode: kVK_Space, modifiers: [.control, .option], key: " ")?.description == "⌃⌥Leertaste")
            expect(Hotkey(keyCode: kVK_F5, modifiers: [.option, .command], key: "\u{F708}")?.description == "⌥⌘F5")
        }
        testCase("a recorded shortcut survives saving and loading") {
            let defaults = scratchDefaults()
            let recorded = Hotkey(keyCode: kVK_ANSI_H, modifiers: [.shift, .command], key: "h")!
            recorded.save(to: defaults)
            expect(Hotkey(defaults: defaults) == recorded)
        }
        testCase("empty preferences give the standard shortcut") {
            expect(Hotkey(defaults: scratchDefaults()) == .standard)
        }
        testCase("tampered preferences fall back to the standard shortcut") {
            let defaults = scratchDefaults()
            for (code, modifiers): (Any, Any) in [(-1, -1), (kVK_ANSI_D, 0), (Int.max, Int.min), ("d", "all"), (kVK_ANSI_D, 1 << 20)] {
                defaults.set(code, forKey: "hotkeyCode")
                defaults.set(modifiers, forKey: "hotkeyModifiers")
                expect(Hotkey(defaults: defaults) == .standard)
            }
        }
        UserDefaults.standard.removePersistentDomain(forName: suite)
    }

    static func scratchDefaults() -> UserDefaults {
        UserDefaults.standard.removePersistentDomain(forName: suite)
        return UserDefaults(suiteName: suite)!
    }
}
