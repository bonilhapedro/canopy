import Foundation
import Testing
@testable import CanopyCore

struct NowPlayingTests {
    private let now = Date(timeIntervalSince1970: 10_000)

    @Test func readsAppleMusicNotification() throws {
        let info: [AnyHashable: Any] = [
            "Player State": "Playing",
            "Name": "Construção",
            "Artist": "Chico Buarque",
            "Album": "Construção",
            "Total Time": NSNumber(value: 384_000),
        ]
        let track = try #require(NowPlaying.parse(player: .appleMusic, userInfo: info, at: now))
        #expect(track.title == "Construção")
        #expect(track.isPlaying)
        #expect(track.duration == 384)
        #expect(track.position == nil)
    }

    @Test func readsSpotifyNotification() throws {
        let info: [AnyHashable: Any] = [
            "Player State": "Paused",
            "Name": "Águas de Março",
            "Artist": "Elis Regina",
            "Album": "Elis & Tom",
            "Duration": NSNumber(value: 212_000),
            "Playback Position": NSNumber(value: 40.5),
        ]
        let track = try #require(NowPlaying.parse(player: .spotify, userInfo: info, at: now))
        #expect(!track.isPlaying)
        #expect(track.duration == 212)
        #expect(track.position == 40.5)
    }

    @Test func stoppedPlayerMeansNothingPlaying() {
        let info: [AnyHashable: Any] = ["Player State": "Stopped"]
        #expect(NowPlaying.parse(player: .spotify, userInfo: info, at: now) == nil)
    }

    @Test func positionAdvancesOnlyWhilePlaying() {
        var track = NowPlaying(
            player: .spotify, title: "x", artist: "", album: "",
            isPlaying: true, duration: 100, position: 10, capturedAt: now
        )
        #expect(track.position(at: now.addingTimeInterval(5)) == 15)
        #expect(track.position(at: now.addingTimeInterval(500)) == 100)
        track.isPlaying = false
        #expect(track.position(at: now.addingTimeInterval(5)) == 10)
    }

    @Test func formatsTimestamps() {
        #expect(NowPlaying.timestamp(7) == "0:07")
        #expect(NowPlaying.timestamp(187.9) == "3:07")
        #expect(NowPlaying.timestamp(3765) == "1:02:45")
    }
}
