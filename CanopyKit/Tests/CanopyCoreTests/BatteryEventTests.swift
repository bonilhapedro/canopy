import Testing
@testable import CanopyCore

struct BatteryEventTests {
    @Test func firstReadingSaysNothing() {
        #expect(BatteryEvent.between(nil, BatterySnapshot(percent: 50, isCharging: false, isPluggedIn: false)) == nil)
    }

    @Test func detectsChargerChanges() {
        let onBattery = BatterySnapshot(percent: 50, isCharging: false, isPluggedIn: false)
        let charging = BatterySnapshot(percent: 50, isCharging: true, isPluggedIn: true)
        #expect(BatteryEvent.between(onBattery, charging) == .pluggedIn)
        #expect(BatteryEvent.between(charging, onBattery) == .unplugged)
    }

    @Test func warnsOnceWhenCrossingTheLowLevel() {
        let eleven = BatterySnapshot(percent: 11, isCharging: false, isPluggedIn: false)
        let ten = BatterySnapshot(percent: 10, isCharging: false, isPluggedIn: false)
        let nine = BatterySnapshot(percent: 9, isCharging: false, isPluggedIn: false)
        #expect(BatteryEvent.between(eleven, ten) == .low)
        #expect(BatteryEvent.between(ten, nine) == nil)
    }
}
