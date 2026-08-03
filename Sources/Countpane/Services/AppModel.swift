import Foundation
import Observation

struct UndoNotice: Equatable, Sendable {
    enum Kind: Equatable, Sendable { case completed, deleted }
    let item: CountdownItem
    let originalIndex: Int
    let kind: Kind

    var message: String {
        switch kind {
        case .completed: "“\(item.title)” completed"
        case .deleted: "“\(item.title)” deleted"
        }
    }
}

struct DashboardSnapshot: Equatable, Sendable {
    let activeItems: [CountdownItem]
    let filteredActiveItems: [CountdownItem]
    let completedItems: [CountdownItem]
    let nextItem: CountdownItem?
    let referenceDate: Date

    var activeCount: Int { activeItems.count }
    var pinnedCount: Int { activeItems.filter(\.isPinned).count }
    var todayCount: Int { activeItems.filter { $0.daysRemaining(from: referenceDate) == 0 }.count }
    var weekCount: Int { activeItems.filter { (0...7).contains($0.daysRemaining(from: referenceDate)) }.count }
}

@MainActor @Observable
final class AppModel {
    static let shared = AppModel()

    private(set) var items: [CountdownItem] = []
    private(set) var isLoaded = false
    private(set) var undoNotice: UndoNotice?
    var persistenceError: String?
    var searchText = ""
    var sortMode: SortMode = .date

    @ObservationIgnored private let repository: CountdownRepository
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var undoExpiryTask: Task<Void, Never>?

    init(repository: CountdownRepository = CountdownRepository()) { self.repository = repository }

    var visibleWidgetItems: [CountdownItem] {
        items.filter { !$0.isCompleted && $0.isWidgetVisible }
    }

    func item(id: UUID) -> CountdownItem? { items.first { $0.id == id } }

    var completedItems: [CountdownItem] {
        filtered(items.filter(\.isCompleted))
            .sorted { lhs, rhs in
                let leftDate = lhs.completedAt ?? .distantPast
                let rightDate = rhs.completedAt ?? .distantPast
                if leftDate != rightDate { return leftDate > rightDate }
                return lhs.id.uuidString < rhs.id.uuidString
            }
    }

    func activeItems(at date: Date = .now) -> [CountdownItem] {
        sorted(filtered(items.filter { !$0.isCompleted }), at: date)
    }

    func nextItem(at date: Date = .now) -> CountdownItem? {
        nextItem(from: activeItems(at: date), at: date)
    }

    func dashboardSnapshot(at date: Date = .now, filter: CountdownFilter = .all) -> DashboardSnapshot {
        let active = activeItems(at: date)
        let filteredActive = active.filter { item in
            switch filter {
            case .all: true
            case .pinned: item.isPinned
            case .today: item.daysRemaining(from: date) == 0
            case .week: (0...7).contains(item.daysRemaining(from: date))
            }
        }
        return DashboardSnapshot(
            activeItems: active,
            filteredActiveItems: filteredActive,
            completedItems: completedItems,
            nextItem: nextItem(from: active, at: date),
            referenceDate: date
        )
    }

    private func nextItem(from activeItems: [CountdownItem], at date: Date) -> CountdownItem? {
        activeItems
            .filter { !$0.isPinned }
            .filter { item in
                let days = item.daysRemaining(from: date)
                return (0...90).contains(days)
            }
            .min { lhs, rhs in
                if lhs.targetDate != rhs.targetDate { return lhs.targetDate < rhs.targetDate }
                return lhs.id.uuidString < rhs.id.uuidString
            }
    }

    func load() async {
        guard !isLoaded else { return }
        do {
            items = try await repository.load()
        } catch { persistenceError = error.localizedDescription }
        isLoaded = true
    }

    func add(_ item: CountdownItem) { items.append(item); scheduleSave() }
    func update(_ item: CountdownItem) { guard let i = index(of: item) else { return }; items[i] = item; scheduleSave() }

    func complete(_ item: CountdownItem) {
        guard let i = index(of: item) else { return }
        let original = items[i]
        items[i].isCompleted = true
        items[i].completedAt = .now
        items[i].isPinned = false
        registerUndo(.init(item: original, originalIndex: i, kind: .completed))
        scheduleSave()
    }

    func restore(_ item: CountdownItem) { mutate(item) { $0.isCompleted = false; $0.completedAt = nil } }
    func togglePinned(_ item: CountdownItem) { mutate(item) { $0.isPinned.toggle() } }
    func setWidgetVisible(_ item: CountdownItem, _ visible: Bool) { mutate(item) { $0.isWidgetVisible = visible } }

    func shiftDate(of item: CountdownItem, by shift: CountdownDateShift, calendar: Calendar = .current) {
        mutate(item) { $0.targetDate = shift.shifted($0.targetDate, calendar: calendar) }
    }

    func delete(_ item: CountdownItem) {
        guard let i = index(of: item) else { return }
        let removed = items.remove(at: i)
        registerUndo(.init(item: removed, originalIndex: i, kind: .deleted))
        scheduleSave()
    }

    func undoLastAction() {
        guard let notice = undoNotice else { return }
        switch notice.kind {
        case .completed:
            guard let i = items.firstIndex(where: { $0.id == notice.item.id }) else { break }
            items[i] = notice.item
        case .deleted:
            let insertionIndex = min(max(notice.originalIndex, 0), items.count)
            items.insert(notice.item, at: insertionIndex)
        }
        clearUndoNotice()
        scheduleSave()
    }

    func dismissUndo() { clearUndoNotice() }

    func saveImmediately() async {
        saveTask?.cancel()
        do { try await repository.save(items) }
        catch { persistenceError = error.localizedDescription }
    }

    /// Atomically persists imported data before replacing the in-memory state.
    /// If persistence fails, the currently displayed countdowns remain unchanged.
    func replaceAll(with importedItems: [CountdownItem]) async throws {
        try CountpaneJSONTransfer.validate(importedItems)
        saveTask?.cancel()
        try await repository.save(importedItems)
        items = importedItems
        clearUndoNotice()
        searchText = ""
    }

    private func index(of item: CountdownItem) -> Int? { items.firstIndex { $0.id == item.id } }

    private func mutate(_ item: CountdownItem, _ body: (inout CountdownItem) -> Void) {
        guard let i = index(of: item) else { return }
        body(&items[i]); scheduleSave()
    }

    private func filtered(_ input: [CountdownItem]) -> [CountdownItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return input }
        return input.filter {
            $0.title.localizedStandardContains(query) || $0.note.localizedStandardContains(query)
        }
    }

    private func sorted(_ input: [CountdownItem], at date: Date) -> [CountdownItem] {
        input.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned && !rhs.isPinned }
            switch sortMode {
            case .date: if lhs.targetDate != rhs.targetDate { return lhs.targetDate < rhs.targetDate }
            case .title:
                let comparison = lhs.title.localizedStandardCompare(rhs.title)
                if comparison != .orderedSame { return comparison == .orderedAscending }
            case .urgency:
                let left = lhs.urgency(from: date).emphasis, right = rhs.urgency(from: date).emphasis
                if left != right { return left > right }
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    private func registerUndo(_ notice: UndoNotice) {
        undoExpiryTask?.cancel()
        undoNotice = notice
        undoExpiryTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(6)) } catch { return }
            guard !Task.isCancelled else { return }
            self?.undoNotice = nil
        }
    }

    private func clearUndoNotice() {
        undoExpiryTask?.cancel(); undoExpiryTask = nil; undoNotice = nil
    }

    private func scheduleSave() {
        let snapshot = items
        saveTask?.cancel()
        saveTask = Task { [repository] in
            do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
            guard !Task.isCancelled else { return }
            do { try await repository.save(snapshot) }
            catch { await MainActor.run { self.persistenceError = error.localizedDescription } }
        }
    }
}
