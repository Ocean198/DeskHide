import Foundation

/// Runs DesktopSettings against a scratch preferences domain, so the real
/// desktop is never touched. No fixtures needed; every case starts from an empty domain.
enum DesktopSettingsTests {
    static let domain = "com.sebastianscholz.DeskHide.tests"
    static let store = UserDefaults(suiteName: domain + ".store")!
    static let finderDomain = domain + ".finder"
    static let settings = DesktopSettings(domain: domain, finderDomain: finderDomain, store: store)

    static func run() {
        test("icons are visible by default") {
            expect(!settings.iconsHidden)
        }
        test("hiding and showing flips only the icon key") {
            settings.setHidden(true, includingWidgets: false)
            expect(settings.iconsHidden && raw("StandardHideDesktopIcons") == true)
            expect(raw("StandardHideWidgets") == nil && raw("EnableStandardClickToShowDesktop") == nil)
            settings.setHidden(false, includingWidgets: false)
            expect(!settings.iconsHidden)
        }
        test("the hide key alone does not count as hidden while click-to-show is off") {
            seed("EnableStandardClickToShowDesktop", false)
            seed("StandardHideDesktopIcons", true)
            expect(!settings.iconsHidden)
        }
        test("click-to-show is switched on for hiding and put back afterwards") {
            seed("EnableStandardClickToShowDesktop", false)
            settings.setHidden(true, includingWidgets: false)
            expect(settings.iconsHidden && raw("EnableStandardClickToShowDesktop") == true)
            settings.setHidden(false, includingWidgets: false)
            expect(!settings.iconsHidden && raw("EnableStandardClickToShowDesktop") == false)
        }
        test("click-to-show the user had on already stays on") {
            seed("EnableStandardClickToShowDesktop", true)
            settings.setHidden(true, includingWidgets: false)
            settings.setHidden(false, includingWidgets: false)
            expect(raw("EnableStandardClickToShowDesktop") == true)
        }
        test("widgets are hidden along with the icons and restored afterwards") {
            settings.setHidden(true, includingWidgets: true)
            expect(settings.iconsHidden && settings.widgetsHidden)
            settings.setHidden(false, includingWidgets: true)
            expect(!settings.iconsHidden && !settings.widgetsHidden)
        }
        test("widgets the user had hidden already stay hidden") {
            seed("StandardHideWidgets", true)
            settings.setHidden(true, includingWidgets: true)
            settings.setHidden(false, includingWidgets: true)
            expect(settings.widgetsHidden)
        }
        test("switching the widget option off while hidden brings widgets back") {
            settings.setHidden(true, includingWidgets: true)
            settings.setHidden(true, includingWidgets: false)
            expect(settings.iconsHidden && !settings.widgetsHidden)
        }
        test("hiding instantly never asks for a Finder relaunch") {
            expect(!settings.setHidden(true, includingWidgets: true))
            expect(!settings.setHidden(false, includingWidgets: true))
            expect(raw("CreateDesktop", in: finderDomain) == nil)
        }
        test("hiding via Finder removes its desktop and leaves the instant keys alone") {
            seed("EnableStandardClickToShowDesktop", false)
            expect(settings.setHidden(true, includingWidgets: false, viaFinder: true))
            expect(settings.iconsHidden && raw("CreateDesktop", in: finderDomain) == false)
            expect(raw("StandardHideDesktopIcons") == false && raw("EnableStandardClickToShowDesktop") == false)
            expect(!settings.setHidden(true, includingWidgets: false, viaFinder: true))  // nothing left to change
        }
        test("showing again gives Finder its desktop back") {
            settings.setHidden(true, includingWidgets: true, viaFinder: true)
            expect(settings.widgetsHidden)
            expect(settings.setHidden(false, includingWidgets: true))
            expect(!settings.iconsHidden && !settings.widgetsHidden && raw("CreateDesktop", in: finderDomain) == nil)
        }
        test("switching from instant to Finder while hidden hands over cleanly") {
            seed("EnableStandardClickToShowDesktop", false)
            settings.setHidden(true, includingWidgets: false)
            expect(settings.setHidden(true, includingWidgets: false, viaFinder: true))
            expect(settings.iconsHidden && raw("StandardHideDesktopIcons") == false)
            expect(raw("EnableStandardClickToShowDesktop") == false)
        }
        test("Stage Manager uses its own keys") {
            seed("GloballyEnabled", true)
            seed("HideDesktop", false)
            settings.setHidden(true, includingWidgets: true)
            expect(raw("HideDesktop") == true && raw("StageManagerHideWidgets") == true)
            expect(raw("StandardHideDesktopIcons") == nil && raw("StandardHideWidgets") == nil)
            expect(raw("EnableStandardClickToShowDesktop") == nil)
        }
        test("Stage Manager hides desktop items unless told otherwise") {
            seed("GloballyEnabled", true)
            expect(settings.iconsHidden)
        }

        reset()
    }

    static func test(_ name: String, _ body: () -> Void) {
        reset()
        testCase(name, body)
    }

    static func raw(_ key: String, in domain: String = domain) -> Bool? {
        CFPreferencesAppSynchronize(domain as CFString)
        return CFPreferencesCopyAppValue(key as CFString, domain as CFString) as? Bool
    }

    static func seed(_ key: String, _ value: Bool) {
        CFPreferencesSetAppValue(key as CFString, value as CFBoolean, domain as CFString)
        CFPreferencesAppSynchronize(domain as CFString)
    }

    static func reset() {
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.removePersistentDomain(forName: domain + ".store")
        UserDefaults.standard.removePersistentDomain(forName: finderDomain)
        CFPreferencesAppSynchronize(domain as CFString)
        CFPreferencesAppSynchronize(finderDomain as CFString)
    }
}
