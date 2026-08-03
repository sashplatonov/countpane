import Foundation
import Testing
@testable import Countpane

@Suite("Countdown item coding")
struct CountdownItemCodingTests {
    @Test("Round trip preserves all user settings")
    func roundTrip() throws {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        var original = CountdownItem(
            title: "Vacation",
            targetDate: date,
            note: "Pack documents",
            symbol: "airplane",
            theme: .aurora
        )
        original.createdAt = date.addingTimeInterval(-86_400)
        original.isPinned = true
        original.soonThreshold = 21
        original.hurryThreshold = 10
        original.almostThreshold = 2
        original.attentionEnabled = false
        original.isCompleted = true
        original.completedAt = date.addingTimeInterval(3_600)

        let data = try JSONEncoder.configured.encode(original)
        let decoded = try JSONDecoder.configured.decode(CountdownItem.self, from: data)

        #expect(decoded == original)
    }

    @Test("Incomplete JSON is rejected")
    func incompleteJSONIsRejected() {
        let json = """
        {
          "title": "Incomplete",
          "targetDate": "2027-01-01T00:00:00Z"
        }
        """.data(using: .utf8)!

        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder.configured.decode(CountdownItem.self, from: json)
        }
    }

}
