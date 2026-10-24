import Testing
@testable import CanopyCore

struct IslandPagerTests {
    @Test func nowPageOnlyExistsWithAnActivity() {
        #expect(IslandPage.available(hasActivity: false, showsWeather: true) == [.home, .weather])
        #expect(IslandPage.available(hasActivity: true, showsWeather: true) == [.now, .home, .weather])
        #expect(IslandPage.available(hasActivity: true, showsWeather: false) == [.now, .home])
    }

    @Test func trayComesRightAfterHome() {
        #expect(IslandPage.available(hasActivity: true, showsWeather: true, showsTray: true) == [.now, .home, .tray, .weather])
    }

    @Test func neighborDoesNotWrapAround() {
        let pages: [IslandPage] = [.now, .home, .weather]
        #expect(IslandPage.now.neighbor(1, in: pages) == .home)
        #expect(IslandPage.home.neighbor(1, in: pages) == .weather)
        #expect(IslandPage.weather.neighbor(1, in: pages) == nil)
        #expect(IslandPage.now.neighbor(-1, in: pages) == nil)
    }

    @Test func missingPageFallsBackToTheFirst() {
        #expect(IslandPage.weather.neighbor(1, in: [.home, .tray]) == .home)
    }

    @Test func swipeFiresOncePerGesture() {
        var tracker = SwipeTracker()
        #expect(tracker.handle(fingerDeltaX: -10, phase: .began) == nil)
        #expect(tracker.handle(fingerDeltaX: -20, phase: .changed) == nil)
        #expect(tracker.handle(fingerDeltaX: -10, phase: .changed) == 1)
        #expect(tracker.handle(fingerDeltaX: -80, phase: .changed) == nil)
        #expect(tracker.handle(fingerDeltaX: 0, phase: .ended) == nil)
        #expect(tracker.handle(fingerDeltaX: 40, phase: .began) == -1)
    }

    @Test func smallSwipesAreIgnored() {
        var tracker = SwipeTracker()
        _ = tracker.handle(fingerDeltaX: 10, phase: .began)
        #expect(tracker.handle(fingerDeltaX: 10, phase: .changed) == nil)
        #expect(tracker.handle(fingerDeltaX: -15, phase: .changed) == nil)
    }
}
