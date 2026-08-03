import Foundation

enum AppBuildInfo {
    static var productVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
            .flatMap { $0.isEmpty ? nil : $0 } ?? "0.0.0"
    }

    static var buildTimestamp: String {
        if let timestamp = Bundle.main.object(forInfoDictionaryKey: "CountpaneBuildTimestamp") as? String,
           !timestamp.isEmpty, timestamp != "Development" {
            return timestamp
        }
        guard let executableURL = Bundle.main.executableURL,
              let attributes = try? FileManager.default.attributesOfItem(atPath: executableURL.path),
              let modifiedAt = attributes[.modificationDate] as? Date else {
            return "Development"
        }
        return buildTimestampFormatter.string(from: modifiedAt)
    }

    static var displayVersion: String {
        buildTimestamp == "Development"
            ? "\(productVersion) · Development"
            : "\(productVersion) · Build \(buildTimestamp)"
    }

    private static let buildTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyyMMdd-HHmm"
        return formatter
    }()
}
