import Foundation
import Testing
@testable import CanopyCore

struct AlignedTicksTests {
    private let anchor = Date(timeIntervalSinceReferenceDate: 1_000)

    @Test func landsOnTheNextWholeStep() {
        #expect(AlignedTicks.next(after: anchor.addingTimeInterval(-1.7), anchor: anchor, interval: 1) == anchor.addingTimeInterval(-1))
        #expect(AlignedTicks.next(after: anchor.addingTimeInterval(0.5), anchor: anchor, interval: 1) == anchor.addingTimeInterval(1))
    }

    @Test func skipsTheStepItIsOn() {
        #expect(AlignedTicks.next(after: anchor, anchor: anchor, interval: 1) == anchor.addingTimeInterval(1))
    }

    @Test func worksWithMinutesBeforeTheAnchor() {
        // Uma reunião às 10:00 vista às 9:55:00,5: o rótulo muda às 9:56.
        let now = anchor.addingTimeInterval(-299.5)
        #expect(AlignedTicks.next(after: now, anchor: anchor, interval: 60) == anchor.addingTimeInterval(-240))
    }

    @Test func neverTicksWithoutAnInterval() {
        #expect(AlignedTicks.next(after: anchor, anchor: anchor, interval: 0) == .distantFuture)
    }
}
