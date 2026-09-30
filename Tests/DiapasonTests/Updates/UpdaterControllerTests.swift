@testable import Diapason
import Foundation
import Testing

@Suite("UpdaterController")
@MainActor
struct UpdaterControllerTests {
    @Test("detects an XCTest host from the environment")
    func detectsTestHost() {
        #expect(ProcessInfo.isRunningTests(environment: ["XCTestConfigurationFilePath": "/tmp/x"]))
        #expect(!ProcessInfo.isRunningTests(environment: ["HOME": "/Users/someone"]))
        #expect(ProcessInfo.isRunningTests())
    }

    @Test("start does nothing inside a test host")
    func startSkipsSparkleUnderTests() {
        let updater = UpdaterController(publicKey: "key", environment: ["XCTestConfigurationFilePath": "/tmp/x"])
        updater.start()
        #expect(!updater.isStarted)
        #expect(!updater.canCheckForUpdates)
    }

    @Test("start does nothing without a public key")
    func startSkipsSparkleWithoutKey() {
        let updater = UpdaterController(publicKey: "", environment: [:])
        updater.start()
        #expect(!updater.isStarted)
    }
}
