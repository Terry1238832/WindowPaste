import AppKit
import Foundation

struct TargetApp: Codable, Equatable, Identifiable, Hashable {
    var name: String
    var bundleIdentifier: String?

    var id: String {
        bundleIdentifier ?? name
    }

    static let letsView = TargetApp(
        name: "LetsView",
        bundleIdentifier: "com.wangxutech.letsview"
    )

    func matches(runningApp app: NSRunningApplication) -> Bool {
        if let bundleIdentifier, let other = app.bundleIdentifier, bundleIdentifier == other {
            return true
        }
        return app.localizedName?.caseInsensitiveCompare(name) == .orderedSame
    }

    func matches(applicationName: String?, bundleIdentifier: String?) -> Bool {
        if let expected = self.bundleIdentifier,
           let actual = bundleIdentifier,
           expected == actual {
            return true
        }
        guard let applicationName else { return false }
        if applicationName.caseInsensitiveCompare(name) == .orderedSame {
            return true
        }
        return applicationName.localizedCaseInsensitiveContains(name)
    }
}
