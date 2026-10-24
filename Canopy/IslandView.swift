import AppKit
import CanopyCore
import SwiftUI

struct IslandView: View {
    @Environment(IslandCoordinator.self) private var coordinator
    @AppStorage(SettingsKey.glassIsland) private var glassIsland = true

    var body: some View {
        let phase = coordinator.phase
        let size = coordinator.layout.size(for: phase)
        let metrics = Metrics(phase: phase)
        let shape = NotchShape(earRadius: metrics.ear, bottomRadius: metrics.bottom)
        let glow = coordinator.primary?.accent ?? .white
        let usesGlass = glassIsland && phase == .expanded
        // Crescer quica; encolher não, senão o quique passa do tamanho final e a ilha some por um instante.
        let morph: Animation = coordinator.lastChangeGrew
            ? .bouncy(duration: 0.45, extraBounce: 0.1)
            : .smooth(duration: 0.36)

        ZStack(alignment: .top) {
            content(for: phase)
                .id(phase)
                .transition(.blurReplace.combined(with: .scale(0.94, anchor: .top)))
        }
        .frame(width: size.width, height: size.height)
        .padding(.horizontal, metrics.ear)
        .background {
            ZStack(alignment: .top) {
                // Liquid Glass só na ilha aberta: fechada e compacta, ela precisa ser preta
                // para se confundir com o notch.
                Color.clear
                    .glassEffect(.regular.tint(Color.black.opacity(0.35)), in: shape)
                    .opacity(usesGlass ? 1 : 0)
                Color.black
                    .opacity(usesGlass ? 0 : 1)
                if phase == .expanded {
                    coordinator.primary?.backdrop
                        .opacity(usesGlass ? 0.65 : 1)
                }
                if usesGlass {
                    // Faixa preta no topo, para o notch de verdade continuar parecendo parte da ilha.
                    LinearGradient(
                        stops: [
                            .init(color: .black, location: 0),
                            .init(color: .black, location: 0.55),
                            .init(color: .black.opacity(0), location: 1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: coordinator.layout.notch.height + 22)
                    .transition(.opacity)
                }
            }
        }
        .clipShape(shape)
        .overlay {
            shape
                .stroke(Color.white.opacity(phase == .expanded ? 0.09 : 0), lineWidth: 1)
        }
        .contentShape(shape)
        .shadow(color: .black.opacity(phase == .expanded ? 0.55 : 0), radius: 18, y: 8)
        .shadow(color: glow.opacity(phase == .expanded ? 0.28 : 0), radius: 24)
        .onHover { coordinator.pointer(inside: $0) }
        .onTapGesture { coordinator.click() }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(morph, value: phase)
        .animation(morph, value: size)
        .onChange(of: phase) { _, newPhase in
            // Um toque leve no trackpad quando a ilha abre.
            if newPhase == .expanded {
                NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
            }
        }
        .environment(\.colorScheme, .dark)
        .fontDesign(.rounded)
    }

    @ViewBuilder
    private func content(for phase: IslandPhase) -> some View {
        switch phase {
        case .closed:
            Color.clear
        case .compact:
            compactContent
        case .expanded:
            expandedContent
        }
    }

    private var compactContent: some View {
        HStack(spacing: 0) {
            coordinator.primary?.compactLeading
            Spacer(minLength: coordinator.layout.notch.width)
            coordinator.primary?.compactTrailing
        }
        .padding(.horizontal, 12)
        .frame(maxHeight: .infinity)
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let primary = coordinator.primary {
                primary.expanded
            } else {
                IdleView()
            }
            if !coordinator.secondary.isEmpty {
                HStack(spacing: 8) {
                    ForEach(coordinator.secondary, id: \.id) { activity in
                        activity.minimal
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .glassEffect(.regular, in: Capsule())
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, coordinator.layout.notch.height + 8)
        .padding([.horizontal, .bottom], 22)
    }
}

/// Raio das "orelhas" e dos cantos de baixo em cada estado.
private struct Metrics {
    let ear: CGFloat
    let bottom: CGFloat

    init(phase: IslandPhase) {
        switch phase {
        case .closed:
            // Fechada, a ilha cobre exatamente o notch, sem orelhas à mostra.
            ear = 0
            bottom = 8
        case .compact:
            ear = 6
            bottom = 12
        case .expanded:
            ear = 12
            bottom = 32
        }
    }
}

/// Ilha aberta sem nenhuma atividade: saudação, hora, data e bateria.
private struct IdleView: View {
    var body: some View {
        TimelineView(.everyMinute) { context in
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(greeting(for: context.date))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text(context.date, format: .dateTime.hour().minute())
                        .font(.system(size: 46, weight: .semibold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text(context.date, format: .dateTime.weekday(.wide).day().month(.wide))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if let battery = BatteryMonitor.read() {
                    BatteryRing(percent: battery.percent, isCharging: battery.isCharging)
                }
            }
            .foregroundStyle(.white)
            .frame(maxHeight: .infinity)
        }
    }

    private func greeting(for date: Date) -> String {
        switch Calendar.current.component(.hour, from: date) {
        case 5..<12: "Bom dia"
        case 12..<18: "Boa tarde"
        default: "Boa noite"
        }
    }
}
