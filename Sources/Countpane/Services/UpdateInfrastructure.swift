import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct ProcessResult: Equatable, Sendable {
    let status: Int32
    let output: String
}

enum ProcessRunnerError: LocalizedError, Equatable {
    case timedOut
    case cancelled

    var errorDescription: String? {
        switch self {
        case .timedOut: "The update command timed out. Try again after any other Homebrew task finishes."
        case .cancelled: "The update command was cancelled."
        }
    }
}

protocol ProcessExecuting: Sendable {
    func run(executable: URL, arguments: [String], timeout: TimeInterval) async throws -> ProcessResult
}

struct SafeProcessRunner: ProcessExecuting {
    func run(executable: URL, arguments: [String], timeout: TimeInterval = 180) async throws -> ProcessResult {
        let worker = Task.detached(priority: .userInitiated) {
            let outputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("countpane-process-\(UUID().uuidString).log")
            _ = FileManager.default.createFile(atPath: outputURL.path, contents: nil)
            defer { try? FileManager.default.removeItem(at: outputURL) }

            let outputHandle = try FileHandle(forWritingTo: outputURL)
            defer { try? outputHandle.close() }

            let process = Process()
            process.executableURL = executable
            process.arguments = arguments
            process.standardOutput = outputHandle
            process.standardError = outputHandle
            process.environment = ProcessInfo.processInfo.environment.merging(
                ["HOMEBREW_NO_AUTO_UPDATE": "1", "NONINTERACTIVE": "1"]
            ) { current, _ in current }

            try process.run()
            let deadline = Date().addingTimeInterval(timeout)
            while process.isRunning {
                if Task.isCancelled {
                    process.terminate()
                    process.waitUntilExit()
                    throw ProcessRunnerError.cancelled
                }
                if Date() >= deadline {
                    process.terminate()
                    process.waitUntilExit()
                    throw ProcessRunnerError.timedOut
                }
                do {
                    try await Task.sleep(for: .milliseconds(100))
                } catch {
                    process.terminate()
                    process.waitUntilExit()
                    throw ProcessRunnerError.cancelled
                }
            }

            let data = (try? Data(contentsOf: outputURL)) ?? Data()
            return ProcessResult(status: process.terminationStatus, output: String(decoding: data, as: UTF8.self))
        }

        return try await withTaskCancellationHandler {
            try await worker.value
        } onCancel: {
            worker.cancel()
        }
    }
}

protocol ReleaseChecking: Sendable {
    func latestRelease() async throws -> LatestRelease
}

final class GitHubReleaseClient: ReleaseChecking, @unchecked Sendable {
    static let latestReleaseEndpoint = URL(string: "https://github.com/sashplatonov/countpane/releases/latest")!

    private let session: URLSession
    private let endpoint: URL

    init(
        session: URLSession = .shared,
        endpoint: URL = latestReleaseEndpoint
    ) {
        self.session = session
        self.endpoint = endpoint
    }

    func latestRelease() async throws -> LatestRelease {
        var request = URLRequest(url: endpoint)
        request.timeoutInterval = 20
        request.setValue("Countpane/\(AppBuildInfo.productVersion)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw UpdateServiceError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 404 { throw UpdateServiceError.noPublishedRelease }
            throw UpdateServiceError.classifyHTTPFailure(
                statusCode: http.statusCode,
                headers: http.allHeaderFields.reduce(into: [String: String]()) { result, entry in
                    result[String(describing: entry.key)] = String(describing: entry.value)
                },
                body: data,
                now: Date()
            )
        }
        guard let resolvedURL = http.url,
              let release = LatestRelease(resolvedURL: resolvedURL) else {
            throw UpdateServiceError.invalidReleaseURL
        }
        return release
    }
}

protocol InstallationChannelDetecting: Sendable {
    func detect() async -> InstallationChannel
}

struct InstallationChannelDetector: InstallationChannelDetecting {
    let processRunner: any ProcessExecuting

    init(processRunner: any ProcessExecuting = SafeProcessRunner()) {
        self.processRunner = processRunner
    }

    func detect() async -> InstallationChannel {
        guard Bundle.main.bundleURL.pathExtension == "app" else { return .development }
        guard let brew = Self.brewExecutable else { return .dmg }
        do {
            let result = try await processRunner.run(
                executable: brew,
                arguments: ["list", "--cask", "countpane"],
                timeout: 20
            )
            return result.status == 0 ? .homebrew : .dmg
        } catch {
            return .dmg
        }
    }

    static var brewExecutable: URL? {
        ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
            .map(URL.init(fileURLWithPath:))
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }
}

protocol HomebrewUpdating: Sendable {
    func installUpdate() async throws -> String
}

struct HomebrewUpdater: HomebrewUpdating {
    let processRunner: any ProcessExecuting

    init(processRunner: any ProcessExecuting = SafeProcessRunner()) {
        self.processRunner = processRunner
    }

    func installUpdate() async throws -> String {
        guard let brew = InstallationChannelDetector.brewExecutable else {
            throw UpdateServiceError.homebrewUnavailable
        }
        let update = try await processRunner.run(executable: brew, arguments: ["update"], timeout: 180)
        guard update.status == 0 else { throw UpdateServiceError.commandFailed(Self.sanitized(update.output)) }
        let upgrade = try await processRunner.run(
            executable: brew,
            arguments: ["upgrade", "--cask", "countpane"],
            timeout: 300
        )
        guard upgrade.status == 0 else { throw UpdateServiceError.commandFailed(Self.sanitized(upgrade.output)) }
        let output = Self.sanitized(upgrade.output)
        if output.localizedCaseInsensitiveContains("already installed") ||
            output.localizedCaseInsensitiveContains("not upgrading") {
            throw UpdateServiceError.tapNotUpdated
        }
        return output
    }

    private static func sanitized(_ output: String) -> String {
        let lines = output.split(separator: "\n").suffix(12)
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}


enum UpdateServiceError: LocalizedError, Equatable {
    case invalidResponse
    case invalidReleaseURL
    case httpStatus(Int)
    case forbidden
    case rateLimited(retryAt: Date)
    case noPublishedRelease
    case invalidReleaseTag(String)
    case invalidCurrentVersion(String)
    case homebrewUnavailable
    case commandFailed(String)
    case tapNotUpdated

    static func classifyHTTPFailure(
        statusCode: Int,
        headers: [String: String],
        body: Data,
        now: Date
    ) -> UpdateServiceError {
        func header(_ name: String) -> String? {
            headers.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
        }

        let message = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any]
        let bodyMessage = (message?["message"] as? String ?? String(decoding: body, as: UTF8.self))
            .lowercased()
        let hasRateLimitEvidence = statusCode == 429 || (statusCode == 403 && (
            header("Retry-After") != nil ||
                header("X-RateLimit-Remaining")?.trimmingCharacters(in: .whitespacesAndNewlines) == "0" ||
                bodyMessage.contains("rate limit") ||
                bodyMessage.contains("rate-limit")
        ))

        guard hasRateLimitEvidence else {
            return statusCode == 403 ? .forbidden : .httpStatus(statusCode)
        }

        let retryAt: Date
        if let retryAfter = header("Retry-After"), let seconds = TimeInterval(retryAfter) {
            retryAt = now.addingTimeInterval(max(1, seconds))
        } else if let retryAfter = header("Retry-After"),
                  let date = Self.parseHTTPDate(retryAfter), date > now {
            retryAt = date
        } else if let reset = header("X-RateLimit-Reset").flatMap(TimeInterval.init),
                  Date(timeIntervalSince1970: reset) > now {
            retryAt = Date(timeIntervalSince1970: reset)
        } else {
            retryAt = now.addingTimeInterval(60)
        }
        return .rateLimited(retryAt: retryAt)
    }

    private static func parseHTTPDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
        return formatter.date(from: value)
    }

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "GitHub returned an invalid response."
        case .invalidReleaseURL: "GitHub did not redirect to a valid Countpane release."
        case .httpStatus(let code): "GitHub returned HTTP \(code). Try again later."
        case .forbidden: "GitHub denied the update check (HTTP 403). Check your network or try again later."
        case .rateLimited(let retryAt): "GitHub rate limit is active. Try again after \(retryAt.formatted(date: .omitted, time: .shortened))."
        case .noPublishedRelease: "No published Countpane release is available yet."
        case .invalidReleaseTag(let tag): "The latest release tag ‘\(tag)’ is not a semantic version."
        case .invalidCurrentVersion(let version): "This build has an invalid product version ‘\(version)’."
        case .homebrewUnavailable: "Homebrew was not found in /opt/homebrew or /usr/local."
        case .commandFailed(let output): output.isEmpty ? "Homebrew could not install the update." : output
        case .tapNotUpdated: "Homebrew does not see the new Countpane Cask yet. Wait a few minutes and try again."
        }
    }
}
