import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class UpdateController {
    static let shared = UpdateController()

    private(set) var status: UpdateStatus = .idle
    private(set) var latestRelease: GitHubRelease?
    private(set) var installationChannel: InstallationChannel = .unknown
    private(set) var automaticChecksEnabled: Bool

    private var automaticTimer: Timer?
    private let releaseClient: any ReleaseChecking
    private let channelDetector: any InstallationChannelDetecting
    private let homebrewUpdater: any HomebrewUpdating
    private let defaults: UserDefaults
    private let now: @Sendable () -> Date
    private let currentVersion: @Sendable () -> String

    private static let repositoryURL = URL(string: "https://github.com/sashplatonov/countpane/releases/latest")!
    private static let automaticCheckInterval: TimeInterval = 6 * 60 * 60
    private static let minimumLaunchCheckInterval: TimeInterval = 60 * 60
    private static let lastCheckKey = "update.lastSuccessfulCheck"
    private static let automaticChecksKey = "update.automaticChecksEnabled"

    init(
        releaseClient: any ReleaseChecking = GitHubReleaseClient(),
        channelDetector: any InstallationChannelDetecting = InstallationChannelDetector(),
        homebrewUpdater: any HomebrewUpdating = HomebrewUpdater(),
        defaults: UserDefaults = .standard,
        now: @escaping @Sendable () -> Date = Date.init,
        currentVersion: @escaping @Sendable () -> String = { AppBuildInfo.productVersion }
    ) {
        self.releaseClient = releaseClient
        self.channelDetector = channelDetector
        self.homebrewUpdater = homebrewUpdater
        self.defaults = defaults
        self.now = now
        self.currentVersion = currentVersion
        self.automaticChecksEnabled = defaults.object(forKey: Self.automaticChecksKey) as? Bool ?? true
    }

    var statusTitle: String {
        switch status {
        case .idle: automaticChecksEnabled ? "Updates are checked automatically" : "Automatic checks are off"
        case .checking: "Checking for updates…"
        case .current: "Countpane is up to date"
        case .available(let version): "Update available: \(version)"
        case .installing: "Installing update…"
        case .installed: "Update installed. Restart Countpane."
        case .failed: "Update check failed"
        }
    }

    var statusDetail: String? {
        switch status {
        case .current(let date): "Last checked \(date.formatted(date: .omitted, time: .shortened))"
        case .failed(let message): message
        case .available:
            switch installationChannel {
            case .homebrew: "Homebrew can update Countpane in place."
            case .dmg: "Open the latest GitHub Release and replace the app from the new DMG."
            case .development: "Updates are not installed automatically for development builds."
            case .unknown: "Detecting how Countpane was installed…"
            }
        default: nil
        }
    }

    var primaryButtonTitle: String {
        switch status {
        case .available: installationChannel == .homebrew ? "Install Update" : "Open Latest Release"
        case .installed: "Restart Countpane"
        case .checking, .installing: "Please Wait…"
        default: "Check for Updates"
        }
    }

    var isBusy: Bool {
        if case .checking = status { return true }
        if case .installing = status { return true }
        return false
    }

    func setAutomaticChecksEnabled(_ enabled: Bool) {
        automaticChecksEnabled = enabled
        defaults.set(enabled, forKey: Self.automaticChecksKey)
        if enabled {
            startAutomaticChecks()
        } else {
            automaticTimer?.invalidate()
            automaticTimer = nil
            if case .idle = status { status = .idle }
        }
    }

    func startAutomaticChecks() {
        automaticTimer?.invalidate()
        automaticTimer = nil
        Task { installationChannel = await channelDetector.detect() }
        guard automaticChecksEnabled else { return }
        automaticTimer = Timer.scheduledTimer(withTimeInterval: Self.automaticCheckInterval, repeats: true) { _ in
            Task { @MainActor in await UpdateController.shared.checkForUpdates(userInitiated: false) }
        }
        Task { await checkForUpdates(userInitiated: false) }
    }

    func performPrimaryAction() {
        switch status {
        case .available:
            if installationChannel == .homebrew {
                Task { await installWithHomebrew() }
            } else {
                NSWorkspace.shared.open(latestRelease?.htmlURL ?? Self.repositoryURL)
            }
        case .installed:
            restartApplication()
        default:
            Task { await checkForUpdates(userInitiated: true) }
        }
    }

    func checkForUpdates(userInitiated: Bool) async {
        let currentTime = now()
        if !userInitiated,
           let lastCheck = defaults.object(forKey: Self.lastCheckKey) as? Date,
           currentTime.timeIntervalSince(lastCheck) < Self.minimumLaunchCheckInterval {
            return
        }

        status = .checking
        if installationChannel == .unknown {
            installationChannel = await channelDetector.detect()
        }
        do {
            let release = try await releaseClient.latestRelease()
            guard let latestVersion = release.semanticVersion else {
                throw UpdateServiceError.invalidReleaseTag(release.tagName)
            }
            let installedVersionString = currentVersion()
            guard let currentVersion = SemanticVersion(installedVersionString) else {
                throw UpdateServiceError.invalidCurrentVersion(installedVersionString)
            }
            latestRelease = release
            let checkedAt = now()
            defaults.set(checkedAt, forKey: Self.lastCheckKey)
            status = currentVersion < latestVersion
                ? .available(version: latestVersion.description)
                : .current(lastChecked: checkedAt)
        } catch {
            status = .failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    private func installWithHomebrew() async {
        status = .installing
        do {
            _ = try await homebrewUpdater.installUpdate()
            status = .installed
        } catch {
            status = .failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    private func restartApplication() {
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            status = .failed("Restart is available for the packaged Countpane.app build.")
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, error in
            Task { @MainActor in
                if let error {
                    self.status = .failed(error.localizedDescription)
                } else {
                    NSApp.terminate(nil)
                }
            }
        }
    }
}
