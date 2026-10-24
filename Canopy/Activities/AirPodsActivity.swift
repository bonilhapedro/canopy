import AppKit
import CanopyCore
import SwiftUI

/// AirPods conectando, como no iPhone: a ilha abre com o fone girando para a frente
/// e os anéis de bateria dos fones e do estojo se enchendo.
///
/// Tudo é animação de uma vez só, ao aparecer; depois a ilha não redesenha nada
/// até a bateria chegar do Bluetooth.
@MainActor
final class AirPodsActivity: IslandActivity {
    static let activityID = "airpods"

    let id = AirPodsActivity.activityID
    let priority = ActivityPriority.alert
    let accent: Color? = .white
    private let monitor: AirPodsMonitor
    private let model: AirPodsModel
    private let name: String

    init(monitor: AirPodsMonitor, status: AirPodsStatus) {
        self.monitor = monitor
        model = status.model
        name = status.name
    }

    var tabSymbol: String { SymbolName.first(of: model.pairSymbols) }

    var compactLeading: AnyView { AnyView(AirPodsHero(model: model, size: 15, ripples: false)) }
    var compactTrailing: AnyView { AnyView(CompactBattery(monitor: monitor)) }
    var minimal: AnyView { AnyView(AirPodsHero(model: model, size: 11, ripples: false)) }

    var expanded: AnyView {
        AnyView(
            HStack(spacing: 18) {
                AirPodsHero(model: model, size: 54, ripples: true)
                    .frame(width: 92, height: 92)
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                    MarqueeText(text: name, size: 20, weight: .bold)
                    Label("Conectado", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.green)
                }
                .entrance(1)
                ExpandedBattery(monitor: monitor, model: model)
                    .entrance(2)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        )
    }
}

/// O fone que entra girando de lado para a frente, com um brilho e, aberto, duas ondas
/// saindo dele como no pareamento do iPhone. As ondas acontecem uma vez e somem.
private struct AirPodsHero: View {
    let model: AirPodsModel
    let size: CGFloat
    let ripples: Bool
    @State private var isShown = false
    @State private var rippled = false

    var body: some View {
        ZStack {
            if ripples {
                ForEach(0..<2, id: \.self) { index in
                    Circle()
                        .stroke(Color.white.opacity(rippled ? 0 : 0.5), lineWidth: 1.5)
                        .frame(width: size * 1.1, height: size * 1.1)
                        .scaleEffect(rippled ? 1.7 : 0.8)
                        .animation(.easeOut(duration: 1.2).delay(0.35 + Double(index) * 0.3), value: rippled)
                }
            }
            Image(systemName: SymbolName.first(of: model.pairSymbols))
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(
                    LinearGradient(colors: [.white, .white.opacity(0.78)], startPoint: .top, endPoint: .bottom)
                )
                .shadow(color: .white.opacity(isShown ? 0.4 : 0), radius: size * 0.3)
                .rotation3DEffect(.degrees(isShown ? 0 : -75), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
                .scaleEffect(isShown ? 1 : 0.55)
                .opacity(isShown ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.62).delay(0.08)) { isShown = true }
            if ripples { rippled = true }
        }
    }
}

/// Ao lado do notch: um anel pequeno com a carga do fone mais fraco.
private struct CompactBattery: View {
    let monitor: AirPodsMonitor

    var body: some View {
        let percent = monitor.status?.battery.budsPercent
        let tint = (percent ?? 100) <= AirPodsGauge.lowThreshold ? Color.red : .green
        HStack(spacing: 5) {
            if let percent {
                Text("\(percent)%")
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(tint)
                    .contentTransition(.numericText())
            }
            GaugeRing(percent: percent ?? 0, tint: tint, lineWidth: 2.5)
                .frame(width: 15, height: 15)
        }
        .animation(.smooth, value: percent)
    }
}

/// Os anéis da ilha aberta: fones (juntos ou um de cada lado) e estojo.
/// Antes da bateria chegar, um anel vazio diz que ela está a caminho.
private struct ExpandedBattery: View {
    let monitor: AirPodsMonitor
    let model: AirPodsModel

    var body: some View {
        let gauges = monitor.status?.battery.gauges ?? []
        HStack(spacing: 14) {
            if gauges.isEmpty {
                GaugeView(symbol: SymbolName.first(of: model.pairSymbols), percent: nil, order: 0)
            } else {
                ForEach(Array(gauges.enumerated()), id: \.element.id) { index, gauge in
                    GaugeView(symbol: SymbolName.first(of: symbols(for: gauge.part)), percent: gauge.percent, order: index)
                        .transition(.blurReplace)
                }
            }
        }
        .animation(.smooth(duration: 0.4), value: gauges)
    }

    private func symbols(for part: AirPodsGauge.Part) -> [String] {
        switch part {
        case .buds, .headphones: model.pairSymbols
        case .left: model.budSymbols(left: true)
        case .right: model.budSymbols(left: false)
        case .chargingCase: model.caseSymbols
        }
    }
}

private struct GaugeView: View {
    let symbol: String
    let percent: Int?
    let order: Int

    var body: some View {
        let tint = (percent ?? 100) <= AirPodsGauge.lowThreshold ? Color.red : .green
        VStack(spacing: 6) {
            ZStack {
                GaugeRing(percent: percent ?? 0, tint: tint, lineWidth: 4.5, delay: 0.3 + Double(order) * 0.12)
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .frame(width: 50, height: 50)
            Text(percent.map { "\($0)%" } ?? "–")
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(percent == nil ? Color.white.opacity(0.4) : Color.white)
                .contentTransition(.numericText())
        }
    }
}

/// Anel de carga que se enche uma vez ao aparecer e depois só anda quando a carga muda.
private struct GaugeRing: View {
    let percent: Int
    let tint: Color
    let lineWidth: CGFloat
    var delay: Double = 0.2
    @State private var isFilled = false

    var body: some View {
        let level = isFilled ? CGFloat(min(max(percent, 0), 100)) / 100 : 0
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.14), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: level)
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: tint.opacity(0.55), radius: lineWidth * 1.4)
        }
        .animation(.smooth(duration: 0.6), value: percent)
        .onAppear {
            withAnimation(.smooth(duration: 0.9).delay(delay)) { isFilled = true }
        }
    }
}
