import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct CountpaneExportDocument: Codable, Equatable, Sendable {
    static let currentFormatVersion = 2

    let formatVersion: Int
    let exportedAt: Date
    let items: [CountdownItem]

    init(items: [CountdownItem], exportedAt: Date = .now) {
        self.formatVersion = Self.currentFormatVersion
        self.exportedAt = exportedAt
        self.items = items
    }
}

private struct CountpaneExportHeader: Decodable {
    let formatVersion: Int
}

enum CountpaneTransferError: LocalizedError, Equatable {
    case unsupportedFormat(Int)
    case duplicateIdentifier
    case emptyTitle
    case invalidThresholds(String)
    case unreadableFile

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let version):
            "This backup uses unsupported format version \(version)."
        case .duplicateIdentifier:
            "The backup contains duplicate countdown identifiers."
        case .emptyTitle:
            "Every imported countdown must have a title."
        case .invalidThresholds(let title):
            "The urgency thresholds for “\(title)” are invalid."
        case .unreadableFile:
            "The selected file could not be read."
        }
    }
}

enum CountpaneJSONTransfer {
    static func encode(items: [CountdownItem], exportedAt: Date = .now) throws -> Data {
        try JSONEncoder.configured.encode(CountpaneExportDocument(items: items, exportedAt: exportedAt))
    }

    static func decode(_ data: Data) throws -> CountpaneExportDocument {
        let header = try JSONDecoder().decode(CountpaneExportHeader.self, from: data)
        guard header.formatVersion == CountpaneExportDocument.currentFormatVersion else {
            throw CountpaneTransferError.unsupportedFormat(header.formatVersion)
        }
        let document = try JSONDecoder.configured.decode(CountpaneExportDocument.self, from: data)
        try validate(document.items)
        return document
    }

    static func validate(_ items: [CountdownItem]) throws {
        guard Set(items.map(\.id)).count == items.count else {
            throw CountpaneTransferError.duplicateIdentifier
        }

        for item in items {
            guard !item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw CountpaneTransferError.emptyTitle
            }
            guard item.almostThreshold >= 0,
                  item.hurryThreshold > item.almostThreshold,
                  item.soonThreshold > item.hurryThreshold else {
                throw CountpaneTransferError.invalidThresholds(item.title)
            }
        }
    }
}

struct CountpaneBackupFile: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data = Data()) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CountpaneTransferError.unreadableFile
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
