import SwiftUI

/// Botão redondo da ilha: acende ao passar o mouse e encolhe com mola ao clicar.
struct IslandButtonStyle: ButtonStyle {
    var size: CGFloat = 32

    func makeBody(configuration: Configuration) -> some View {
        IslandButton(configuration: configuration, size: size)
    }
}

private struct IslandButton: View {
    let configuration: ButtonStyleConfiguration
    let size: CGFloat
    @State private var isHovered = false

    var body: some View {
        configuration.label
            .frame(width: size, height: size)
            .background(Circle().fill(Color.white.opacity(isHovered ? 0.14 : 0)))
            .contentShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.84 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.55), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .onHover { isHovered = $0 }
    }
}
