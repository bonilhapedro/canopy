import CanopyCore
import SwiftUI

/// Fica na ilha enquanto algum app usa o microfone ou a câmera.
@MainActor
final class PrivacyActivity: IslandActivity {
    static let activityID = "privacy"

    let id = PrivacyActivity.activityID
    let priority = ActivityPriority.normal
    private let privacy: PrivacyMonitor

    init(privacy: PrivacyMonitor) {
        self.privacy = privacy
    }

    var compactLeading: AnyView { AnyView(PrivacyIcons(privacy: privacy, size: 12)) }
    var compactTrailing: AnyView { AnyView(PrivacyDots(privacy: privacy)) }
    var minimal: AnyView { AnyView(PrivacyIcons(privacy: privacy, size: 11)) }
    var accent: Color? { privacy.isCameraInUse ? .green : .orange }

    var expanded: AnyView {
        AnyView(
            PrivacyIcons(privacy: privacy, size: 34)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        )
    }
}

private struct PrivacyIcons: View {
    let privacy: PrivacyMonitor
    let size: CGFloat

    var body: some View {
        HStack(spacing: size * 0.6) {
            if privacy.isMicrophoneInUse {
                Image(systemName: "mic.fill")
                    .foregroundStyle(.orange)
                    .shadow(color: .orange.opacity(0.6), radius: size * 0.3)
                    .transition(.scale.combined(with: .opacity))
            }
            if privacy.isCameraInUse {
                Image(systemName: "video.fill")
                    .foregroundStyle(.green)
                    .shadow(color: .green.opacity(0.6), radius: size * 0.3)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .font(.system(size: size, weight: .semibold))
        .symbolEffect(.pulse, options: .repeating)
        .animation(.bouncy, value: privacy.isMicrophoneInUse)
        .animation(.bouncy, value: privacy.isCameraInUse)
    }
}

/// Os pontinhos coloridos que o macOS também mostra na barra de menus.
private struct PrivacyDots: View {
    let privacy: PrivacyMonitor

    var body: some View {
        HStack(spacing: 4) {
            if privacy.isMicrophoneInUse { dot(.orange) }
            if privacy.isCameraInUse { dot(.green) }
        }
    }

    private func dot(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .shadow(color: color, radius: 3)
    }
}
