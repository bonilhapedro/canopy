import AppKit
import CanopyCore
import SwiftUI

struct IslandView: View {
    @Environment(IslandCoordinator.self) private var coordinator
    @Environment(TimerController.self) private var timer
    @AppStorage(SettingsKey.glassIsland) private var glassIsland = true
    @AppStorage(SettingsKey.glassDarkness) private var glassDarkness = 0.25
    /// Onde o mouse está sobre a ilha, para o reflexo na borda de vidro.
    /// Fica num objeto à parte para não redesenhar a ilha inteira a cada movimento.
    @State private var light = PointerLight()

    var body: some View {
        let phase = coordinator.phase
        let size = coordinator.layout.size(for: phase)
        let metrics = Metrics(phase: phase)
        let shape = NotchShape(earRadius: metrics.ear, bottomRadius: metrics.bottom)
        let glow = coordinator.primary?.accent ?? .white
        let usesGlass = glassIsland && phase == .expanded
        let outerSize = CGSize(width: size.width + 2 * metrics.ear, height: size.height)
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
                    .glassEffect(.clear.tint(Color.black.opacity(0.06 + 0.6 * glassDarkness)), in: shape)
                    .opacity(usesGlass ? 1 : 0)
                Color.black
                    .opacity(usesGlass ? 0 : 1)
                if phase == .expanded {
                    if usesGlass {
                        // Um brilho leve na cor da atividade, sem tapar o que está atrás do vidro.
                        RadialGradient(
                            colors: [glow.opacity(0.18), glow.opacity(0)],
                            center: .bottomLeading,
                            startRadius: 10,
                            endRadius: size.width * 0.8
                        )
                        .transition(.opacity)
                    } else {
                        coordinator.primary?.backdrop
                    }
                }
                if usesGlass {
                    // Preto no topo que se dissolve no vidro, para o notch de verdade continuar parecendo parte da ilha.
                    LinearGradient(
                        stops: [
                            .init(color: .black, location: 0),
                            .init(color: .black, location: 0.45),
                            .init(color: .black.opacity(0), location: 1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: coordinator.layout.notch.height + 30)
                    .transition(.opacity)
                }
            }
        }
        .clipShape(shape)
        .overlay {
            // Borda fina de vidro: clara embaixo, onde a luz bate, e some no topo preto.
            shape
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0), glow.opacity(0.35), Color.white.opacity(0.28)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
                .opacity(usesGlass ? 1 : 0)
        }
        .overlay {
            if usesGlass {
                GlassHighlight(light: light, shape: shape, size: outerSize)
            }
        }
        .contentShape(shape)
        .shadow(color: .black.opacity(phase == .expanded ? 0.35 : 0), radius: 18, y: 8)
        .shadow(color: glow.opacity(phase == .expanded ? 0.22 : 0), radius: 24)
        .onHover { coordinator.pointer(inside: $0) }
        .onContinuousHover { hover in
            switch hover {
            case .active(let point): light.point = point
            case .ended: light.point = nil
            }
        }
        .onTapGesture { coordinator.click() }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(morph, value: phase)
        .animation(morph, value: size)
        .onChange(of: phase) { _, newPhase in
            // Um toque leve no trackpad quando a ilha abre.
            if newPhase == .expanded, Preferences.haptics {
                NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
            }
        }
        .onChange(of: coordinator.currentPage) {
            if Preferences.haptics {
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
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
        let page = coordinator.currentPage
        let step = coordinator.pageStep
        return VStack(spacing: 0) {
            IslandHeader()
                .frame(height: coordinator.layout.notch.height)
            ZStack {
                pageContent(page)
                    .id(page)
                    .transition(
                        AnyTransition.asymmetric(
                            insertion: .offset(x: 46 * CGFloat(step)),
                            removal: .offset(x: -46 * CGFloat(step))
                        )
                        .combined(with: AnyTransition(.blurReplace))
                    )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.top, 8)
            .padding([.horizontal, .bottom], 22)
            .animation(.smooth(duration: 0.38), value: page)
        }
    }

    @ViewBuilder
    private func pageContent(_ page: IslandPage) -> some View {
        switch page {
        case .now:
            VStack(alignment: .leading, spacing: 10) {
                if let primary = coordinator.primary {
                    primary.expanded
                }
                if !coordinator.secondary.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(coordinator.secondary, id: \.id) { activity in
                            activity.minimal
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .glassEffect(.clear, in: Capsule())
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        case .home:
            HomePage()
        case .weather:
            WeatherPage()
        case .timer:
            TimerPage(timer: timer)
        }
    }
}

/// Faixa do topo da ilha aberta, dos dois lados do notch: abas à esquerda, bateria à direita.
private struct IslandHeader: View {
    @Environment(IslandCoordinator.self) private var coordinator
    @Namespace private var tabs

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 2) {
                ForEach(coordinator.pages, id: \.self) { page in
                    let isSelected = page == coordinator.currentPage
                    Button {
                        coordinator.select(page)
                    } label: {
                        Image(systemName: symbol(for: page))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.4))
                            .frame(width: 28, height: 20)
                            .background {
                                if isSelected {
                                    Capsule()
                                        .fill(Color.white.opacity(0.16))
                                        .matchedGeometryEffect(id: "selected", in: tabs)
                                }
                            }
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.snappy(duration: 0.3), value: coordinator.currentPage)
            .animation(.snappy(duration: 0.3), value: coordinator.pages)

            Spacer(minLength: coordinator.layout.notch.width + 16)

            HeaderBattery()
        }
        .padding(.horizontal, 20)
        .entrance(0)
    }

    private func symbol(for page: IslandPage) -> String {
        switch page {
        case .now: coordinator.primary?.tabSymbol ?? "sparkles"
        case .home: "calendar"
        case .weather: "cloud.sun.fill"
        case .timer: "timer"
        }
    }
}

/// Bateria pequena no canto direito, como na barra de status do iPhone.
private struct HeaderBattery: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { _ in
            if let battery = BatteryMonitor.read() {
                let tint: Color = battery.isCharging ? .green : battery.percent <= 20 ? .red : .white
                HStack(spacing: 5) {
                    Text("\(battery.percent)%")
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.75))
                    BatteryGlyph(percent: battery.percent, isCharging: battery.isCharging, tint: tint, width: 22)
                }
            }
        }
    }
}

@MainActor
@Observable
final class PointerLight {
    var point: CGPoint?
}

/// Reflexo que acompanha o mouse: a borda acende perto dele e o vidro ganha um brilho suave.
private struct GlassHighlight: View {
    let light: PointerLight
    let shape: NotchShape
    let size: CGSize

    var body: some View {
        let point = light.point ?? CGPoint(x: size.width / 2, y: size.height)
        let center = UnitPoint(
            x: size.width > 0 ? point.x / size.width : 0.5,
            y: size.height > 0 ? point.y / size.height : 1
        )
        ZStack {
            RadialGradient(
                colors: [Color.white.opacity(0.08), Color.white.opacity(0)],
                center: center,
                startRadius: 0,
                endRadius: 220
            )
            .clipShape(shape)
            shape
                .stroke(
                    RadialGradient(
                        colors: [Color.white.opacity(0.8), Color.white.opacity(0)],
                        center: center,
                        startRadius: 0,
                        endRadius: 150
                    ),
                    lineWidth: 1.5
                )
                .blendMode(.plusLighter)
        }
        .opacity(light.point == nil ? 0 : 1)
        .animation(.smooth(duration: 0.3), value: light.point == nil)
        .allowsHitTesting(false)
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
