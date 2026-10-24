import SwiftUI

/// Botão redondo de Liquid Glass: reage ao mouse e encolhe com mola ao clicar.
struct IslandButtonStyle: ButtonStyle {
    var size: CGFloat = 32

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: size, height: size)
            .glassEffect(.regular.interactive(), in: Circle())
            .contentShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.86 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.55), value: configuration.isPressed)
    }
}
