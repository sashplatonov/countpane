import Foundation
import Testing
@testable import Countpane

@Suite("Countdown editor draft")
struct CountdownEditorDraftTests {
    @Test("An untouched draft can close without confirmation")
    func untouchedDraft() {
        let original = CountdownItem(title: "Vacation", targetDate: .now)

        #expect(!CountdownEditorDraft.hasChanges(
            original: original,
            draft: original,
            title: original.title
        ))
    }

    @Test("Title and countdown edits require confirmation")
    func editedDraft() {
        let original = CountdownItem(title: "Vacation", targetDate: .now)
        var changedCountdown = original
        changedCountdown.isWidgetVisible = false

        #expect(CountdownEditorDraft.hasChanges(
            original: original,
            draft: original,
            title: "Summer vacation"
        ))
        #expect(CountdownEditorDraft.hasChanges(
            original: original,
            draft: changedCountdown,
            title: original.title
        ))
    }

    @Test("Saving a new countdown records its creation date")
    func newCountdownCreationDate() {
        let createdAt = Date(timeIntervalSince1970: 1_800_000_000)
        let saved = CountdownEditorDraft.itemForSaving(
            CountdownItem(title: "", targetDate: createdAt.addingTimeInterval(86_400)),
            title: "Vacation",
            isNewCountdown: true,
            now: createdAt
        )

        #expect(saved.title == "Vacation")
        #expect(saved.createdAt == createdAt)
    }

    @Test("Saving an existing legacy countdown does not invent a creation date")
    func legacyCountdownCreationDate() {
        let saved = CountdownEditorDraft.itemForSaving(
            CountdownItem(title: "Vacation", targetDate: .now),
            title: "Vacation",
            isNewCountdown: false,
            now: .now
        )

        #expect(saved.createdAt == nil)
    }
}
