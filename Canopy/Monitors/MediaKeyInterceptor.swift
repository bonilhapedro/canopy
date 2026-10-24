import AppKit
import ApplicationServices

/// Pega as teclas de volume e brilho antes do macOS, para o Canopy fazer a mudança
/// e mostrar só o indicador dele. Precisa da permissão de Acessibilidade.
@MainActor
final class MediaKeyInterceptor {
    enum Key {
        case volumeUp, volumeDown, mute, brightnessUp, brightnessDown
    }

    /// Recebe a tecla e se é o passo fino (Option+Shift). Devolve true se tratou,
    /// e aí o macOS não vê a tecla nem mostra o indicador dele.
    var handler: ((Key, Bool) -> Bool)?

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var consumedKeys: Set<Int> = []
    private var hasPrompted = false
    /// Enquanto falta a permissão: o aviso do macOS de que a lista de Acessibilidade mudou
    /// e a volta para o Canopy, para o caso de o aviso se perder.
    private var trustObserver: NSObjectProtocol?
    private var activationObserver: NSObjectProtocol?
    private var retryTask: Task<Void, Never>?

    var isRunning: Bool { tap != nil }

    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Liga ou desliga. Sem a permissão, pede uma vez e espera o macOS avisar que ela foi dada.
    func setEnabled(_ enabled: Bool) {
        guard enabled else {
            stop()
            return
        }
        guard !isRunning else { return }
        if Self.isTrusted, install() { return }
        if !hasPrompted {
            hasPrompted = true
            Self.requestTrust()
        }
        waitForTrust()
    }

    private func waitForTrust() {
        guard trustObserver == nil else { return }
        trustObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.accessibility.api"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.retryInstall() }
        }
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.retryInstall() }
        }
    }

    /// O aviso chega um pouco antes de a permissão valer, e logo depois de liberar o macOS às vezes
    /// ainda recusa o tap: tenta algumas vezes, cada vez com mais calma, e volta a esperar.
    private func retryInstall() {
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            for delay in [0.3, 1.0, 3.0] {
                try? await Task.sleep(for: .seconds(delay))
                guard let self, !Task.isCancelled, !self.isRunning else { return }
                if MediaKeyInterceptor.isTrusted, self.install() {
                    self.stopWaitingForTrust()
                    return
                }
            }
        }
    }

    private func stopWaitingForTrust() {
        if let trustObserver { DistributedNotificationCenter.default().removeObserver(trustObserver) }
        if let activationObserver { NotificationCenter.default.removeObserver(activationObserver) }
        trustObserver = nil
        activationObserver = nil
        retryTask?.cancel()
        retryTask = nil
    }

    /// Mostra o pedido do macOS para liberar o Canopy em Acessibilidade.
    static func requestTrust() {
        // O valor de kAXTrustedCheckOptionPrompt, escrito direto para não tocar na variável global do C.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @discardableResult
    private func install() -> Bool {
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1 << 14),
            callback: mediaKeyTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        self.source = source
        return true
    }

    private func stop() {
        stopWaitingForTrust()
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
        consumedKeys = []
    }

    fileprivate func reenable() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
    }

    fileprivate func handle(_ event: CGEvent) -> Bool {
        guard let systemEvent = NSEvent(cgEvent: event),
              systemEvent.type == .systemDefined,
              systemEvent.subtype.rawValue == 8
        else { return false }
        let data = systemEvent.data1
        let code = (data & 0xFFFF_0000) >> 16
        let state = (data & 0xFF00) >> 8
        guard let key = Self.key(for: code) else { return false }

        // Soltar a tecla: some junto se o aperto foi tratado.
        if state == 0x0B {
            return consumedKeys.remove(code) != nil
        }
        guard state == 0x0A else { return false }

        let modifiers = systemEvent.modifierFlags
        // Option sozinho abre os Ajustes de Som ou de Telas; isso fica com o macOS.
        if modifiers.contains(.option) && !modifiers.contains(.shift) { return false }
        let fine = modifiers.contains(.option) && modifiers.contains(.shift)

        guard handler?(key, fine) == true else { return false }
        consumedKeys.insert(code)
        return true
    }

    private static func key(for code: Int) -> Key? {
        switch code {
        case 0: .volumeUp
        case 1: .volumeDown
        case 2: .brightnessUp
        case 3: .brightnessDown
        case 7: .mute
        default: nil
        }
    }
}

/// Chamada pelo macOS a cada tecla de mídia. É uma função solta porque o tap só aceita um ponteiro de função C.
private func mediaKeyTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let interceptor = Unmanaged<MediaKeyInterceptor>.fromOpaque(refcon).takeUnretainedValue()
    // O tap está na run loop principal, então tudo aqui já roda na main thread.
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        MainActor.assumeIsolated { interceptor.reenable() }
        return Unmanaged.passUnretained(event)
    }
    // NX_SYSDEFINED: é por onde chegam as teclas de mídia.
    guard type.rawValue == 14 else { return Unmanaged.passUnretained(event) }
    nonisolated(unsafe) let systemEvent = event
    let consumed = MainActor.assumeIsolated { interceptor.handle(systemEvent) }
    return consumed ? nil : Unmanaged.passUnretained(event)
}
