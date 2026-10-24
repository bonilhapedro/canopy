import Testing
@testable import CanopyCore

struct AudioOutputTests {
    @Test func recognizesAirPodsByName() {
        #expect(AudioOutputKind(name: "AirPods Pro de Pedro", transport: .bluetooth) == .airPodsPro)
        #expect(AudioOutputKind(name: "AirPods Max", transport: .bluetooth) == .airPodsMax)
        #expect(AudioOutputKind(name: "AirPods de Pedro", transport: .bluetooth) == .airPods)
        #expect(AudioOutputKind(name: "Beats Studio Buds", transport: .bluetooth) == .beats)
        #expect(AudioOutputKind(name: "AirPods de Pedro", transport: .bluetooth).isAppleHeadphones)
        #expect(!AudioOutputKind(name: "WH-1000XM5", transport: .bluetooth).isAppleHeadphones)
    }

    @Test func fallsBackToTheTransport() {
        #expect(AudioOutputKind(name: "Alto-falantes do MacBook Pro", transport: .builtIn) == .builtInSpeakers)
        #expect(AudioOutputKind(name: "External Headphones", transport: .builtIn) == .headphones)
        #expect(AudioOutputKind(name: "LG UltraFine", transport: .hdmiOrDisplayPort) == .display)
        #expect(AudioOutputKind(name: "Sala", transport: .airPlay) == .airPlay)
        #expect(AudioOutputKind(name: "WH-1000XM5", transport: .bluetooth) == .headphones)
    }
}
