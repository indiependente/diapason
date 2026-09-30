import Foundation

extension ProcessInfo {
    /// True inside an XCTest host. The unit tests run in the real app process, so startup work that
    /// would prompt (Keychain access) or show modal alerts (Sparkle) must stay off there.
    static func isRunningTests(environment: [String: String] = processInfo.environment) -> Bool {
        environment.keys.contains { $0.hasPrefix("XCTest") }
    }
}
