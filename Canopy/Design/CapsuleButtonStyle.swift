import SwiftUI

/// Botão em cápsula de Liquid Glass, para ações com texto como "+1 min" ou "Entrar".
struct CapsuleButtonStyle: ButtonStyle {
    var tint: Color = .white
    var isProminent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(isProminent ? Color.black : Color.white)
            .padding(.horizontal, 14)
            .frame(height: 30)
            .glassEffect(
                isProminent ? .regular.tint(tint).interactive() : .clear.interactive(),
                in: Capsule()
            )
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
