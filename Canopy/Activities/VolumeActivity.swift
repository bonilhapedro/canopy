import CanopyCore
import SwiftUI

/// Indicador de volume que aparece por um instante quando o volume muda.
@MainActor
final class VolumeActivity: IslandActivity {
    static let activityID = "volume"

    let id = VolumeActivity.activityID
    let priority = ActivityPriority.alert
    private let volume: VolumeMonitor
    /// Com "combinar com a música", a cor da capa que está tocando.
    private let tint: Color

    init(volume: VolumeMonitor, tint: Color = .white) {
        self.volume = volume
        self.tint = tint
    }

    var accent: Color? { tint }
    let tabSymbol = "speaker.wave.2.fill"

    var compactLeading: AnyView { AnyView(VolumeIcon(volume: volume).font(.system(size: 13, weight: .semibold))) }
    var compactTrailing: AnyView { AnyView(VolumeLevel(volume: volume) { LevelSegments(level: $0, tint: self.tint) }) }
    var minimal: AnyView { AnyView(VolumeIcon(volume: volume)) }

    var expanded: AnyView {
        AnyView(
            HStack(spacing: 14) {
                VolumeIcon(volume: volume)
                    .font(.system(size: 22, weight: .semibold))
                    .frame(width: 34)
                VolumeLevel(volume: volume) { level in
                    LevelBar(level: level, tint: self.tint)
                    LevelPercent(text: self.volume.isMuted ? "Mudo" : "\(Int((level * 100).rounded()))")
                }
            }
            .foregroundStyle(.white)
            .frame(maxHeight: .infinity)
        )
    }
}

private struct VolumeIcon: View {
    let volume: VolumeMonitor

    var body: some View {
        Image(systemName: symbol)
            .foregroundStyle(.white)
            .contentTransition(.symbolEffect(.replace))
            .animation(.snappy, value: symbol)
    }

    private var symbol: String {
        if volume.isMuted || volume.volume == 0 { return "speaker.slash.fill" }
        if volume.volume < 0.34 { return "speaker.wave.1.fill" }
        if volume.volume < 0.67 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }
}

/// Lê o volume dentro do próprio body, para só este pedaço redesenhar quando ele muda.
private struct VolumeLevel<Content: View>: View {
    let volume: VolumeMonitor
    @ViewBuilder let content: (Double) -> Content

    var body: some View {
        content(volume.isMuted ? 0 : Double(volume.volume))
    }
}
