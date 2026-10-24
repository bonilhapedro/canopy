import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let coordinator = IslandCoordinator()
    private var windowController: NotchWindowController?
    private var screenObserver: NSObjectProtocol?
    private var clickMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = NotchWindowController(coordinator: coordinator)
        controller.show()
        windowController = controller

        // Monitor ligado, desligado ou resolução trocada: reposiciona a ilha.
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.windowController?.reposition() }
        }

        // Um clique em qualquer outro app fecha a ilha aberta.
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.coordinator.dismiss() }
        }
    }
}
