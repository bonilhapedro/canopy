import AppKit
import CanopyCore
import Observation

/// Acompanha o Apple Music e o Spotify pelas notificações que eles mandam e os controla via AppleScript.
@MainActor
@Observable
final class MusicController {
    private(set) var nowPlaying: NowPlaying?
    private(set) var artwork: NSImage?

    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var artworkKey: String?

    func start() {
        for player in NowPlaying.Player.allCases {
            let token = DistributedNotificationCenter.default().addObserver(
                forName: Notification.Name(player.notificationName),
                object: nil,
                queue: .main
            ) { [weak self] notification in
                let userInfo = notification.userInfo ?? [:]
                MainActor.assumeIsolated {
                    self?.handle(player: player, userInfo: userInfo)
                }
            }
            observers.append(token)
        }
        loadCurrentState()
    }

    func playPause() { send("playpause") }
    func nextTrack() { send("next track") }
    func previousTrack() { send("previous track") }

    // MARK: - Notificações

    private func handle(player: NowPlaying.Player, userInfo: [AnyHashable: Any]) {
        guard var track = NowPlaying.parse(player: player, userInfo: userInfo, at: .now) else {
            if nowPlaying?.player == player { update(nil) }
            return
        }
        // O Apple Music não manda a posição na notificação.
        if track.position == nil {
            track.position = currentPosition(of: player)
        }
        update(track)
    }

    private func update(_ track: NowPlaying?) {
        nowPlaying = track
        if track?.trackKey != artworkKey {
            artworkKey = track?.trackKey
            artwork = nil
            if let track { loadArtwork(for: track) }
        }
        onChange?()
    }

    // MARK: - AppleScript

    /// Nunca fala com um player fechado: o AppleScript abriria o app.
    private func isRunning(_ player: NowPlaying.Player) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: player.bundleIdentifier).isEmpty
    }

    private func send(_ command: String) {
        guard let player = nowPlaying?.player, isRunning(player) else { return }
        AppleScriptRunner.run("tell application \"\(player.scriptName)\" to \(command)")
    }

    private func currentPosition(of player: NowPlaying.Player) -> TimeInterval? {
        guard isRunning(player) else { return nil }
        return AppleScriptRunner.run("tell application \"\(player.scriptName)\" to player position")?.doubleValue
    }

    /// Ao abrir o Canopy, a música já pode estar tocando: pergunta direto aos players abertos.
    private func loadCurrentState() {
        for player in NowPlaying.Player.allCases where isRunning(player) {
            let durationExpression = player == .spotify ? "(duration of t) / 1000" : "duration of t"
            let script = """
            tell application "\(player.scriptName)"
                if player state is stopped then return {"stopped"}
                set t to current track
                return {player state as string, name of t, artist of t, album of t, \(durationExpression), player position}
            end tell
            """
            guard let result = AppleScriptRunner.run(script),
                  result.numberOfItems == 6,
                  let state = result.atIndex(1)?.stringValue,
                  state == "playing" || state == "paused",
                  let title = result.atIndex(2)?.stringValue
            else { continue }

            update(NowPlaying(
                player: player,
                title: title,
                artist: result.atIndex(3)?.stringValue ?? "",
                album: result.atIndex(4)?.stringValue ?? "",
                isPlaying: state == "playing",
                duration: result.atIndex(5)?.doubleValue,
                position: result.atIndex(6)?.doubleValue,
                capturedAt: .now
            ))
            if state == "playing" { return }
        }
    }

    private func loadArtwork(for track: NowPlaying) {
        guard isRunning(track.player) else { return }
        switch track.player {
        case .appleMusic:
            let data = AppleScriptRunner.run("tell application \"Music\" to get data of artwork 1 of current track")?.data
            artwork = data.flatMap(NSImage.init(data:))
        case .spotify:
            guard let address = AppleScriptRunner.run("tell application \"Spotify\" to get artwork url of current track")?.stringValue,
                  let url = URL(string: address)
            else { return }
            let key = track.trackKey
            Task { [weak self] in
                guard let (data, _) = try? await URLSession.shared.data(from: url) else { return }
                // A faixa pode ter mudado enquanto a capa baixava.
                guard let self, self.artworkKey == key else { return }
                self.artwork = NSImage(data: data)
            }
        }
    }
}

private extension NowPlaying.Player {
    var scriptName: String {
        switch self {
        case .appleMusic: "Music"
        case .spotify: "Spotify"
        }
    }
}
