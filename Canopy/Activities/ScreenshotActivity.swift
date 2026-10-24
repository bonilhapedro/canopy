import CanopyCore
import SwiftUI

/// Aviso rápido de que uma captura de tela acabou de entrar na bandeja.
@MainActor
final class ScreenshotActivity: IslandActivity {
    static let activityID = "screenshot"

    let id = ScreenshotActivity.activityID
    let priority = ActivityPriority.alert
    let accent: Color? = .white
    private let count: Int

    init(count: Int) {
        self.count = count
    }

    var tabSymbol: String { "camera.viewfinder" }

    private var label: String {
        count == 1 ? "Na bandeja" : "\(count) na bandeja"
    }

    var compactLeading: AnyView {
        AnyView(
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
        )
    }
    var compactTrailing: AnyView {
        AnyView(
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
        )
    }
    var minimal: AnyView {
        AnyView(Image(systemName: "camera.viewfinder").font(.system(size: 11, weight: .semibold)))
    }
    var expanded: AnyView {
        AnyView(
            HStack(spacing: 16) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 40, weight: .medium))
                    .frame(width: 80)
                    .entrance(0)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Captura de tela")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                    Text(label)
                        .font(.system(size: 22, weight: .bold))
                }
                .entrance(1)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        )
    }
}
