import Foundation
import Testing
@testable import Countpane

@Suite("Review regressions")
struct ReviewRegressionTests {
    @Test("Repository creates a missing parent directory")
    func repositoryCreatesParentDirectory() async throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "CountdownsRepositoryParent-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root
            .appending(path: "Nested", directoryHint: .isDirectory)
            .appending(path: "countpane.json")
        let repository = CountdownRepository(fileURL: file)
        let item = CountdownItem(title: "Created", targetDate: .now)

        try await repository.save([item])

        #expect(FileManager.default.fileExists(atPath: file.path()))
        #expect(try await repository.load() == [item])
    }
}
