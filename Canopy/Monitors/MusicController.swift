import AppKit
import CanopyCore
import Observation

/// Acompanha o Apple Music e o Spotify pelas notificações que eles mandam e os controla via AppleScript.
@MainActor
@Observable
final class MusicController {
    private(set) var nowPlaying: NowPlaying?
    private(set) var artwork: NSImage?
    private(set) var isShuffling = false
    /// Volume do próprio player, de 0 a 100, independente do volume do Mac.
    private(set) var playerVolume: Int?

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
                // O userInfo não é Sendable: vira NowPlaying antes de entrar no MainActor.
                let track = NowPlaying.parse(player: player, userInfo: notification.userInfo ?? [:], at: .now)
                MainActor.assumeIsolated {
                    self?.handle(player: player, track: track)
                }
            }
            observers.append(token)
        }
        loadCurrentState()
    }

    func playPause() { send("playpause") }
    func nextTrack() { send("next track") }
    func previousTrack() { send("previous track") }

    func toggleShuffle() {
        guard let player = nowPlaying?.player else { return }
        send("set \(player.shuffleProperty) to \(!isShuffling)")
        refreshPlayerSettings()
    }

    func setPlayerVolume(_ volume: Int) {
        let clamped = min(100, max(0, volume))
        send("set sound volume to \(clamped)")
        playerVolume = clamped
    }

    func changePlayerVolume(by step: Int) {
        guard let playerVolume else { return }
        setPlayerVolume(playerVolume + step)
    }

    /// Pula para um ponto da faixa, em segundos.
    func seek(to position: TimeInterval) {
        guard var track = nowPlaying else { return }
        send("set player position to \(position)")
        // Atualiza na hora, sem esperar a próxima notificação do player.
        track.position = position
        track.capturedAt = .now
        nowPlaying = track
    }

    // MARK: - Notificações

    private func handle(player: NowPlaying.Player, track: NowPlaying?) {
        guard var track else {
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
        refreshPlayerSettings()
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

    /// Lê o modo aleatório e o volume do player, que podem ser mudados no próprio app.
    private func refreshPlayerSettings() {
        guard let player = nowPlaying?.player, isRunning(player),
              let result = AppleScriptRunner.run(
                  "tell application \"\(player.scriptName)\" to return {\(player.shuffleProperty), sound volume}"
              ),
              result.numberOfItems == 2
        else { return }
        isShuffling = result.atIndex(1)?.booleanValue ?? false
        playerVolume = result.atIndex(2).map { Int($0.int32Value) }
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

    var shuffleProperty: String {
        switch self {
        case .appleMusic: "shuffle enabled"
        case .spotify: "shuffling"
        }
    }
}
