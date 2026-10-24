import SwiftUI

/// Dez segmentos que acendem com o nível, como no iPhone. Usado pelo volume e pelo brilho.
struct LevelSegments: View {
    /// De 0 a 1.
    let level: Double
    let tint: Color

    var body: some View {
        let lit = Int((level * 10).rounded(.up))
        HStack(spacing: 2) {
            ForEach(0..<10, id: \.self) { index in
                Capsule()
                    .fill(index < lit ? tint : Color.white.opacity(0.18))
                    .frame(width: 3, height: 6 + CGFloat(index) * 0.7)
            }
        }
        .animation(.snappy(duration: 0.15), value: lit)
    }
}

/// A barra larga da ilha aberta, com um brilho na ponta.
struct LevelBar: View {
    /// De 0 a 1.
    let level: Double
    let tint: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.16))
                Capsule()
                    .fill(LinearGradient(colors: [tint.opacity(0.7), tint], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(10, geometry.size.width * level))
                    .shadow(color: tint.opacity(0.6), radius: 6)
            }
        }
        .frame(height: 10)
        .animation(.snappy(duration: 0.18), value: level)
    }
}

/// O número ao lado da barra, que rola quando muda.
struct LevelPercent: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 20, weight: .semibold))
            .monospacedDigit()
            .contentTransition(.numericText())
            .frame(width: 56, alignment: .trailing)
    }
}
