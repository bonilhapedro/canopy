import CanopyCore
import SwiftUI

/// O cadeado que se abre na ilha logo depois de desbloquear o Mac, como o Face ID no iPhone.
@MainActor
final class UnlockActivity: IslandActivity {
    static let activityID = "unlock"

    let id = UnlockActivity.activityID
    let priority = ActivityPriority.alert
    let accent: Color? = .green

    var compactLeading: AnyView { AnyView(OpeningLock(size: 15)) }
    var compactTrailing: AnyView {
        AnyView(
            Image(systemName: "touchid")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.green)
                .symbolEffect(.bounce, options: .nonRepeating)
        )
    }
    var minimal: AnyView { AnyView(OpeningLock(size: 11)) }
    var expanded: AnyView {
        AnyView(
            VStack(spacing: 8) {
                OpeningLock(size: 40)
                Text("Bem-vindo de volta")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        )
    }
}

/// Começa fechado e abre com a animação nativa do SF Symbol.
struct OpeningLock: View {
    let size: CGFloat
    @State private var isOpen = false

    var body: some View {
        Image(systemName: isOpen ? "lock.open.fill" : "lock.fill")
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(isOpen ? Color.green : Color.white)
            .shadow(color: .green.opacity(isOpen ? 0.6 : 0), radius: size * 0.3)
            .contentTransition(.symbolEffect(.replace))
            .animation(.bouncy(duration: 0.4), value: isOpen)
            .task {
                try? await Task.sleep(for: .milliseconds(350))
                isOpen = true
            }
    }
}

/// O Touch ID lendo o dedo: digital pulsando, depois um check verde ou um X vermelho.
@MainActor
final class TouchIDActivity: IslandActivity {
    static let activityID = "touchid"

    let id = TouchIDActivity.activityID
    let priority = ActivityPriority.alert
    private let touchID: TouchIDAuthenticator

    init(touchID: TouchIDAuthenticator) {
        self.touchID = touchID
    }

    var accent: Color? { TouchIDGlyph.tint(for: touchID.state) }
    var compactLeading: AnyView { AnyView(TouchIDGlyph(touchID: touchID, size: 16)) }
    var compactTrailing: AnyView {
        AnyView(
            Text(TouchIDGlyph.label(for: touchID.state))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(TouchIDGlyph.tint(for: touchID.state))
                .contentTransition(.opacity)
        )
    }
    var minimal: AnyView { AnyView(TouchIDGlyph(touchID: touchID, size: 11)) }
    var expanded: AnyView {
        AnyView(
            VStack(spacing: 8) {
                TouchIDGlyph(touchID: touchID, size: 44)
                Text(TouchIDGlyph.label(for: touchID.state))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        )
    }
}

private struct TouchIDGlyph: View {
    let touchID: TouchIDAuthenticator
    let size: CGFloat

    var body: some View {
        let state = touchID.state
        Image(systemName: Self.symbol(for: state))
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(Self.tint(for: state))
            .shadow(color: Self.tint(for: state).opacity(0.6), radius: size * 0.3)
            .contentTransition(.symbolEffect(.replace))
            .symbolEffect(.pulse, options: .repeating, isActive: state == .scanning)
            .animation(.bouncy(duration: 0.4), value: state)
    }

    static func symbol(for state: TouchIDAuthenticator.State) -> String {
        switch state {
        case .idle, .scanning: "touchid"
        case .success: "checkmark.circle.fill"
        case .failure: "xmark.circle.fill"
        }
    }

    static func tint(for state: TouchIDAuthenticator.State) -> Color {
        switch state {
        case .idle, .scanning: .white
        case .success: .green
        case .failure: .red
        }
    }

    static func label(for state: TouchIDAuthenticator.State) -> String {
        switch state {
        case .idle, .scanning: "Touch ID"
        case .success: "Pronto"
        case .failure: "Falhou"
        }
    }
}
