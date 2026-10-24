import SwiftUI

/// Botão de glifo solto sobre o vidro, como no player do Canopy original.
/// Sem fundo próprio: ao passar o mouse surge uma gota de Liquid Glass atrás do ícone,
/// e ao clicar ele afunda com mola.
struct IslandButtonStyle: ButtonStyle {
    var size: CGFloat = 32

    func makeBody(configuration: Configuration) -> some View {
        GlyphButton(configuration: configuration, size: size)
    }
}

private struct GlyphButton: View {
    let configuration: ButtonStyleConfiguration
    let size: CGFloat
    @State private var isHovered = false

    var body: some View {
        configuration.label
            .foregroundStyle(.white.opacity(isHovered ? 1 : 0.92))
            .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
            .frame(width: size, height: size)
            .glassEffect(isHovered ? .clear.interactive() : .identity, in: Circle())
            .contentShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.82 : isHovered ? 1.06 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.55), value: configuration.isPressed)
            .animation(.smooth(duration: 0.2), value: isHovered)
            .onHover { isHovered = $0 }
    }
}
