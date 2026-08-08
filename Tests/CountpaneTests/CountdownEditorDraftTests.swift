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
}
