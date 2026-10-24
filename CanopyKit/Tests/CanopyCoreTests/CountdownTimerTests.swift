import Foundation
import Testing
@testable import CanopyCore

struct CountdownTimerTests {
    private let start = Date(timeIntervalSince1970: 1_000)

    @Test func countsDownAndFinishes() {
        let timer = CountdownTimer(duration: 60, startingAt: start)
        #expect(timer.remaining(at: start.addingTimeInterval(15)) == 45)
        #expect(timer.progress(at: start.addingTimeInterval(15)) == 0.25)
        #expect(!timer.isFinished(at: start.addingTimeInterval(59)))
        #expect(timer.isFinished(at: start.addingTimeInterval(60)))
        #expect(timer.remaining(at: start.addingTimeInterval(90)) == 0)
    }

    @Test func pauseFreezesTheRemainingTime() {
        var timer = CountdownTimer(duration: 60, startingAt: start)
        timer.pause(at: start.addingTimeInterval(20))
        #expect(timer.isPaused)
        #expect(timer.remaining(at: start.addingTimeInterval(500)) == 40)
        #expect(!timer.isFinished(at: start.addingTimeInterval(500)))
        timer.resume(at: start.addingTimeInterval(500))
        #expect(timer.remaining(at: start.addingTimeInterval(510)) == 30)
    }

    @Test func addingTimeExtendsBothRunningAndPaused() {
        var timer = CountdownTimer(duration: 60, startingAt: start)
        timer.add(60, at: start.addingTimeInterval(30))
        #expect(timer.duration == 120)
        #expect(timer.remaining(at: start.addingTimeInterval(30)) == 90)
        timer.pause(at: start.addingTimeInterval(40))
        timer.add(60, at: start.addingTimeInterval(40))
        #expect(timer.remaining(at: start.addingTimeInterval(40)) == 140)
    }

    @Test func formatsMinutesAndHours() {
        #expect(CountdownTimer.format(245) == "4:05")
        #expect(CountdownTimer.format(0.2) == "0:01")
        #expect(CountdownTimer.format(3723) == "1:02:03")
    }
}
