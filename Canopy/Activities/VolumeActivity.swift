import CanopyCore
import SwiftUI

/// Indicador de volume que aparece por um instante quando o volume muda.
@MainActor
final class VolumeActivity: IslandActivity {
    static let activityID = "volume"

    let id = VolumeActivity.activityID
    let priority = ActivityPriority.alert
    private let volume: VolumeMonitor

    init(volume: VolumeMonitor) {
        self.volume = volume
    }

    var compactLeading: AnyView { AnyView(VolumeIcon(volume: volume).font(.system(size: 13, weight: .semibold))) }
    var compactTrailing: AnyView { AnyView(VolumeSegments(volume: volume)) }
    var minimal: AnyView { AnyView(VolumeIcon(volume: volume)) }

    var expanded: AnyView {
        AnyView(
            HStack(spacing: 14) {
                VolumeIcon(volume: volume)
                    .font(.system(size: 22, weight: .semibold))
                    .frame(width: 34)
                VolumeBar(volume: volume)
                Text(volume.isMuted ? "Mudo" : "\(Int((volume.volume * 100).rounded()))")
                    .font(.system(size: 20, weight: .semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .frame(width: 56, alignment: .trailing)
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

/// Dez segmentos que acendem com o volume, como no iPhone.
private struct VolumeSegments: View {
    let volume: VolumeMonitor

    var body: some View {
        let lit = volume.isMuted ? 0 : Int((volume.volume * 10).rounded(.up))
        HStack(spacing: 2) {
            ForEach(0..<10, id: \.self) { index in
                Capsule()
                    .fill(index < lit ? Color.white : Color.white.opacity(0.18))
                    .frame(width: 3, height: 6 + CGFloat(index) * 0.7)
            }
        }
        .animation(.snappy(duration: 0.15), value: lit)
    }
}

private struct VolumeBar: View {
    let volume: VolumeMonitor

    var body: some View {
        let level = volume.isMuted ? 0 : CGFloat(volume.volume)
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.16))
                Capsule()
                    .fill(LinearGradient(colors: [.white.opacity(0.75), .white], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(10, geometry.size.width * level))
                    .shadow(color: .white.opacity(0.5), radius: 6)
            }
        }
        .frame(height: 10)
        .animation(.snappy(duration: 0.18), value: level)
    }
}
