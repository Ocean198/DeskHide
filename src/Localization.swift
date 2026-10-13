import Foundation

/// Where localized strings are looked up. The app uses its own bundle; tests and the
/// screenshot script have none and point this at a compiled `.lproj` folder instead.
var localizationBundle = Bundle.main

/// The text for `key` from `assets/Localizable.xcstrings`, in the user's language.
func L(_ key: String) -> String {
    localizationBundle.localizedString(forKey: key, value: nil, table: nil)
}

func L(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: L(key), arguments: arguments)
}
