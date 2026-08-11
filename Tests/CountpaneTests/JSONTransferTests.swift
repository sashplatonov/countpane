import Foundation
import Testing
@testable import Countpane

@Suite("JSON import and export")
struct JSONTransferTests {
    @Test("Export round trip preserves current-schema countdowns")
    func roundTrip() throws {
        let exportedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let items = [
            CountdownItem(title: "Launch", targetDate: exportedAt.addingTimeInterval(86_400), note: "Ship it", theme: .midnight),
            CountdownItem(title: "Trip", targetDate: exportedAt.addingTimeInterval(172_800), symbol: "airplane", theme: .peach)
        ]

        let data = try CountpaneJSONTransfer.encode(items: items, exportedAt: exportedAt)
        let decoded = try CountpaneJSONTransfer.decode(data)

        #expect(decoded.formatVersion == 3)
        #expect(decoded.exportedAt == exportedAt)
        #expect(decoded.items == items)
    }

    @Test("Unsupported export versions are rejected")
    func unsupportedVersion() throws {
        let json = """
        {
          "formatVersion": 1,
          "exportedAt": "2027-01-15T08:00:00Z",
          "items": []
        }
        """

        #expect(throws: CountpaneTransferError.unsupportedFormat(1)) {
            _ = try CountpaneJSONTransfer.decode(Data(json.utf8))
        }
    }

    @Test("Duplicate countdown identifiers are rejected")
    func duplicateIdentifiers() throws {
        let id = UUID()
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let items = [
            CountdownItem(id: id, title: "One", targetDate: date),
            CountdownItem(id: id, title: "Two", targetDate: date)
        ]

        #expect(throws: CountpaneTransferError.duplicateIdentifier) {
            try CountpaneJSONTransfer.validate(items)
        }
    }

    @Test("Empty titles and invalid urgency thresholds are rejected")
    func invalidItems() throws {
        let date = Date(timeIntervalSince1970: 1_800_000_000)

        #expect(throws: CountpaneTransferError.emptyTitle) {
            try CountpaneJSONTransfer.validate([CountdownItem(title: "   ", targetDate: date)])
        }

        let invalid = CountdownItem(
            title: "Invalid",
            targetDate: date,
            soonThreshold: 7,
            hurryThreshold: 7,
            almostThreshold: 3
        )
        #expect(throws: CountpaneTransferError.invalidThresholds("Invalid")) {
            try CountpaneJSONTransfer.validate([invalid])
        }
    }

    @Test("Import boundaries reject oversized and semantically invalid data")
    func importBoundaries() throws {
        #expect(throws: CountpaneTransferError.fileTooLarge) {
            try CountpaneJSONTransfer.validate(dataSize: CountpaneJSONTransfer.maxBackupBytes + 1)
        }

        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let tooMany = (0...CountpaneJSONTransfer.maxItemCount).map {
            CountdownItem(title: "Item \($0)", targetDate: date)
        }
        #expect(throws: CountpaneTransferError.tooManyItems) {
            try CountpaneJSONTransfer.validate(tooMany)
        }

        let longTitle = String(repeating: "x", count: CountpaneJSONTransfer.maxTitleLength + 1)
        #expect(throws: CountpaneTransferError.textTooLong(longTitle)) {
            try CountpaneJSONTransfer.validate([CountdownItem(title: longTitle, targetDate: date)])
        }

        let nonFinite = CountdownItem(title: "Invalid date", targetDate: Date(timeIntervalSinceReferenceDate: .infinity))
        #expect(throws: CountpaneTransferError.invalidDate("Invalid date")) {
            try CountpaneJSONTransfer.validate([nonFinite])
        }

        var inconsistent = CountdownItem(title: "Incomplete", targetDate: date)
        inconsistent.isCompleted = true
        #expect(throws: CountpaneTransferError.invalidCompletionState("Incomplete")) {
            try CountpaneJSONTransfer.validate([inconsistent])
        }
    }

    @Test("Replacing data persists first and then updates the model")
    @MainActor
    func replaceAll() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "CountpaneImportTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        let location = directory.appending(path: "countpane.sqlite3")
        defer { try? FileManager.default.removeItem(at: directory) }

        let repository = CountdownRepository(fileURL: location)
        let model = AppModel(repository: repository)
        let imported = [CountdownItem(title: "Imported", targetDate: Date(timeIntervalSince1970: 1_900_000_000))]

        try await model.replaceAll(with: imported)

        #expect(model.items == imported)
        #expect(try await repository.load() == imported)
    }
}
