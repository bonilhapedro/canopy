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

    var compactLeading: AnyView { AnyView(PrivacyIcons(privacy: privacy)) }
    var compactTrailing: AnyView {
        AnyView(Text("Em uso").font(.caption).foregroundStyle(.white.opacity(0.8)))
    }
    var minimal: AnyView { AnyView(PrivacyIcons(privacy: privacy)) }
    var expanded: AnyView { AnyView(PrivacyExpandedView(privacy: privacy)) }
}

private struct PrivacyIcons: View {
    let privacy: PrivacyMonitor

    var body: some View {
        HStack(spacing: 4) {
            if privacy.isMicrophoneInUse {
                Image(systemName: "mic.fill").foregroundStyle(.orange)
            }
            if privacy.isCameraInUse {
                Image(systemName: "video.fill").foregroundStyle(.green)
            }
        }
        .font(.caption)
    }
}

private struct PrivacyExpandedView: View {
    let privacy: PrivacyMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if privacy.isMicrophoneInUse {
                Label("Microfone em uso", systemImage: "mic.fill")
                    .foregroundStyle(.orange)
            }
            if privacy.isCameraInUse {
                Label("Câmera em uso", systemImage: "video.fill")
                    .foregroundStyle(.green)
            }
        }
        .font(.headline)
    }
}
