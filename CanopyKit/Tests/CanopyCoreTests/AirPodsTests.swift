import Testing
@testable import CanopyCore

struct AirPodsTests {
    @Test func recognizesTheModelByProductID() {
        #expect(AirPodsModel(productID: 0x200F) == .airPods)
        #expect(AirPodsModel(productID: 0x2014) == .airPodsPro)
        #expect(AirPodsModel(productID: 0x200A) == .airPodsMax)
        #expect(AirPodsModel(productID: 0x2019) == .airPods4)
        #expect(AirPodsModel(productID: 0x9999) == nil)
    }

    @Test func fallsBackToTheName() {
        #expect(AirPodsModel(name: "AirPods Pro de Pedro") == .airPodsPro)
        #expect(AirPodsModel(name: "AirPods Max") == .airPodsMax)
        #expect(AirPodsModel(name: "AirPods de Pedro") == .airPods)
        #expect(AirPodsModel(name: "Powerbeats Pro") == .beatsEarbuds)
        #expect(AirPodsModel(name: "Beats Studio Pro") == .beatsHeadphones)
        #expect(AirPodsModel.looksLikeAirPods(name: "AirPods de Pedro"))
        #expect(!AirPodsModel.looksLikeAirPods(name: "Magic Keyboard"))
    }

    @Test func zeroMeansUnknown() {
        let battery = AirPodsBattery(left: 0, right: 0, chargingCase: 0)
        #expect(battery.isEmpty)
        #expect(battery.gauges.isEmpty)
    }

    @Test func showsTheBudsTogetherWhenTheyAreClose() {
        let battery = AirPodsBattery(left: 82, right: 85, chargingCase: 60)
        #expect(battery.gauges == [
            AirPodsGauge(part: .buds, percent: 82),
            AirPodsGauge(part: .chargingCase, percent: 60),
        ])
        #expect(battery.isComplete)
        #expect(battery.budsPercent == 82)
    }

    @Test func splitsTheBudsWhenTheyDiffer() {
        let battery = AirPodsBattery(left: 40, right: 90)
        #expect(battery.gauges.map(\.part) == [.left, .right])
        #expect(!battery.isComplete)
        #expect(battery.budsPercent == 40)
    }

    @Test func headphonesHaveOneBattery() {
        let battery = AirPodsBattery(single: 15)
        #expect(battery.gauges == [AirPodsGauge(part: .headphones, percent: 15)])
        #expect(battery.gauges.first?.isLow == true)
        #expect(battery.isComplete)
    }

    @Test func oneBudInTheEar() {
        let battery = AirPodsBattery(right: 70, chargingCase: 30)
        #expect(battery.gauges.map(\.part) == [.right, .chargingCase])
        #expect(battery.budsPercent == 70)
    }
}
