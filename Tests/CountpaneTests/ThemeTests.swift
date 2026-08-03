import Foundation
import Testing
@testable import Countpane

@Suite("Application themes")
struct AppThemeTests {
    @Test("Theme raw values remain unique")
    func uniqueRawValues() {
        let values = AppTheme.allCases.map(\.rawValue)
        #expect(Set(values).count == values.count)
    }

    @Test("Theme collection includes light, dark, and adaptive choices")
    func appearanceCoverage() {
        #expect(AppTheme.allCases.contains { $0.colorScheme == nil })
        #expect(AppTheme.allCases.contains { $0.colorScheme == .light })
        #expect(AppTheme.allCases.contains { $0.colorScheme == .dark })
    }
}
