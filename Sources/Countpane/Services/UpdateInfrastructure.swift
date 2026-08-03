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
        try await Task.detached(priority: .userInitiated) {
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
        }.value
    }
}

protocol ReleaseChecking: Sendable {
    func latestRelease() async throws -> GitHubRelease
}

final class GitHubReleaseClient: ReleaseChecking, @unchecked Sendable {
    private let session: URLSession
    private let endpoint: URL

    init(
        session: URLSession = .shared,
        endpoint: URL = URL(string: "https://api.github.com/repos/sashplatonov/countpane/releases/latest")!
    ) {
        self.session = session
        self.endpoint = endpoint
    }

    func latestRelease() async throws -> GitHubRelease {
        var request = URLRequest(url: endpoint)
        request.timeoutInterval = 20
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("Countpane/\(AppBuildInfo.productVersion)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw UpdateServiceError.invalidResponse }
        switch http.statusCode {
        case 200: break
        case 403: throw UpdateServiceError.rateLimited
        case 404: throw UpdateServiceError.noPublishedRelease
        default: throw UpdateServiceError.httpStatus(http.statusCode)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(GitHubRelease.self, from: data)
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


enum UpdateServiceError: LocalizedError {
    case invalidResponse
    case httpStatus(Int)
    case rateLimited
    case noPublishedRelease
    case invalidReleaseTag(String)
    case invalidCurrentVersion(String)
    case homebrewUnavailable
    case commandFailed(String)
    case tapNotUpdated

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "GitHub returned an invalid response."
        case .httpStatus(let code): "GitHub returned HTTP \(code). Try again later."
        case .rateLimited: "GitHub temporarily limited update checks. Try again later."
        case .noPublishedRelease: "No published Countpane release is available yet."
        case .invalidReleaseTag(let tag): "The latest release tag ‘\(tag)’ is not a semantic version."
        case .invalidCurrentVersion(let version): "This build has an invalid product version ‘\(version)’."
        case .homebrewUnavailable: "Homebrew was not found in /opt/homebrew or /usr/local."
        case .commandFailed(let output): output.isEmpty ? "Homebrew could not install the update." : output
        case .tapNotUpdated: "Homebrew does not see the new Countpane Cask yet. Wait a few minutes and try again."
        }
    }
}

