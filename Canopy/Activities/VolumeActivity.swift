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

    var compactLeading: AnyView { AnyView(VolumeIcon(volume: volume)) }
    var compactTrailing: AnyView { AnyView(VolumeBar(volume: volume).frame(width: 56)) }
    var minimal: AnyView { AnyView(VolumeIcon(volume: volume)) }

    var expanded: AnyView {
        AnyView(
            HStack(spacing: 12) {
                VolumeIcon(volume: volume)
                    .font(.title2)
                    .frame(width: 32)
                VolumeBar(volume: volume)
                Text(volume.isMuted ? "Mudo" : "\(Int((volume.volume * 100).rounded()))%")
                    .monospacedDigit()
                    .frame(width: 48, alignment: .trailing)
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
    }

    private var symbol: String {
        if volume.isMuted || volume.volume == 0 { return "speaker.slash.fill" }
        if volume.volume < 0.34 { return "speaker.wave.1.fill" }
        if volume.volume < 0.67 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }
}

private struct VolumeBar: View {
    let volume: VolumeMonitor

    var body: some View {
        ProgressView(value: volume.isMuted ? 0 : Double(volume.volume))
            .progressViewStyle(.linear)
            .tint(.white)
    }
}
