import CanopyCore
import SwiftUI

/// Atividade de exemplo da Fase 0: um contador de tempo, só para testar os estados da ilha.
@MainActor
final class DemoActivity: IslandActivity {
    static let activityID = "demo"

    let id = DemoActivity.activityID
    let priority = ActivityPriority.normal
    private let startedAt = Date.now

    var compactLeading: AnyView {
        AnyView(Image(systemName: "sparkles").foregroundStyle(.yellow))
    }

    var compactTrailing: AnyView {
        AnyView(
            Text(startedAt, style: .timer)
                .monospacedDigit()
                .foregroundStyle(.white)
        )
    }

    var minimal: AnyView {
        AnyView(Image(systemName: "sparkles").foregroundStyle(.yellow))
    }

    var expanded: AnyView {
        AnyView(
            VStack(alignment: .leading, spacing: 6) {
                Label("Atividade de teste", systemImage: "sparkles")
                    .font(.headline)
                Text(startedAt, style: .timer)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text("Confirma que o notch abre, fecha e mostra atividades.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.white)
        )
    }
}
