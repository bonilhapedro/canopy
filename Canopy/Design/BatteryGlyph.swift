import SwiftUI

/// Bateria desenhada à mão, com o nível preenchido e um raio quando está carregando.
struct BatteryGlyph: View {
    let percent: Int
    let isCharging: Bool
    let tint: Color
    var width: CGFloat = 26
    /// Carregando, o nível vira um líquido com a borda ondulando e um brilho que passa.
    var isLive = false

    var body: some View {
        let height = width * 0.48
        let level = CGFloat(min(max(percent, 0), 100)) / 100
        HStack(spacing: width * 0.04) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height * 0.3, style: .continuous)
                    .stroke(Color.white.opacity(0.45), lineWidth: max(1, width * 0.045))
                if isLive && isCharging {
                    LiquidLevel(level: level, tint: tint)
                        .frame(width: width - 4, height: height - 4)
                        .clipShape(RoundedRectangle(cornerRadius: height * 0.18, style: .continuous))
                        .padding(.leading, 2)
                } else {
                    RoundedRectangle(cornerRadius: height * 0.18, style: .continuous)
                        .fill(tint)
                        .frame(width: max(2, (width - 4) * level), height: height - 4)
                        .padding(.leading, 2)
                }
                if isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: height * 0.72, weight: .heavy))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 1)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(width: width, height: height)
            Capsule()
                .fill(Color.white.opacity(0.45))
                .frame(width: max(1.5, width * 0.07), height: height * 0.4)
        }
        .animation(.smooth(duration: 0.4), value: percent)
    }
}

/// Anel de carga usado na ilha aberta sem atividade.
struct BatteryRing: View {
    let percent: Int
    let isCharging: Bool

    private var tint: Color {
        if isCharging { return .green }
        return percent <= 20 ? .red : .white
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 6)
            Circle()
                .trim(from: 0, to: CGFloat(percent) / 100)
                .stroke(tint, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: tint.opacity(0.6), radius: 6)
            VStack(spacing: 0) {
                Image(systemName: isCharging ? "bolt.fill" : "battery.100percent")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(tint)
                Text("\(percent)%")
                    .font(.system(size: 15, weight: .semibold))
                    .monospacedDigit()
            }
        }
        .frame(width: 66, height: 66)
    }
}

/// O nível da bateria como líquido: a borda da direita ondula e um brilho atravessa.
private struct LiquidLevel: View {
    let level: CGFloat
    let tint: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            GeometryReader { geometry in
                let size = geometry.size
                ZStack(alignment: .leading) {
                    LiquidEdge(level: level, phase: time * 3.2, amplitude: max(1, size.height * 0.08))
                        .fill(LinearGradient(colors: [tint.opacity(0.75), tint], startPoint: .leading, endPoint: .trailing))
                    // O brilho que corre da esquerda para a direita, como no iPhone carregando.
                    let sweep = CGFloat((time * 0.6).truncatingRemainder(dividingBy: 1))
                    LinearGradient(
                        colors: [.white.opacity(0), .white.opacity(0.55), .white.opacity(0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: size.width * 0.35)
                    .offset(x: size.width * (sweep * 1.4 - 0.35))
                    .mask(LiquidEdge(level: level, phase: time * 3.2, amplitude: max(1, size.height * 0.08)))
                    .blendMode(.plusLighter)
                }
            }
        }
    }
}

private struct LiquidEdge: Shape {
    var level: CGFloat
    var phase: Double
    var amplitude: CGFloat

    func path(in rect: CGRect) -> Path {
        let edge = max(rect.width * level, 2)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: edge, y: rect.minY))
        let steps = 12
        for step in 0...steps {
            let y = rect.height * CGFloat(step) / CGFloat(steps)
            let wave = sin(Double(y / rect.height) * .pi * 2 + phase)
            path.addLine(to: CGPoint(x: min(edge + amplitude * CGFloat(wave), rect.maxX), y: y))
        }
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
