import Testing
@testable import CanopyCore

struct RepeatModeTests {
    @Test func cyclesThroughModes() {
        #expect(RepeatMode.off.next(supportsOne: true) == .all)
        #expect(RepeatMode.all.next(supportsOne: true) == .one)
        #expect(RepeatMode.one.next(supportsOne: true) == .off)
        #expect(RepeatMode.all.next(supportsOne: false) == .off)
    }
}
