import AppKit
import CanopyCore
import SwiftUI

@MainActor
final class NotchWindowController {
    private let panel = NotchPanel(
        contentRect: .zero,
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: false
    )
    private let coordinator: IslandCoordinator

    init(coordinator: IslandCoordinator) {
        self.coordinator = coordinator
        let host = FirstMouseHostingView(rootView: IslandView().environment(coordinator))
        // A janela tem tamanho fixo; o SwiftUI não deve redimensioná-la.
        host.sizingOptions = []
        panel.contentView = host
    }

    func show() {
        reposition()
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
}

private extension NSScreen {
    /// A tela embutida do MacBook, que é a única com notch.
    static var withNotch: NSScreen? {
        screens.first { $0.safeAreaInsets.top > 0 }
    }
}

/// Aceita o primeiro clique mesmo com o Canopy em segundo plano.
private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
