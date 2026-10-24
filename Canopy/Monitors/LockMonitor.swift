import Foundation

/// Avisa quando o Mac é bloqueado e desbloqueado (senha, Touch ID ou Apple Watch).
/// O macOS não deixa um app de terceiros entrar na tela de bloqueio, então a ilha
/// reage logo depois, quando a mesa volta a aparecer.
@MainActor
final class LockMonitor {
    var onLock: (() -> Void)?
    var onUnlock: (() -> Void)?

    private var observers: [NSObjectProtocol] = []

    func start() {
        let center = DistributedNotificationCenter.default()
        observers.append(center.addObserver(
            forName: Notification.Name("com.apple.screenIsLocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.onLock?() }
        })
        observers.append(center.addObserver(
            forName: Notification.Name("com.apple.screenIsUnlocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.onUnlock?() }
        })
    }
}
