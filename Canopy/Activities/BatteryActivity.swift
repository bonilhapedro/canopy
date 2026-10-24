import CanopyCore
import SwiftUI

/// Aviso rápido de carregador ligado, desligado ou bateria fraca.
@MainActor
final class BatteryActivity: IslandActivity {
    static let activityID = "battery"

    let id = BatteryActivity.activityID
    let priority = ActivityPriority.alert
    private let event: BatteryEvent
    private let snapshot: BatterySnapshot

    init(event: BatteryEvent, snapshot: BatterySnapshot) {
        self.event = event
        self.snapshot = snapshot
    }

    private var tint: Color {
        switch event {
        case .pluggedIn: .green
        case .unplugged: .white
        case .low: .red
        }
    }

    private var message: String {
        switch event {
        case .pluggedIn: "Carregando"
        case .unplugged: "Usando a bateria"
        case .low: "Bateria fraca"
        }
    }

    private func glyph(width: CGFloat) -> BatteryGlyph {
        BatteryGlyph(percent: snapshot.percent, isCharging: event == .pluggedIn, tint: tint, width: width)
    }

    var compactLeading: AnyView { AnyView(glyph(width: 24)) }

    var compactTrailing: AnyView {
        AnyView(
            Text("\(snapshot.percent)%")
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(tint)
        )
    }

    var minimal: AnyView { AnyView(glyph(width: 20)) }
    var accent: Color? { tint }

    var expanded: AnyView {
        AnyView(
            HStack(spacing: 18) {
                glyph(width: 72)
                    .shadow(color: tint.opacity(0.5), radius: 10)
                VStack(alignment: .leading, spacing: 0) {
                    Text(message)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("\(snapshot.percent)%")
                        .font(.system(size: 34, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(tint)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        )
    }
}
