import CanopyCore
import SwiftUI

/// Aviso rápido de saída de áudio nova, como os AirPods conectando no iPhone.
@MainActor
final class OutputActivity: IslandActivity {
    static let activityID = "output"

    let id = OutputActivity.activityID
    let priority = ActivityPriority.alert
    let accent: Color? = .white
    private let kind: AudioOutputKind
    private let name: String

    init(kind: AudioOutputKind, name: String) {
        self.kind = kind
        self.name = name
    }

    var tabSymbol: String { kind.symbol }

    var compactLeading: AnyView { AnyView(DeviceGlyph(kind: kind, size: 15)) }
    var compactTrailing: AnyView {
        AnyView(
            Text(kind.shortName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
                .frame(maxWidth: 70, alignment: .trailing)
        )
    }
    var minimal: AnyView { AnyView(DeviceGlyph(kind: kind, size: 11)) }
    var expanded: AnyView {
        AnyView(
            HStack(spacing: 20) {
                DeviceGlyph(kind: kind, size: 48)
                    .frame(width: 80)
                    .entrance(0)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Saída de áudio")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                    MarqueeText(text: name, size: 22, weight: .bold)
                    Label("Conectado", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.green)
                }
                .entrance(1)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        )
    }
}

private struct DeviceGlyph: View {
    let kind: AudioOutputKind
    let size: CGFloat
    @State private var bounced = 0

    var body: some View {
        Image(systemName: kind.symbol)
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(.white)
            .shadow(color: .white.opacity(0.35), radius: size * 0.25)
            .symbolEffect(.bounce, value: bounced)
            .task {
                try? await Task.sleep(for: .milliseconds(250))
                bounced += 1
            }
    }
}
