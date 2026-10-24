import CanopyCore
import SwiftUI

@MainActor
final class MusicActivity: IslandActivity {
    static let activityID = "music"

    let id = MusicActivity.activityID
    let priority = ActivityPriority.normal
    private let music: MusicController

    init(music: MusicController) {
        self.music = music
    }

    var compactLeading: AnyView { AnyView(ArtworkView(music: music, size: 26, cornerRadius: 6)) }
    var compactTrailing: AnyView { AnyView(EqualizerBars(music: music)) }
    var minimal: AnyView { AnyView(ArtworkView(music: music, size: 22, cornerRadius: 5)) }
    var expanded: AnyView { AnyView(MusicExpandedView(music: music)) }
}

private struct ArtworkView: View {
    let music: MusicController
    let size: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        Group {
            if let artwork = music.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Color.white.opacity(0.15)
                    Image(systemName: "music.note")
                        .font(.system(size: size * 0.45))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

/// Barrinhas que pulam enquanto a música toca e param quando pausa.
private struct EqualizerBars: View {
    let music: MusicController

    var body: some View {
        let isPlaying = music.nowPlaying?.isPlaying ?? false
        TimelineView(.animation(minimumInterval: 0.12, paused: !isPlaying)) { context in
            HStack(spacing: 2) {
                ForEach(0..<4, id: \.self) { index in
                    Capsule()
                        .fill(Color.green)
                        .frame(width: 3, height: height(of: index, at: context.date, isPlaying: isPlaying))
                }
            }
            .frame(height: 14)
        }
    }

    private func height(of index: Int, at date: Date, isPlaying: Bool) -> CGFloat {
        guard isPlaying else { return 3 }
        let phase = date.timeIntervalSinceReferenceDate * 6 + Double(index) * 1.3
        return 4 + 10 * abs(sin(phase))
    }
}

private struct MusicExpandedView: View {
    let music: MusicController

    var body: some View {
        if let track = music.nowPlaying {
            HStack(spacing: 16) {
                ArtworkView(music: music, size: 104, cornerRadius: 14)
                VStack(alignment: .leading, spacing: 6) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(track.title)
                            .font(.headline)
                            .lineLimit(1)
                        Text(track.artist)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    SeekBar(music: music, track: track)
                    HStack(spacing: 20) {
                        control("shuffle", isOn: music.isShuffling, action: music.toggleShuffle)
                        Spacer(minLength: 0)
                        control("backward.fill", action: music.previousTrack)
                        control(track.isPlaying ? "pause.fill" : "play.fill", action: music.playPause)
                        control("forward.fill", action: music.nextTrack)
                        Spacer(minLength: 0)
                        // Mantém os três botões do meio centralizados.
                        Color.clear.frame(width: 28, height: 1)
                    }
                    PlayerVolumeRow(music: music)
                }
            }
            .foregroundStyle(.white)
        }
    }

    private func control(_ symbol: String, isOn: Bool = false, action: @escaping @MainActor () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(isOn ? Color.green : Color.white)
                .frame(width: 28, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Barra de progresso que dá para clicar ou arrastar para avançar e voltar na faixa.
private struct SeekBar: View {
    let music: MusicController
    let track: NowPlaying
    @State private var dragFraction: Double?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let duration = track.duration ?? 0
            let playing = track.position(at: context.date) ?? 0
            let fraction = dragFraction ?? (duration > 0 ? min(playing / duration, 1) : 0)
            HStack(spacing: 8) {
                Text(NowPlaying.timestamp(fraction * duration))
                    .frame(width: 38, alignment: .leading)
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.25))
                        Capsule().fill(Color.white).frame(width: geometry.size.width * fraction)
                    }
                    .frame(height: dragFraction == nil ? 4 : 6)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                dragFraction = min(max(value.location.x / geometry.size.width, 0), 1)
                            }
                            .onEnded { value in
                                let target = min(max(value.location.x / geometry.size.width, 0), 1)
                                dragFraction = nil
                                if duration > 0 { music.seek(to: target * duration) }
                            }
                    )
                }
                .frame(height: 14)
                Text(NowPlaying.timestamp(duration))
                    .frame(width: 38, alignment: .trailing)
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }
}

/// Volume do próprio player, sem mexer no volume do Mac.
private struct PlayerVolumeRow: View {
    let music: MusicController
    @State private var draft: Double?

    var body: some View {
        if let volume = music.playerVolume {
            HStack(spacing: 8) {
                Button { music.changePlayerVolume(by: -10) } label: {
                    Image(systemName: "speaker.fill")
                        .frame(width: 20, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Slider(
                    value: Binding(
                        get: { draft ?? Double(volume) },
                        set: { draft = $0 }
                    ),
                    in: 0...100,
                    onEditingChanged: { editing in
                        if !editing, let draft {
                            music.setPlayerVolume(Int(draft.rounded()))
                            self.draft = nil
                        }
                    }
                )
                .controlSize(.mini)
                .tint(.white)
                Button { music.changePlayerVolume(by: 10) } label: {
                    Image(systemName: "speaker.wave.3.fill")
                        .frame(width: 24, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .font(.caption)
            .foregroundStyle(.white.opacity(0.8))
        }
    }
}
