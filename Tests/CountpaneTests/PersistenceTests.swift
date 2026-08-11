import Foundation
import SQLite3
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
        #expect(FileManager.default.fileExists(atPath: location.path(percentEncoded: false)))
        let header = try Data(contentsOf: location).prefix(16)
        #expect(String(decoding: header, as: UTF8.self) == "SQLite format 3\0")
    }

    @Test("Missing storage file loads as an empty collection")
    func missingFile() async throws {
        let location = temporaryFileURL()
        defer { try? FileManager.default.removeItem(at: location.deletingLastPathComponent()) }

        let repository = CountdownRepository(fileURL: location)
        let loaded = try await repository.load()

        #expect(loaded.isEmpty)
    }

    @Test("Malformed storage data reports a database error")
    func malformedFile() async throws {
        let location = temporaryFileURL()
        defer { try? FileManager.default.removeItem(at: location.deletingLastPathComponent()) }
        try Data("not-json".utf8).write(to: location)

        let repository = CountdownRepository(fileURL: location)

        await #expect(throws: CountdownPersistenceError.self) {
            _ = try await repository.load()
        }
    }

    @Test("A failed save rolls back without replacing stored countdowns")
    func failedSaveRollsBack() async throws {
        let location = temporaryFileURL()
        defer { try? FileManager.default.removeItem(at: location.deletingLastPathComponent()) }

        let repository = CountdownRepository(fileURL: location)
        let original = CountdownItem(
            title: "Persisted",
            targetDate: Date(timeIntervalSince1970: 1_800_000_000)
        )
        try await repository.save([original])

        var duplicate = CountdownItem(
            title: "Duplicate",
            targetDate: Date(timeIntervalSince1970: 1_900_000_000)
        )
        duplicate.id = original.id

        await #expect(throws: CountdownPersistenceError.self) {
            try await repository.save([original, duplicate])
        }
        #expect(try await repository.load() == [original])
    }

    @Test("Version 1 databases canonicalize missing creation dates")
    func migratesNullableCreationDate() async throws {
        let location = temporaryFileURL()
        defer { try? FileManager.default.removeItem(at: location.deletingLastPathComponent()) }

        var database: OpaquePointer?
        #expect(sqlite3_open_v2(location.path(percentEncoded: false), &database, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE, nil) == SQLITE_OK)
        defer { sqlite3_close(database) }

        let schema = """
        CREATE TABLE countdowns (
            id TEXT PRIMARY KEY NOT NULL,
            sort_index INTEGER NOT NULL UNIQUE,
            title TEXT NOT NULL,
            target_date REAL NOT NULL,
            created_at REAL,
            note TEXT NOT NULL,
            symbol TEXT NOT NULL,
            theme TEXT NOT NULL,
            is_completed INTEGER NOT NULL CHECK (is_completed IN (0, 1)),
            completed_at REAL,
            is_pinned INTEGER NOT NULL CHECK (is_pinned IN (0, 1)),
            soon_threshold INTEGER NOT NULL,
            hurry_threshold INTEGER NOT NULL,
            almost_threshold INTEGER NOT NULL,
            attention_enabled INTEGER NOT NULL CHECK (attention_enabled IN (0, 1)),
            is_widget_visible INTEGER NOT NULL CHECK (is_widget_visible IN (0, 1))
        );
        PRAGMA user_version = 1;
        """
        #expect(sqlite3_exec(database, schema, nil, nil, nil) == SQLITE_OK)

        let id = UUID().uuidString
        let target = Date(timeIntervalSince1970: 1_900_000_000)
        let insert = """
        INSERT INTO countdowns (id, sort_index, title, target_date, created_at, note, symbol, theme, is_completed, completed_at, is_pinned, soon_threshold, hurry_threshold, almost_threshold, attention_enabled, is_widget_visible)
        VALUES ('\(id)', 0, 'Legacy', \(target.timeIntervalSinceReferenceDate), NULL, '', 'star', 'Ocean Light', 0, NULL, 0, 14, 7, 3, 1, 1);
        """
        #expect(sqlite3_exec(database, insert, nil, nil, nil) == SQLITE_OK)
        sqlite3_close(database)
        database = nil

        let loaded = try await CountdownRepository(fileURL: location).load()
        #expect(loaded.count == 1)
        #expect(loaded[0].createdAt == target)
        #expect(try await CountdownRepository(fileURL: location).load() == loaded)
    }

    private func temporaryFileURL() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "Countpane Tests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "countpane.sqlite3")
    }
}
