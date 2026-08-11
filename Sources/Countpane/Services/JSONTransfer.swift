import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct CountpaneExportDocument: Codable, Equatable, Sendable {
    static let currentFormatVersion = 3

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
    case fileTooLarge
    case tooManyItems
    case textTooLong(String)
    case duplicateIdentifier
    case emptyTitle
    case invalidDate(String)
    case invalidCompletionState(String)
    case invalidThresholds(String)
    case unreadableFile

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let version):
            "This backup uses unsupported format version \(version)."
        case .fileTooLarge:
            "This backup is larger than the supported 10 MB limit."
        case .tooManyItems:
            "This backup contains more than 1,000 countdowns."
        case .textTooLong(let title):
            "The countdown “\(title)” contains text that is too long."
        case .duplicateIdentifier:
            "The backup contains duplicate countdown identifiers."
        case .emptyTitle:
            "Every imported countdown must have a title."
        case .invalidDate(let title):
            "The countdown “\(title)” contains an invalid date."
        case .invalidCompletionState(let title):
            "The completed state for “\(title)” is invalid."
        case .invalidThresholds(let title):
            "The urgency thresholds for “\(title)” are invalid."
        case .unreadableFile:
            "The selected file could not be read."
        }
    }
}

enum CountpaneJSONTransfer {
    static let maxBackupBytes = 10 * 1024 * 1024
    static let maxItemCount = 1_000
    static let maxTitleLength = 500
    static let maxNoteLength = 5_000

    static func encode(items: [CountdownItem], exportedAt: Date = .now) throws -> Data {
        try validate(items)
        return try JSONEncoder.configured.encode(CountpaneExportDocument(items: items, exportedAt: exportedAt))
    }

    static func decode(_ data: Data) throws -> CountpaneExportDocument {
        try validate(dataSize: data.count)
        let header = try JSONDecoder().decode(CountpaneExportHeader.self, from: data)
        guard header.formatVersion == CountpaneExportDocument.currentFormatVersion else {
            throw CountpaneTransferError.unsupportedFormat(header.formatVersion)
        }
        let document = try JSONDecoder.configured.decode(CountpaneExportDocument.self, from: data)
        try validate(document.items)
        return document
    }

    static func validate(dataSize: Int) throws {
        guard dataSize <= maxBackupBytes else { throw CountpaneTransferError.fileTooLarge }
    }

    static func validate(_ items: [CountdownItem]) throws {
        guard items.count <= maxItemCount else { throw CountpaneTransferError.tooManyItems }
        guard Set(items.map(\.id)).count == items.count else {
            throw CountpaneTransferError.duplicateIdentifier
        }

        for item in items {
            let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else {
                throw CountpaneTransferError.emptyTitle
            }
            guard title.count <= maxTitleLength, item.note.count <= maxNoteLength else {
                throw CountpaneTransferError.textTooLong(title)
            }
            guard item.targetDate.timeIntervalSinceReferenceDate.isFinite,
                  item.createdAt.timeIntervalSinceReferenceDate.isFinite,
                  item.completedAt?.timeIntervalSinceReferenceDate.isFinite ?? true else {
                throw CountpaneTransferError.invalidDate(title)
            }
            guard item.isCompleted == (item.completedAt != nil) else {
                throw CountpaneTransferError.invalidCompletionState(title)
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

extension JSONEncoder {
    static var configured: JSONEncoder {
        let value = JSONEncoder()
        value.outputFormatting = [.prettyPrinted, .sortedKeys]
        value.dateEncodingStrategy = .deferredToDate
        return value
    }
}

extension JSONDecoder {
    static var configured: JSONDecoder {
        let value = JSONDecoder()
        value.dateDecodingStrategy = .deferredToDate
        return value
    }
}
