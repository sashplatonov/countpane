import Foundation

struct SemanticVersion: Comparable, Equatable, Sendable, CustomStringConvertible {
    let major: Int
    let minor: Int
    let patch: Int
    let prerelease: [String]

    init?(_ rawValue: String) {
        let normalized = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        let coreAndPrerelease = normalized.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        let numbers = coreAndPrerelease[0].split(separator: ".", omittingEmptySubsequences: false)
        guard numbers.count == 3,
              let major = Int(numbers[0]),
              let minor = Int(numbers[1]),
              let patch = Int(numbers[2]),
              major >= 0, minor >= 0, patch >= 0 else { return nil }
        self.major = major
        self.minor = minor
        self.patch = patch
        self.prerelease = coreAndPrerelease.count == 2
            ? coreAndPrerelease[1].split(separator: ".").map(String.init)
            : []
    }

    var description: String {
        let core = "\(major).\(minor).\(patch)"
        return prerelease.isEmpty ? core : core + "-" + prerelease.joined(separator: ".")
    }

    static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        if lhs.patch != rhs.patch { return lhs.patch < rhs.patch }
        if lhs.prerelease.isEmpty != rhs.prerelease.isEmpty { return !lhs.prerelease.isEmpty }
        for index in 0..<max(lhs.prerelease.count, rhs.prerelease.count) {
            guard index < lhs.prerelease.count else { return true }
            guard index < rhs.prerelease.count else { return false }
            let left = lhs.prerelease[index]
            let right = rhs.prerelease[index]
            if left == right { continue }
            if let leftNumber = Int(left), let rightNumber = Int(right) { return leftNumber < rightNumber }
            if Int(left) != nil { return true }
            if Int(right) != nil { return false }
            return left < right
        }
        return false
    }
}

struct LatestRelease: Sendable, Equatable {
    let tagName: String
    let htmlURL: URL

    var semanticVersion: SemanticVersion? { SemanticVersion(tagName) }

    init?(resolvedURL: URL) {
        guard resolvedURL.scheme?.lowercased() == "https",
              resolvedURL.host?.lowercased() == "github.com" else { return nil }
        let components = resolvedURL.pathComponents.filter { !$0.isEmpty && $0 != "/" }
        guard components.count == 5,
              components[0] == "sashplatonov",
              components[1] == "countpane",
              components[2] == "releases",
              components[3] == "tag",
              !components[4].isEmpty else { return nil }
        self.tagName = components[4]
        self.htmlURL = resolvedURL
    }
}

enum InstallationChannel: Equatable, Sendable {
    case unknown
    case homebrew
    case dmg
    case development
}

enum UpdateStatus: Equatable {
    case idle
    case checking
    case current(lastChecked: Date)
    case available(version: String)
    case installing
    case installed
    case failed(String)
}

