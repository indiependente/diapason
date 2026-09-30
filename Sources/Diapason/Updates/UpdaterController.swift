import Foundation
import Observation
import Sparkle

/// Thin observable wrapper around Sparkle's `SPUStandardUpdaterController`.
@Observable
@MainActor
final class UpdaterController: NSObject, SPUUpdaterDelegate {
    private(set) var canCheckForUpdates = false
    private(set) var updateAvailable = false
    private(set) var lastError: String?

    private var controller: SPUStandardUpdaterController?
    private let isEnabled: Bool

    /// Sparkle refuses to run without an EdDSA public key, and it must not start inside the
    /// unit test host either, so both cases leave the updater off.
    init(
        publicKey: String? = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        isEnabled = !(publicKey ?? "").isEmpty && !ProcessInfo.isRunningTests(environment: environment)
        super.init()
    }

    var isStarted: Bool {
        controller != nil
    }

    func start() {
        guard isEnabled, controller == nil else {
            return
        }
        let controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
        self.controller = controller
        canCheckForUpdates = controller.updater.canCheckForUpdates
    }

    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }

    nonisolated func updater(_: SPUUpdater, didFindValidUpdate _: SUAppcastItem) {
        Task { @MainActor in updateAvailable = true }
    }

    nonisolated func updaterDidNotFindUpdate(_: SPUUpdater) {
        Task { @MainActor in updateAvailable = false }
    }

    nonisolated func updater(_: SPUUpdater, didAbortWithError error: any Error) {
        Task { @MainActor in lastError = error.localizedDescription }
    }
}
