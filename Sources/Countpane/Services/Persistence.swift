import Foundation
import SQLite3

protocol CountdownStoring: Sendable {
    func load() async throws -> [CountdownItem]
    func save(_ items: [CountdownItem]) async throws
}

enum CountdownPersistenceError: LocalizedError {
    case database(String)
    case invalidRecord(String)

    var errorDescription: String? {
        switch self {
        case .database(let message):
            "Countdown database error: \(message)"
        case .invalidRecord(let message):
            "Invalid countdown database record: \(message)"
        }
    }
}

actor CountdownRepository: CountdownStoring {
    private static let schema = """
        CREATE TABLE IF NOT EXISTS countdowns (
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
        """

    private let databaseURL: URL
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appending(path: "Library/Application Support", directoryHint: .isDirectory)
        databaseURL = base
            .appending(path: "Countpane", directoryHint: .isDirectory)
            .appending(path: "countpane.sqlite3")
    }

    init(fileURL: URL, fileManager: FileManager = .default) {
        self.databaseURL = fileURL
        self.fileManager = fileManager
    }

    func load() throws -> [CountdownItem] {
        try withDatabase { database in
            let sql = """
                SELECT id, title, target_date, created_at, note, symbol, theme,
                       is_completed, completed_at, is_pinned, soon_threshold,
                       hurry_threshold, almost_threshold, attention_enabled,
                       is_widget_visible
                FROM countdowns
                ORDER BY sort_index ASC;
                """
            let statement = try prepare(sql, in: database)
            defer { sqlite3_finalize(statement) }

            var items: [CountdownItem] = []
            while true {
                switch sqlite3_step(statement) {
                case SQLITE_ROW:
                    items.append(try decodeItem(from: statement))
                case SQLITE_DONE:
                    return items
                default:
                    throw databaseError(database)
                }
            }
        }
    }

    func save(_ items: [CountdownItem]) throws {
        try withDatabase { database in
            try execute("BEGIN IMMEDIATE TRANSACTION;", in: database)
            do {
                try execute("DELETE FROM countdowns;", in: database)
                let statement = try prepare(
                    """
                    INSERT INTO countdowns (
                        id, sort_index, title, target_date, created_at, note,
                        symbol, theme, is_completed, completed_at, is_pinned,
                        soon_threshold, hurry_threshold, almost_threshold,
                        attention_enabled, is_widget_visible
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
                    """,
                    in: database
                )
                defer { sqlite3_finalize(statement) }

                for (index, item) in items.enumerated() {
                    sqlite3_reset(statement)
                    sqlite3_clear_bindings(statement)
                    try bind(item, at: index, to: statement, database: database)
                    guard sqlite3_step(statement) == SQLITE_DONE else {
                        throw databaseError(database)
                    }
                }
                try execute("COMMIT;", in: database)
            } catch {
                try? execute("ROLLBACK;", in: database)
                throw error
            }
        }
    }

    private func withDatabase<T>(_ body: (OpaquePointer) throws -> T) throws -> T {
        try fileManager.createDirectory(
            at: databaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var connection: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(databaseURL.path(), &connection, flags, nil) == SQLITE_OK,
              let connection else {
            let message = connection.map { String(cString: sqlite3_errmsg($0)) } ?? "Unable to open database."
            if let connection { sqlite3_close(connection) }
            throw CountdownPersistenceError.database(message)
        }
        defer { sqlite3_close(connection) }

        try execute("PRAGMA journal_mode = WAL;", in: connection)
        try execute("PRAGMA synchronous = FULL;", in: connection)
        try execute(Self.schema, in: connection)
        try execute("PRAGMA user_version = 1;", in: connection)
        return try body(connection)
    }

    private func execute(_ sql: String, in database: OpaquePointer) throws {
        var errorMessage: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(database, sql, nil, nil, &errorMessage) == SQLITE_OK else {
            let message = errorMessage.map { String(cString: $0) }
                ?? String(cString: sqlite3_errmsg(database))
            sqlite3_free(errorMessage)
            throw CountdownPersistenceError.database(message)
        }
    }

    private func prepare(_ sql: String, in database: OpaquePointer) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            throw databaseError(database)
        }
        return statement
    }

    private func bind(
        _ item: CountdownItem,
        at index: Int,
        to statement: OpaquePointer,
        database: OpaquePointer
    ) throws {
        try bindText(item.id.uuidString, index: 1, statement: statement, database: database)
        try check(sqlite3_bind_int64(statement, 2, Int64(index)), database)
        try bindText(item.title, index: 3, statement: statement, database: database)
        try check(sqlite3_bind_double(statement, 4, item.targetDate.timeIntervalSinceReferenceDate), database)
        try bindDate(item.createdAt, index: 5, statement: statement, database: database)
        try bindText(item.note, index: 6, statement: statement, database: database)
        try bindText(item.symbol, index: 7, statement: statement, database: database)
        try bindText(item.theme.rawValue, index: 8, statement: statement, database: database)
        try bindBool(item.isCompleted, index: 9, statement: statement, database: database)
        try bindDate(item.completedAt, index: 10, statement: statement, database: database)
        try bindBool(item.isPinned, index: 11, statement: statement, database: database)
        try check(sqlite3_bind_int64(statement, 12, Int64(item.soonThreshold)), database)
        try check(sqlite3_bind_int64(statement, 13, Int64(item.hurryThreshold)), database)
        try check(sqlite3_bind_int64(statement, 14, Int64(item.almostThreshold)), database)
        try bindBool(item.attentionEnabled, index: 15, statement: statement, database: database)
        try bindBool(item.isWidgetVisible, index: 16, statement: statement, database: database)
    }

    private func bindText(
        _ value: String,
        index: Int32,
        statement: OpaquePointer,
        database: OpaquePointer
    ) throws {
        let result = value.withCString { pointer in
            sqlite3_bind_text(statement, index, pointer, -1, sqliteTransient)
        }
        try check(result, database)
    }

    private func bindDate(
        _ value: Date?,
        index: Int32,
        statement: OpaquePointer,
        database: OpaquePointer
    ) throws {
        let result = value.map {
            sqlite3_bind_double(statement, index, $0.timeIntervalSinceReferenceDate)
        } ?? sqlite3_bind_null(statement, index)
        try check(result, database)
    }

    private func bindBool(
        _ value: Bool,
        index: Int32,
        statement: OpaquePointer,
        database: OpaquePointer
    ) throws {
        try check(sqlite3_bind_int(statement, index, value ? 1 : 0), database)
    }

    private func check(_ result: Int32, _ database: OpaquePointer) throws {
        guard result == SQLITE_OK else { throw databaseError(database) }
    }

    private func decodeItem(from statement: OpaquePointer) throws -> CountdownItem {
        guard let identifierText = text(at: 0, from: statement),
              let identifier = UUID(uuidString: identifierText),
              let title = text(at: 1, from: statement),
              let note = text(at: 4, from: statement),
              let symbol = text(at: 5, from: statement),
              let themeText = text(at: 6, from: statement),
              let theme = CountdownTheme(rawValue: themeText) else {
            throw CountdownPersistenceError.invalidRecord("Missing or invalid required value.")
        }

        return CountdownItem(
            id: identifier,
            title: title,
            targetDate: Date(timeIntervalSinceReferenceDate: sqlite3_column_double(statement, 2)),
            createdAt: date(at: 3, from: statement),
            note: note,
            symbol: symbol,
            theme: theme,
            isCompleted: sqlite3_column_int(statement, 7) != 0,
            completedAt: date(at: 8, from: statement),
            isPinned: sqlite3_column_int(statement, 9) != 0,
            soonThreshold: Int(sqlite3_column_int64(statement, 10)),
            hurryThreshold: Int(sqlite3_column_int64(statement, 11)),
            almostThreshold: Int(sqlite3_column_int64(statement, 12)),
            attentionEnabled: sqlite3_column_int(statement, 13) != 0,
            isWidgetVisible: sqlite3_column_int(statement, 14) != 0
        )
    }

    private func text(at index: Int32, from statement: OpaquePointer) -> String? {
        sqlite3_column_text(statement, index).map { String(cString: $0) }
    }

    private func date(at index: Int32, from statement: OpaquePointer) -> Date? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else { return nil }
        return Date(timeIntervalSinceReferenceDate: sqlite3_column_double(statement, index))
    }

    private func databaseError(_ database: OpaquePointer) -> CountdownPersistenceError {
        .database(String(cString: sqlite3_errmsg(database)))
    }
}

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
