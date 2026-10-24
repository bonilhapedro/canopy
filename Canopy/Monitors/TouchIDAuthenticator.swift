import LocalAuthentication
import Observation

/// Pede o dedo no Touch ID e conta à ilha como foi, no estilo do Face ID do iPhone.
@MainActor
@Observable
final class TouchIDAuthenticator {
    enum State {
        case idle, scanning, success, failure
    }

    private(set) var state = State.idle
    @ObservationIgnored var onChange: (() -> Void)?
    /// O contexto precisa viver até a resposta chegar.
    @ObservationIgnored private var context: LAContext?

    var isAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    func authenticate(reason: String) {
        guard state != .scanning else { return }
        let context = LAContext()
        context.localizedFallbackTitle = ""
        self.context = context
        set(.scanning)
        // A resposta chega numa fila do sistema; o @Sendable evita que o Swift 6 presuma a main thread.
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { @Sendable success, _ in
            Task { @MainActor in self.finish(success: success) }
        }
    }

    private func finish(success: Bool) {
        context = nil
        set(success ? .success : .failure)
    }

    private func set(_ newState: State) {
        state = newState
        onChange?()
    }
}
