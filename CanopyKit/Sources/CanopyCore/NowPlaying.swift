import Foundation

/// A música tocando agora no Apple Music ou no Spotify.
public struct NowPlaying: Sendable, Equatable {
    public enum Player: String, CaseIterable, Sendable {
        case appleMusic
        case spotify

        public var bundleIdentifier: String {
            switch self {
            case .appleMusic: "com.apple.Music"
            case .spotify: "com.spotify.client"
            }
        }

        /// Notificação distribuída que o app envia a cada troca de faixa ou de estado.
        public var notificationName: String {
            switch self {
            case .appleMusic: "com.apple.Music.playerInfo"
            case .spotify: "com.spotify.client.PlaybackStateChanged"
            }
        }
    }

    public var player: Player
    public var title: String
    public var artist: String
    public var album: String
    public var isPlaying: Bool
    /// Duração da faixa, em segundos.
    public var duration: TimeInterval?
    /// Posição na faixa, em segundos, no instante `capturedAt`.
    public var position: TimeInterval?
    public var capturedAt: Date

    public init(
        player: Player,
        title: String,
        artist: String,
        album: String,
        isPlaying: Bool,
        duration: TimeInterval?,
        position: TimeInterval?,
        capturedAt: Date
    ) {
        self.player = player
        self.title = title
        self.artist = artist
        self.album = album
        self.isPlaying = isPlaying
        self.duration = duration
        self.position = position
        self.capturedAt = capturedAt
    }

    /// Identifica a faixa, para saber quando buscar uma capa nova.
    public var trackKey: String {
        "\(player.rawValue)|\(title)|\(artist)|\(album)"
    }

    /// Posição estimada em `date`, avançando o relógio enquanto toca.
    public func position(at date: Date) -> TimeInterval? {
        guard let position else { return nil }
        let elapsed = isPlaying ? max(0, date.timeIntervalSince(capturedAt)) : 0
        let estimate = position + elapsed
        if let duration { return min(estimate, duration) }
        return estimate
    }

    /// Lê o `userInfo` da notificação do player. Devolve nil quando a reprodução parou.
    public static func parse(player: Player, userInfo: [AnyHashable: Any], at date: Date) -> NowPlaying? {
        let state = (userInfo["Player State"] as? String)?.lowercased()
        guard state == "playing" || state == "paused",
              let title = userInfo["Name"] as? String, !title.isEmpty
        else { return nil }

        let duration: TimeInterval?
        let position: TimeInterval?
        switch player {
        case .appleMusic:
            duration = (userInfo["Total Time"] as? NSNumber).map { $0.doubleValue / 1000 }
            position = nil
        case .spotify:
            duration = (userInfo["Duration"] as? NSNumber).map { $0.doubleValue / 1000 }
            position = (userInfo["Playback Position"] as? NSNumber)?.doubleValue
        }

        return NowPlaying(
            player: player,
            title: title,
            artist: userInfo["Artist"] as? String ?? "",
            album: userInfo["Album"] as? String ?? "",
            isPlaying: state == "playing",
            duration: duration,
            position: position,
            capturedAt: date
        )
    }

    /// Formata segundos como "3:07" ou "1:02:45".
    public static func timestamp(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        let hours = total / 3600
        let minutes = total % 3600 / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}
