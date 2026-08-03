import Foundation
import Testing
@testable import Countpane

@Suite("Software updates")
struct UpdateTests {
    @Test("Semantic versions compare numeric components")
    func semanticVersionComparison() throws {
        let one = try #require(SemanticVersion("v1.0.0"))
        let newer = try #require(SemanticVersion("1.1.0"))
        let ten = try #require(SemanticVersion("1.10.0"))
        let nine = try #require(SemanticVersion("1.9.0"))
        #expect(one < newer)
        #expect(ten > nine)
        #expect(SemanticVersion("1.0.0") == SemanticVersion("v1.0.0"))
    }

    @Test("Prereleases sort before final releases")
    func prereleaseComparison() throws {
        let beta = try #require(SemanticVersion("1.2.0-beta.2"))
        let final = try #require(SemanticVersion("1.2.0"))
        #expect(beta < final)
        #expect(SemanticVersion("1.2") == nil)
        #expect(SemanticVersion("release") == nil)
    }

    @Test("GitHub release decoding accepts the official payload shape")
    func releaseDecoding() throws {
        let json = """
        {
          "tag_name": "v1.2.3",
          "name": "Countpane 1.2.3",
          "html_url": "https://github.com/sashplatonov/countpane/releases/tag/v1.2.3",
          "published_at": "2026-08-03T12:00:00Z",
          "assets": []
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let release = try decoder.decode(GitHubRelease.self, from: Data(json.utf8))
        #expect(release.semanticVersion == SemanticVersion("1.2.3"))
    }

    @Test("Controller reports a newer semantic version")
    @MainActor
    func updateAvailable() async throws {
        let defaults = isolatedDefaults()
        let controller = UpdateController(
            releaseClient: FakeReleaseClient(result: .success(release("v1.1.0"))),
            channelDetector: FixedChannelDetector(channel: .dmg),
            homebrewUpdater: FakeHomebrewUpdater(result: .success("updated")),
            defaults: defaults,
            now: { Date(timeIntervalSince1970: 2_000_000_000) },
            currentVersion: { "1.0.0" }
        )
        await controller.checkForUpdates(userInitiated: true)
        #expect(controller.status == .available(version: "1.1.0"))
        #expect(controller.installationChannel == .dmg)
    }

    @Test("Equal and older releases report current")
    @MainActor
    func currentVersion() async {
        for tag in ["v1.1.0", "v1.0.9"] {
            let controller = UpdateController(
                releaseClient: FakeReleaseClient(result: .success(release(tag))),
                channelDetector: FixedChannelDetector(channel: .development),
                homebrewUpdater: FakeHomebrewUpdater(result: .success("")),
                defaults: isolatedDefaults(),
                now: { Date(timeIntervalSince1970: 2_000_000_000) },
                currentVersion: { "1.1.0" }
            )
            await controller.checkForUpdates(userInitiated: true)
            guard case .current = controller.status else {
                Issue.record("Expected current status for \(tag)")
                continue
            }
        }
    }

    @Test("Malformed release tags fail safely")
    @MainActor
    func malformedTag() async {
        let controller = UpdateController(
            releaseClient: FakeReleaseClient(result: .success(release("latest"))),
            channelDetector: FixedChannelDetector(channel: .dmg),
            homebrewUpdater: FakeHomebrewUpdater(result: .success("")),
            defaults: isolatedDefaults(),
            currentVersion: { "1.0.0" }
        )
        await controller.checkForUpdates(userInitiated: true)
        guard case .failed(let message) = controller.status else {
            Issue.record("Expected failed status")
            return
        }
        #expect(message.contains("semantic version"))
    }

    @Test("Automatic checks respect the stored opt-out")
    @MainActor
    func automaticOptOut() {
        let defaults = isolatedDefaults()
        defaults.set(true, forKey: "update.automaticChecksEnabled")
        let controller = UpdateController(
            releaseClient: FakeReleaseClient(result: .success(release("v1.0.0"))),
            channelDetector: FixedChannelDetector(channel: .dmg),
            homebrewUpdater: FakeHomebrewUpdater(result: .success("")),
            defaults: defaults
        )
        #expect(controller.automaticChecksEnabled)
        controller.setAutomaticChecksEnabled(false)
        #expect(!controller.automaticChecksEnabled)
        #expect(!defaults.bool(forKey: "update.automaticChecksEnabled"))
    }

    @Test("Homebrew update failures become user-facing states")
    @MainActor
    func homebrewFailure() async {
        let controller = UpdateController(
            releaseClient: FakeReleaseClient(result: .success(release("v2.0.0"))),
            channelDetector: FixedChannelDetector(channel: .homebrew),
            homebrewUpdater: FakeHomebrewUpdater(result: .failure(TestError.failed)),
            defaults: isolatedDefaults(),
            currentVersion: { "1.0.0" }
        )
        await controller.checkForUpdates(userInitiated: true)
        controller.performPrimaryAction()
        try? await Task.sleep(for: .milliseconds(50))
        guard case .failed = controller.status else {
            Issue.record("Expected Homebrew failure state")
            return
        }
    }
}

private struct FakeReleaseClient: ReleaseChecking, @unchecked Sendable {
    let result: Result<GitHubRelease, Error>
    func latestRelease() async throws -> GitHubRelease { try result.get() }
}

private struct FixedChannelDetector: InstallationChannelDetecting {
    let channel: InstallationChannel
    func detect() async -> InstallationChannel { channel }
}

private struct FakeHomebrewUpdater: HomebrewUpdating, @unchecked Sendable {
    let result: Result<String, Error>
    func installUpdate() async throws -> String { try result.get() }
}

private enum TestError: LocalizedError {
    case failed
    var errorDescription: String? { "Test update failed" }
}

private func release(_ tag: String) -> GitHubRelease {
    GitHubRelease(
        tagName: tag,
        name: tag,
        htmlURL: URL(string: "https://github.com/sashplatonov/countpane/releases/latest")!,
        publishedAt: Date(timeIntervalSince1970: 2_000_000_000),
        assets: []
    )
}

private func isolatedDefaults() -> UserDefaults {
    let suite = "CountpaneUpdateTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return defaults
}

@Suite("Safe process execution")
struct SafeProcessExecutionTests {
    @Test("Long-running commands time out without a pipe deadlock")
    func timeout() async {
        let runner = SafeProcessRunner()
        await #expect(throws: ProcessRunnerError.timedOut) {
            _ = try await runner.run(
                executable: URL(fileURLWithPath: "/bin/sleep"),
                arguments: ["2"],
                timeout: 0.05
            )
        }
    }
}
