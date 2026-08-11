import Testing
@testable import Countpane

@Suite("Countdown perimeter progress")
struct CountdownPerimeterProgressTests {
    @Test("Missing progress hides the perimeter")
    func missingProgress() {
        let value = CountdownPerimeterProgressValue(nil)

        #expect(value.normalized == nil)
        #expect(!value.showsActiveSegment)
        #expect(value.accessibilityValue == nil)
    }

    @Test("Progress keeps valid values and shows the start marker at zero")
    func validProgress() {
        let zero = CountdownPerimeterProgressValue(0)
        let partial = CountdownPerimeterProgressValue(0.5)
        let complete = CountdownPerimeterProgressValue(1)

        #expect(zero.normalized == 0)
        #expect(!zero.showsActiveSegment)
        #expect(partial.normalized == 0.5)
        #expect(partial.showsActiveSegment)
        #expect(partial.accessibilityValue == "50 percent elapsed")
        #expect(complete.normalized == 1)
        #expect(complete.showsActiveSegment)
        #expect(complete.accessibilityValue == "100 percent elapsed")
    }

    @Test("Progress is clamped to the perimeter bounds")
    func outOfRangeProgress() {
        let negative = CountdownPerimeterProgressValue(-0.25)
        let aboveComplete = CountdownPerimeterProgressValue(1.25)

        #expect(negative.normalized == 0)
        #expect(aboveComplete.normalized == 1)
    }
}
