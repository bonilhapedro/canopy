import Foundation
import Testing
@testable import CanopyCore

struct ActivityQueueTests {
    private let base = Date(timeIntervalSince1970: 1_000)

    @Test func higherPriorityWins() {
        var queue = ActivityQueue()
        queue.upsert(ActivityEntry(id: "music", priority: .normal, startedAt: base))
        queue.upsert(ActivityEntry(id: "volume", priority: .alert, startedAt: base))
        #expect(queue.primary?.id == "volume")
    }

    @Test func mostRecentWinsAmongEqualPriorities() {
        var queue = ActivityQueue()
        queue.upsert(ActivityEntry(id: "music", priority: .normal, startedAt: base))
        queue.upsert(ActivityEntry(id: "timer", priority: .normal, startedAt: base.addingTimeInterval(5)))
        #expect(queue.ordered.map(\.id) == ["timer", "music"])
    }

    @Test func upsertReplacesInsteadOfDuplicating() {
        var queue = ActivityQueue()
        queue.upsert(ActivityEntry(id: "music", priority: .normal, startedAt: base))
        queue.upsert(ActivityEntry(id: "music", priority: .alert, startedAt: base))
        #expect(queue.entries.count == 1)
        #expect(queue.primary?.priority == .alert)
    }

    @Test func removeDropsTheEntry() {
        var queue = ActivityQueue()
        queue.upsert(ActivityEntry(id: "music", priority: .normal, startedAt: base))
        queue.remove(id: "music")
        #expect(queue.isEmpty)
        #expect(!queue.contains(id: "music"))
    }
}
