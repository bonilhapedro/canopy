import AppKit
import CanopyCore
#if BENCHMARK
import ImageIO
#endif
import Observation
import SwiftUI

/// Acompanha o Apple Music e o Spotify pelas notificações que eles mandam e os controla via AppleScript.
@MainActor
@Observable
final class MusicController {
    private(set) var nowPlaying: NowPlaying?
    private(set) var artwork: NSImage?
    /// Cor tirada da capa, usada no brilho, no equalizador e na barra de progresso.
    private(set) var accent: Color?
    private(set) var isShuffling = false
    /// Volume do próprio player, de 0 a 100, independente do volume do Mac.
    private(set) var playerVolume: Int?
    private(set) var repeatMode = RepeatMode.off
    /// Se a faixa está nos favoritos. Só o Apple Music deixa ler isso; no Spotify fica nil.
    private(set) var isFavorite: Bool?

    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var artworkKey: String?
    @ObservationIgnored private var icons: [NowPlaying.Player: NSImage] = [:]

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

    func cycleRepeat() {
        guard let player = nowPlaying?.player else { return }
        let next = repeatMode.next(supportsOne: player == .appleMusic)
        switch player {
        case .appleMusic: send("set song repeat to \(next.rawValue)")
        case .spotify: send("set repeating to \(next != .off)")
        }
        repeatMode = next
    }

    func toggleFavorite() {
        guard let isFavorite, let player = nowPlaying?.player, player == .appleMusic, isRunning(player) else { return }
        let value = !isFavorite
        // "loved" virou "favorited" no Apple Music mais novo; tenta os dois.
        AppleScriptRunner.run("""
        tell application "Music"
            try
                set favorited of current track to \(value)
            on error
                set loved of current track to \(value)
            end try
        end tell
        """)
        self.isFavorite = value
    }

    /// Traz o player para a frente.
    func activatePlayer() {
        guard let player = nowPlaying?.player else { return }
        NSRunningApplication.runningApplications(withBundleIdentifier: player.bundleIdentifier).first?.activate()
    }

    /// Ícone do app do player, para o selinho na capa.
    func icon(for player: NowPlaying.Player) -> NSImage? {
        if let cached = icons[player] { return cached }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: player.bundleIdentifier) else { return nil }
        let image = NSWorkspace.shared.icon(forFile: url.path)
        icons[player] = image
        return image
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

    #if BENCHMARK
    /// Uma faixa falsa tocando, com uma capa grande de verdade, para medir sem depender de um player.
    func simulatePlayback() {
        let track = NowPlaying(
            player: .spotify,
            title: "Uma faixa com um título comprido o bastante para rolar na ilha",
            artist: "Artista de teste com um nome bem longo também",
            album: "Canopy",
            isPlaying: true,
            duration: 245,
            position: 12,
            capturedAt: .now
        )
        nowPlaying = track
        artworkKey = track.trackKey
        setArtwork(Self.benchmarkArtwork().flatMap(NSImage.init(data:)))
        onChange?()
    }

    /// Uma capa de 1000 por 1000 em JPEG, do tamanho das que o Spotify e o Apple Music mandam.
    private static func benchmarkArtwork() -> Data? {
        let side = 1000
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                  space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ),
              let gradient = CGGradient(
                  colorsSpace: space,
                  colors: [CGColor(red: 0.95, green: 0.35, blue: 0.45, alpha: 1), CGColor(red: 0.2, green: 0.3, blue: 0.9, alpha: 1)] as CFArray,
                  locations: nil
              )
        else { return nil }
        context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: side, y: side), options: [])
        guard let image = context.makeImage() else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data as CFMutableData, "public.jpeg" as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
    #endif

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
            setArtwork(nil)
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

    /// Lê o modo aleatório, a repetição, o volume e o favorito, que podem ser mudados no próprio app.
    private func refreshPlayerSettings() {
        guard let player = nowPlaying?.player, isRunning(player) else { return }
        let script = switch player {
        case .appleMusic:
            """
            tell application "Music"
                set fav to missing value
                try
                    set fav to favorited of current track
                on error
                    try
                        set fav to loved of current track
                    end try
                end try
                return {shuffle enabled, sound volume, song repeat as string, fav}
            end tell
            """
        case .spotify:
            "tell application \"Spotify\" to return {shuffling, sound volume, repeating}"
        }
        guard let result = AppleScriptRunner.run(script), result.numberOfItems >= 3 else { return }
        isShuffling = result.atIndex(1)?.booleanValue ?? false
        playerVolume = result.atIndex(2).map { Int($0.int32Value) }
        switch player {
        case .appleMusic:
            repeatMode = result.atIndex(3)?.stringValue.flatMap(RepeatMode.init(rawValue:)) ?? .off
            // 'msng' é o "missing value" do AppleScript: a faixa não deixa favoritar.
            let favorite = result.atIndex(4)
            isFavorite = favorite.flatMap { $0.descriptorType == Self.missingValue ? nil : $0.booleanValue }
        case .spotify:
            repeatMode = result.atIndex(3)?.booleanValue == true ? .all : .off
            isFavorite = nil
        }
    }

    private static let missingValue: DescType = 0x6D73_6E67

    private func setArtwork(_ image: NSImage?) {
        artwork = image
        accent = image.flatMap(ArtworkPalette.accent(of:)).map { Color(nsColor: $0) }
    }

    private func loadArtwork(for track: NowPlaying) {
        guard isRunning(track.player) else { return }
        switch track.player {
        case .appleMusic:
            let data = AppleScriptRunner.run("tell application \"Music\" to get data of artwork 1 of current track")?.data
            setArtwork(data.flatMap(NSImage.init(data:)))
        case .spotify:
            guard let address = AppleScriptRunner.run("tell application \"Spotify\" to get artwork url of current track")?.stringValue,
                  let url = URL(string: address)
            else { return }
            let key = track.trackKey
            Task { [weak self] in
                guard let (data, _) = try? await URLSession.shared.data(from: url) else { return }
                // A faixa pode ter mudado enquanto a capa baixava.
                guard let self, self.artworkKey == key else { return }
                self.setArtwork(NSImage(data: data))
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
