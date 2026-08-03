import Foundation

protocol CountdownStoring: Sendable {
    func load() async throws -> [CountdownItem]
    func save(_ items: [CountdownItem]) async throws
}

actor CountdownRepository: CountdownStoring {
    private let fileURL: URL
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appending(path: "Library/Application Support", directoryHint: .isDirectory)
        fileURL = base
            .appending(path: "Countpane", directoryHint: .isDirectory)
            .appending(path: "countpane.json")
    }

    /// Test seam for using an isolated temporary storage location.
    init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
    }

    func load() throws -> [CountdownItem] {
        guard fileManager.fileExists(atPath: fileURL.path()) else { return [] }
        let data = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
        return try JSONDecoder.configured.decode([CountdownItem].self, from: data)
    }

    func save(_ items: [CountdownItem]) throws {
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder.configured.encode(items)
        try data.write(to: fileURL, options: [.atomic])
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
