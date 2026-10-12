import Foundation
import Testing
@testable import Countpane

@Suite("Update check reliability")
struct UpdateReliabilityTests {
    @Test("Latest release is resolved from the GitHub latest-release redirect URL")
    func latestReleaseFromResolvedURL() throws {
        let resolvedURL = try #require(URL(string: "https://github.com/sashplatonov/countpane/releases/tag/v1.13.0"))
        let latest = try #require(LatestRelease(resolvedURL: resolvedURL))

        #expect(latest.tagName == "v1.13.0")
        #expect(latest.semanticVersion == SemanticVersion("1.13.0"))
        #expect(latest.htmlURL == resolvedURL)
        #expect(GitHubReleaseClient.latestReleaseEndpoint.host == "github.com")
        #expect(GitHubReleaseClient.latestReleaseEndpoint.path == "/sashplatonov/countpane/releases/latest")
    }

    @Test("Only confirmed rate limits are classified as rate limited")
    func classifiesRateLimitEvidence() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let reset = now.addingTimeInterval(120)

        let primary = UpdateServiceError.classifyHTTPFailure(
            statusCode: 403,
            headers: ["X-RateLimit-Remaining": "0", "X-RateLimit-Reset": String(reset.timeIntervalSince1970)],
            body: Data("{}".utf8),
            now: now
        )
        #expect(primary == .rateLimited(retryAt: reset))

        let secondary = UpdateServiceError.classifyHTTPFailure(
            statusCode: 403,
            headers: ["Retry-After": "75"],
            body: Data("{}".utf8),
            now: now
        )
        #expect(secondary == .rateLimited(retryAt: now.addingTimeInterval(75)))

        let forbidden = UpdateServiceError.classifyHTTPFailure(
            statusCode: 403,
            headers: [:],
            body: Data("Access denied".utf8),
            now: now
        )
        #expect(forbidden == .forbidden)

        let unavailable = UpdateServiceError.classifyHTTPFailure(
            statusCode: 503,
            headers: ["Retry-After": "75"],
            body: Data("Service unavailable".utf8),
            now: now
        )
        #expect(unavailable == .httpStatus(503))
    }

    @Test("Manual checks wait until the persisted rate-limit deadline")
    @MainActor
    func manualCheckHonorsPersistedRateLimit() async throws {
        let defaults = isolatedDefaults()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        defaults.set(now.addingTimeInterval(300), forKey: UpdateController.rateLimitRetryAtKey)
        let releaseCalls = CallCounter()
        let controller = UpdateController(
            releaseClient: CountingReleaseClient(counter: releaseCalls),
            channelDetector: FixedChannelDetector(channel: .development),
            homebrewUpdater: FakeHomebrewUpdater(result: .success("")),
            defaults: defaults,
            now: { now },
            currentVersion: { "1.0.0" }
        )

        await controller.checkForUpdates(userInitiated: true)

        #expect(releaseCalls.value == 0)
        guard case .failed(let message) = controller.status else {
            Issue.record("Expected a user-facing rate-limit wait state")
            return
        }
        #expect(message.localizedCaseInsensitiveContains("rate limit"))
    }

    @Test("A rate-limit response persists its retry deadline and blocks another request")
    @MainActor
    func rateLimitResponsePersistsRetryDeadline() async {
        let defaults = isolatedDefaults()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let retryAt = now.addingTimeInterval(180)
        let calls = CallCounter()
        let controller = UpdateController(
            releaseClient: RateLimitedReleaseClient(calls: calls, retryAt: retryAt),
            channelDetector: FixedChannelDetector(channel: .development),
            homebrewUpdater: FakeHomebrewUpdater(result: .success("")),
            defaults: defaults,
            now: { now },
            currentVersion: { "1.0.0" }
        )

        await controller.checkForUpdates(userInitiated: true)
        #expect(defaults.object(forKey: UpdateController.rateLimitRetryAtKey) as? Date == retryAt)
        await controller.checkForUpdates(userInitiated: true)

        #expect(calls.value == 1)
    }
}

private final class CallCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    func increment() {
        lock.lock()
        count += 1
        lock.unlock()
    }
}

private struct CountingReleaseClient: ReleaseChecking {
    let counter: CallCounter

    func latestRelease() async throws -> LatestRelease {
        counter.increment()
        return try #require(LatestRelease(resolvedURL: URL(string: "https://github.com/sashplatonov/countpane/releases/tag/v1.0.0")!))
    }
}

private struct RateLimitedReleaseClient: ReleaseChecking {
    let calls: CallCounter
    let retryAt: Date

    func latestRelease() async throws -> LatestRelease {
        calls.increment()
        throw UpdateServiceError.rateLimited(retryAt: retryAt)
    }
}

private struct FixedChannelDetector: InstallationChannelDetecting {
    let channel: InstallationChannel
    func detect() async -> InstallationChannel { channel }
}

private struct FakeHomebrewUpdater: HomebrewUpdating {
    let result: Result<String, Error>
    func installUpdate() async throws -> String { try result.get() }
}

private func isolatedDefaults() -> UserDefaults {
    let suite = "CountpaneUpdateReliability-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return defaults
}
