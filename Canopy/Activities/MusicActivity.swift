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

    var compactLeading: AnyView { AnyView(ArtworkView(music: music, size: 20, cornerRadius: 5)) }
    var compactTrailing: AnyView { AnyView(EqualizerBars(music: music)) }
    var minimal: AnyView { AnyView(ArtworkView(music: music, size: 18, cornerRadius: 4)) }
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
            HStack(spacing: 14) {
                ArtworkView(music: music, size: 76, cornerRadius: 12)
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title)
                        .font(.headline)
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    ProgressRow(track: track)
                    HStack(spacing: 24) {
                        control("backward.fill", action: music.previousTrack)
                        control(track.isPlaying ? "pause.fill" : "play.fill", action: music.playPause)
                        control("forward.fill", action: music.nextTrack)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .foregroundStyle(.white)
        }
    }

    private func control(_ symbol: String, action: @escaping @MainActor () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title3)
                .frame(width: 28, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct ProgressRow: View {
    let track: NowPlaying

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let position = track.position(at: context.date) ?? 0
            let duration = track.duration ?? 0
            HStack(spacing: 8) {
                Text(NowPlaying.timestamp(position))
                ProgressView(value: duration > 0 ? min(position / duration, 1) : 0)
                    .progressViewStyle(.linear)
                    .tint(.white)
                Text(NowPlaying.timestamp(duration))
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }
}
