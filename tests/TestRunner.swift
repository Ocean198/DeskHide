import Foundation

var failures = 0

func testCase(_ name: String, _ body: () -> Void) {
    let before = failures
    body()
    print(failures == before ? "✓" : "✗", name)
}

func expect(_ condition: Bool, file: String = #fileID, line: Int = #line) {
    guard !condition else { return }
    failures += 1
    print("  expectation failed at \(file):\(line)")
}

func fail(_ message: String) {
    failures += 1
    print("  \(message)")
}

@main
struct TestRunner {
    static func main() {
        DesktopSettingsTests.run()
        HotkeyTests.run()
        LocalizationTests.run()
        print(failures == 0 ? "All tests passed." : "\(failures) expectation(s) failed.")
        exit(failures == 0 ? 0 : 1)
    }
}
