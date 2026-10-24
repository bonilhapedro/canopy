import SwiftUI

/// Faz um elemento surgir subindo e desfocando para nítido, com um atraso pela ordem,
/// para o conteúdo da ilha aberta entrar em cascata.
private struct Entrance: ViewModifier {
    let order: Int
    @State private var isShown = false

    func body(content: Content) -> some View {
        content
            .opacity(isShown ? 1 : 0)
            .offset(y: isShown ? 0 : 8)
            .blur(radius: isShown ? 0 : 5)
            .scaleEffect(isShown ? 1 : 0.97)
            .onAppear {
                withAnimation(.smooth(duration: 0.42).delay(0.06 + Double(order) * 0.05)) {
                    isShown = true
                }
            }
    }
}

extension View {
    func entrance(_ order: Int) -> some View {
        modifier(Entrance(order: order))
    }
}
