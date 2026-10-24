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
        BatteryGlyph(percent: snapshot.percent, isCharging: event == .pluggedIn, tint: tint, width: width, isLive: true)
    }

    var tabSymbol: String { event == .pluggedIn ? "bolt.fill" : "battery.50percent" }

    private var detail: String? {
        guard event == .pluggedIn else { return nil }
        guard let minutes = BatteryMonitor.minutesToFull() else { return snapshot.percent >= 100 ? "Carga completa" : nil }
        let hours = minutes / 60
        let rest = minutes % 60
        let time = hours > 0 ? "\(hours) h \(rest) min" : "\(rest) min"
        return "Completa em \(time)"
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
            HStack(spacing: 22) {
                glyph(width: 96)
                    .shadow(color: tint.opacity(0.55), radius: 14)
                    .entrance(0)
                VStack(alignment: .leading, spacing: 0) {
                    Text(message)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("\(snapshot.percent)%")
                        .font(.system(size: 40, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(tint)
                        .shadow(color: tint.opacity(0.4), radius: 10)
                    if let detail {
                        Text(detail)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
                .entrance(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        )
    }
}
