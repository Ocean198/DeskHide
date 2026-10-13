import AppKit

enum Finder {
    // Launched by path rather than bundle identifier: the copy on the sealed system volume
    // cannot be impersonated by another app that claims to be Finder.
    private static let url = URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")

    /// Finder only builds or drops its desktop at launch. It is asked to quit rather than
    /// killed, so it can refuse while it is busy copying – killing it would abort the copy.
    /// Returns false if Finder kept running.
    static func relaunch(timeout: TimeInterval = 5) -> Bool {
        let finders = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder")
        finders.forEach { $0.terminate() }
        // isTerminated is only updated while the run loop turns.
        let deadline = Date(timeIntervalSinceNow: timeout)
        while !finders.allSatisfy(\.isTerminated), Date() < deadline {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        }
        guard finders.allSatisfy(\.isTerminated) else { return false }

        let open = Process()
        open.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        open.arguments = ["-g", url.path]  // -g: leave the user's current app in front
        let started = (try? open.run()) != nil
        if started { open.waitUntilExit() }
        // Finder is already gone at this point, so if `open` failed, launch it the plain way.
        if !started || open.terminationStatus != 0 { NSWorkspace.shared.open(url) }
        return true
    }
}
