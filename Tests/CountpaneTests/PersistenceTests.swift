import Foundation
import Testing
@testable import Countpane

@Suite("Countdown repository")
struct CountdownRepositoryTests {
    @Test("Saving and loading preserves items")
    func saveAndLoad() async throws {
        let location = temporaryFileURL()
        defer { try? FileManager.default.removeItem(at: location.deletingLastPathComponent()) }

        let repository = CountdownRepository(fileURL: location)
        let target = Date(timeIntervalSince1970: 1_800_000_000)
        let items = [
            CountdownItem(title: "First", targetDate: target, theme: .midnight),
            CountdownItem(title: "Second", targetDate: target.addingTimeInterval(86_400), theme: .peach)
        ]

        try await repository.save(items)
        let loaded = try await repository.load()

        #expect(loaded == items)
        #expect(FileManager.default.fileExists(atPath: location.path()))
    }

    @Test("Missing storage file loads as an empty collection")
    func missingFile() async throws {
        let location = temporaryFileURL()
        defer { try? FileManager.default.removeItem(at: location.deletingLastPathComponent()) }

        let repository = CountdownRepository(fileURL: location)
        let loaded = try await repository.load()

        #expect(loaded.isEmpty)
    }

    @Test("Malformed storage data reports a decoding error")
    func malformedFile() async throws {
        let location = temporaryFileURL()
        defer { try? FileManager.default.removeItem(at: location.deletingLastPathComponent()) }
        try Data("not-json".utf8).write(to: location)

        let repository = CountdownRepository(fileURL: location)

        await #expect(throws: DecodingError.self) {
            _ = try await repository.load()
        }
    }

    private func temporaryFileURL() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "CountpaneTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "countpane.json")
    }
}
