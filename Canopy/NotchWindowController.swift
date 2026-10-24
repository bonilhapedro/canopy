import AppKit
import CanopyCore
import SwiftUI

/// Os serviços que as páginas da ilha leem pelo ambiente do SwiftUI.
@MainActor
struct IslandServices {
    let calendar: CalendarMonitor
    let weather: WeatherService
    let timer: TimerController
}

@MainActor
final class NotchWindowController {
    private let panel = NotchPanel(
        contentRect: .zero,
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: false
    )
    private let coordinator: IslandCoordinator

    init(coordinator: IslandCoordinator, services: IslandServices) {
        self.coordinator = coordinator
        let root = IslandView()
            .environment(coordinator)
            .environment(services.calendar)
            .environment(services.weather)
            .environment(services.timer)
        let host = FirstMouseHostingView(rootView: root)
        // A janela tem tamanho fixo; o SwiftUI não deve redimensioná-la.
        host.sizingOptions = []
        host.onScroll = { [weak coordinator] event in
            coordinator?.scroll(event)
        }
        panel.contentView = host
    }

    /// A tela onde a ilha está.
    var screen: NSScreen? { panel.screen ?? NSScreen.withNotch ?? NSScreen.main }

    #if BENCHMARK
    var panelFrame: CGRect { panel.isVisible ? panel.frame : .zero }
    #endif

    func show() {
        reposition()
        applyPreferences()
        panel.orderFrontRegardless()
    }

    func reposition() {
        guard let screen = NSScreen.withNotch ?? NSScreen.main else { return }
        let geometry = NotchGeometry(
            screenFrame: screen.frame,
            auxiliaryTopLeftArea: screen.auxiliaryTopLeftArea,
            auxiliaryTopRightArea: screen.auxiliaryTopRightArea,
            safeAreaTop: screen.safeAreaInsets.top,
            menuBarHeight: NSStatusBar.system.thickness
        )
        coordinator.geometry = geometry
        panel.setFrame(coordinator.layout.panelFrame(notchRect: geometry.rect), display: true)
    }

    func applyPreferences() {
        // Fora de gravações e capturas de tela, como no Canopy original.
        panel.sharingType = Preferences.hideFromCapture ? .none : .readOnly
    }

    /// Some com a ilha, por exemplo com um app em tela cheia.
    func setHidden(_ hidden: Bool) {
        panel.ignoresMouseEvents = hidden
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            panel.animator().alphaValue = hidden ? 0 : 1
        }
        if hidden { coordinator.dismiss() }
    }
}

private extension NSScreen {
    /// A tela embutida do MacBook, que é a única com notch.
    static var withNotch: NSScreen? {
        screens.first { $0.safeAreaInsets.top > 0 }
    }
}

private extension IslandCoordinator {
    /// Converte o NSEvent em "quanto os dedos andaram", respeitando a rolagem natural.
    func scroll(_ event: NSEvent) {
        guard event.hasPreciseScrollingDeltas, event.momentumPhase.isEmpty else { return }
        let phase: SwipeTracker.Phase
        if event.phase.contains(.began) {
            phase = .began
        } else if event.phase.contains(.changed) {
            phase = .changed
        } else if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
            phase = .ended
        } else {
            return
        }
        let finger = event.isDirectionInvertedFromDevice ? event.scrollingDeltaX : -event.scrollingDeltaX
        scroll(fingerDeltaX: Double(finger), phase: phase)
    }
}

/// Aceita o primeiro clique mesmo com o Canopy em segundo plano e repassa o arrastar de dois dedos.
private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    var onScroll: (@MainActor (NSEvent) -> Void)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func scrollWheel(with event: NSEvent) {
        onScroll?(event)
        super.scrollWheel(with: event)
    }
}
