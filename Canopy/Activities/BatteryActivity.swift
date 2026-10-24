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

    private var symbol: String {
        switch event {
        case .pluggedIn: "battery.100percent.bolt"
        case .unplugged: "battery.75percent"
        case .low: "battery.25percent"
        }
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

    var compactLeading: AnyView {
        AnyView(Image(systemName: symbol).foregroundStyle(tint))
    }

    var compactTrailing: AnyView {
        AnyView(Text("\(snapshot.percent)%").monospacedDigit().foregroundStyle(tint))
    }

    var minimal: AnyView { compactLeading }

    var expanded: AnyView {
        AnyView(
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 36))
                    .foregroundStyle(tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(message)
                        .font(.headline)
                    Text("\(snapshot.percent)%")
                        .font(.title2.weight(.semibold))
                        .monospacedDigit()
                }
            }
            .foregroundStyle(.white)
        )
    }
}
