import AppKit

/// Descobre se o app da frente está em tela cheia na tela da ilha.
@MainActor
final class FullscreenMonitor {
    var onChange: ((Bool) -> Void)?
    /// Tamanho da tela da ilha, em pontos.
    var screenSize: () -> CGSize? = { nil }
    private(set) var isFullscreen = false
    private var observers: [NSObjectProtocol] = []
    private var recheck: Task<Void, Never>?

    func start() {
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.activeSpaceDidChangeNotification, NSWorkspace.didActivateApplicationNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.scheduleCheck() }
            })
        }
        check()
    }

    /// A troca de Space anima; confere de novo quando a animação termina.
    private func scheduleCheck() {
        check()
        recheck?.cancel()
        recheck = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }
            self?.check()
        }
    }

    func check() {
        let fullscreen = Self.frontmostCoversScreen(size: screenSize())
        guard fullscreen != isFullscreen else { return }
        isFullscreen = fullscreen
        onChange?(fullscreen)
    }

    /// Uma janela normal do app da frente do tamanho exato da tela é tela cheia.
    /// A lista de janelas dá o tamanho sem pedir permissão de gravação de tela.
    private static func frontmostCoversScreen(size: CGSize?) -> Bool {
        guard let size, let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
        else { return false }
        return windows.contains { info in
            guard (info[kCGWindowOwnerPID as String] as? Int).map(pid_t.init) == pid,
                  info[kCGWindowLayer as String] as? Int == 0,
                  let bounds = info[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary)
            else { return false }
            return abs(rect.width - size.width) < 1 && abs(rect.height - size.height) < 1
        }
    }
}
