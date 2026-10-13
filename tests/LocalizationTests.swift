import Foundation

/// Guards the string catalog against the ways a translation usually breaks: a missing
/// language, a lost placeholder, a key that code and catalog disagree on. Needs the project
/// root as working directory and the catalog compiled to build/Localizations; `make test`
/// provides both.
enum LocalizationTests {
    static let languages = ["en", "de", "fr", "es", "it", "pt-BR", "ja", "zh-Hans", "ko", "ru"]

    static func run() {
        let catalog = loadCatalog()

        testCase("every text exists in all ten languages") {
            expect(!catalog.isEmpty)
            for (key, translations) in catalog.sorted(by: { $0.key < $1.key }) {
                for language in languages where (translations[language] ?? "").isEmpty {
                    fail("\(key) has no \(language) text")
                }
                for language in translations.keys where !languages.contains(language) {
                    fail("\(key) has a text for \(language), which the app does not ship")
                }
            }
        }
        testCase("placeholders survive translation") {
            for (key, translations) in catalog {
                let wanted = placeholders(in: translations["en"] ?? "")
                for (language, text) in translations where placeholders(in: text) != wanted {
                    fail("\(key) in \(language) has \(placeholders(in: text)) instead of \(wanted)")
                }
            }
        }
        testCase("code and catalog agree on the keys") {
            let used = keysUsedInSource()
            expect(!used.isEmpty)
            for key in used.subtracting(catalog.keys).sorted() { fail("\(key) is used in code but not in the catalog") }
            for key in Set(catalog.keys).subtracting(used).sorted() { fail("\(key) is in the catalog but never used") }
        }
        testCase("every language compiles into something macOS can load") {
            for language in languages {
                guard let bundle = Bundle(path: "build/Localizations/\(language).lproj") else {
                    fail("no compiled strings for \(language)")
                    continue
                }
                expect(bundle.localizedString(forKey: "menu.quit", value: nil, table: nil) == catalog["menu.quit"]?[language])
            }
        }
    }

    /// The catalog as key → language → text.
    static func loadCatalog() -> [String: [String: String]] {
        guard let data = FileManager.default.contents(atPath: "assets/Localizable.xcstrings"),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let strings = root["strings"] as? [String: [String: Any]] else { return [:] }
        return strings.mapValues { entry in
            let localizations = entry["localizations"] as? [String: [String: Any]] ?? [:]
            return localizations.compactMapValues { ($0["stringUnit"] as? [String: Any])?["value"] as? String }
        }
    }

    /// Every format specifier in order. A text that needs one but lacks it would print garbage.
    static func placeholders(in text: String) -> [String] {
        let pattern = try! NSRegularExpression(pattern: "%(\\d+\\$)?[@a-zA-Z%]")
        return pattern.matches(in: text, range: NSRange(text.startIndex..., in: text)).map { String(text[Range($0.range, in: text)!]) }
    }

    static func keysUsedInSource() -> Set<String> {
        let pattern = try! NSRegularExpression(pattern: "\\bL\\(\"([A-Za-z0-9.]+)\"")
        var keys: Set<String> = []
        for file in (try? FileManager.default.contentsOfDirectory(atPath: "src")) ?? [] where file.hasSuffix(".swift") {
            guard let source = try? String(contentsOfFile: "src/" + file, encoding: .utf8) else { continue }
            for match in pattern.matches(in: source, range: NSRange(source.startIndex..., in: source)) {
                keys.insert(String(source[Range(match.range(at: 1), in: source)!]))
            }
        }
        return keys
    }
}
