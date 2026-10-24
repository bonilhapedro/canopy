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

    var compactLeading: AnyView { AnyView(ArtworkView(music: music, size: 26, cornerRadius: 7)) }
    var compactTrailing: AnyView { AnyView(EqualizerBars(music: music)) }
    var minimal: AnyView { AnyView(ArtworkView(music: music, size: 20, cornerRadius: 5)) }
    var expanded: AnyView { AnyView(MusicExpandedView(music: music)) }
    var accent: Color? { music.accent }
    var backdrop: AnyView? { AnyView(ArtworkBackdrop(music: music)) }
}

private struct ArtworkView: View {
    let music: MusicController
    let size: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        ZStack {
            if let artwork = music.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .transition(.opacity)
            } else {
                LinearGradient(
                    colors: [Color.white.opacity(0.22), Color.white.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
        )
        .animation(.easeInOut(duration: 0.3), value: music.artwork == nil)
    }
}

/// A capa bem desfocada atrás da ilha aberta, como no Apple Music.
private struct ArtworkBackdrop: View {
    let music: MusicController

    var body: some View {
        ZStack {
            if let artwork = music.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .scaleEffect(1.6)
                    .blur(radius: 50)
                    .opacity(0.5)
            } else if let accent = music.accent {
                accent.opacity(0.25).blur(radius: 40)
            }
            // Escurece por baixo para o texto continuar legível.
            LinearGradient(
                colors: [Color.black.opacity(0.15), Color.black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .animation(.easeInOut(duration: 0.6), value: music.artwork == nil)
    }
}

/// Barrinhas na cor da capa que pulam enquanto a música toca.
private struct EqualizerBars: View {
    let music: MusicController
    var bars = 4
    var barWidth: CGFloat = 3
    var maxHeight: CGFloat = 16

    var body: some View {
        let isPlaying = music.nowPlaying?.isPlaying ?? false
        let tint = music.accent ?? .white
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !isPlaying)) { context in
            HStack(alignment: .center, spacing: barWidth * 0.8) {
                ForEach(0..<bars, id: \.self) { index in
                    Capsule()
                        .fill(tint.gradient)
                        .frame(width: barWidth, height: height(index: index, at: context.date, isPlaying: isPlaying))
                }
            }
            .frame(height: maxHeight)
            .shadow(color: tint.opacity(0.6), radius: 4)
        }
    }

    private func height(index: Int, at date: Date, isPlaying: Bool) -> CGFloat {
        let floor = barWidth
        guard isPlaying else { return floor }
        // Cada barra tem a sua velocidade, para a onda não parecer repetida.
        let speed = 5 + Double((index * 37) % 40) / 10
        let time = date.timeIntervalSinceReferenceDate
        let wave = abs(sin(time * speed + Double(index))) * 0.65 + abs(sin(time * speed * 0.37)) * 0.35
        return floor + (maxHeight - floor) * wave
    }
}

/// Player aberto no layout do Canopy original: capa e faixa em cima, onda à direita,
/// barra de progresso e uma fileira de glifos soltos sobre o vidro.
private struct MusicExpandedView: View {
    let music: MusicController
    @State private var showsVolume = false

    var body: some View {
        if let track = music.nowPlaying {
            let tint = music.accent ?? .white
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    ArtworkView(music: music, size: 56, cornerRadius: 12)
                        .shadow(color: tint.opacity(0.45), radius: 12, y: 4)
                        .scaleEffect(track.isPlaying ? 1 : 0.92)
                        .animation(.bouncy(duration: 0.4), value: track.isPlaying)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                            .font(.system(size: 15, weight: .bold))
                            .lineLimit(1)
                        Text(track.artist)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.55))
                            .lineLimit(1)
                    }
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.25), value: track.trackKey)

                    Spacer(minLength: 8)

                    EqualizerBars(music: music, bars: 6, barWidth: 3.5, maxHeight: 24)
                }

                ZStack {
                    if showsVolume {
                        PlayerVolumeRow(music: music, tint: tint)
                            .transition(.blurReplace)
                    } else {
                        SeekBar(music: music, track: track, tint: tint)
                            .transition(.blurReplace)
                    }
                }
                .frame(height: 24)
                .animation(.smooth(duration: 0.25), value: showsVolume)

                GlassEffectContainer(spacing: 8) {
                    HStack(spacing: 0) {
                        Button(action: music.toggleShuffle) {
                            Image(systemName: "shuffle")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(music.isShuffling ? tint : Color.white.opacity(0.5))
                        }
                        .buttonStyle(IslandButtonStyle(size: 32))
                        Spacer(minLength: 0)
                        Button(action: music.previousTrack) {
                            Image(systemName: "backward.fill").font(.system(size: 20))
                        }
                        .buttonStyle(IslandButtonStyle(size: 38))
                        Button(action: music.playPause) {
                            Image(systemName: track.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 28))
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .buttonStyle(IslandButtonStyle(size: 44))
                        .padding(.horizontal, 14)
                        Button(action: music.nextTrack) {
                            Image(systemName: "forward.fill").font(.system(size: 20))
                        }
                        .buttonStyle(IslandButtonStyle(size: 38))
                        Spacer(minLength: 0)
                        Button { showsVolume.toggle() } label: {
                            Image(systemName: showsVolume ? "speaker.wave.2.fill" : "hifispeaker.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(showsVolume ? tint : Color.white.opacity(0.85))
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .buttonStyle(IslandButtonStyle(size: 32))
                    }
                }
            }
            .foregroundStyle(.white)
            .frame(maxHeight: .infinity)
        }
    }
}

/// Barra de progresso que dá para clicar ou arrastar para avançar e voltar na faixa.
private struct SeekBar: View {
    let music: MusicController
    let track: NowPlaying
    let tint: Color
    @State private var dragFraction: Double?
    @State private var isHovered = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let duration = track.duration ?? 0
            let playing = track.position(at: context.date) ?? 0
            let fraction = dragFraction ?? (duration > 0 ? min(playing / duration, 1) : 0)
            let isActive = isHovered || dragFraction != nil
            HStack(spacing: 8) {
                Text(NowPlaying.timestamp(fraction * duration))
                    .frame(width: 36, alignment: .leading)
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.18))
                        Capsule()
                            .fill(LinearGradient(colors: [tint.opacity(0.7), tint], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(isActive ? 6 : 4, geometry.size.width * fraction))
                            .shadow(color: tint.opacity(isActive ? 0.7 : 0.3), radius: 4)
                    }
                    .frame(height: isActive ? 7 : 4)
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
                    .onHover { isHovered = $0 }
                }
                .frame(height: 14)
                Text(NowPlaying.timestamp(duration))
                    .frame(width: 40, alignment: .trailing)
            }
            .font(.system(size: 10, weight: .semibold).monospacedDigit())
            .foregroundStyle(.white.opacity(0.55))
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isActive)
        }
    }
}

/// Volume do próprio player, sem mexer no volume do Mac.
private struct PlayerVolumeRow: View {
    let music: MusicController
    let tint: Color
    @State private var draft: Double?

    var body: some View {
        if let volume = music.playerVolume {
            HStack(spacing: 6) {
                Button { music.changePlayerVolume(by: -10) } label: {
                    Image(systemName: "speaker.fill").font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(IslandButtonStyle(size: 24))
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
                .tint(tint)
                Button { music.changePlayerVolume(by: 10) } label: {
                    Image(systemName: "speaker.wave.3.fill").font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(IslandButtonStyle(size: 24))
            }
            .foregroundStyle(.white.opacity(0.6))
        }
    }
}
