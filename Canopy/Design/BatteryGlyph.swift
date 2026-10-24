import AppKit
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
                    LiquidLevel(level: level, tint: tint, cornerRadius: height * 0.18)
                        .frame(width: width - 4, height: height - 4)
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
/// Como no equalizador, quem anima é o Core Animation; o SwiftUI desenha uma vez só.
private struct LiquidLevel: NSViewRepresentable {
    let level: CGFloat
    let tint: Color
    let cornerRadius: CGFloat

    func makeNSView(context: Context) -> LiquidLevelView {
        LiquidLevelView()
    }

    func updateNSView(_ view: LiquidLevelView, context: Context) {
        view.update(level: level, tint: NSColor(tint), cornerRadius: cornerRadius)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: LiquidLevelView, context: Context) -> CGSize? {
        proposal.replacingUnspecifiedDimensions()
    }
}

private final class LiquidLevelView: NSView {
    private var level: CGFloat?
    private var tint = NSColor.clear
    /// Os cantos arredondados de dentro da bateria.
    private let clip = CALayer()
    /// O líquido: o degradê e o brilho, recortados pela borda ondulada.
    private let liquid = CALayer()
    private let fill = CAGradientLayer()
    private let sweep = CAGradientLayer()
    private let edge = CAShapeLayer()

    private static let waveKey = "wave"
    private static let sweepKey = "sweep"
    /// Uma volta da onda, em segundos.
    private static let wavePeriod = 2 * Double.pi / 3.2
    /// O tempo do brilho para atravessar a bateria.
    private static let sweepPeriod = 1 / 0.6

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        clip.masksToBounds = true
        clip.cornerCurve = .continuous
        for gradient in [fill, sweep] {
            gradient.startPoint = CGPoint(x: 0, y: 0.5)
            gradient.endPoint = CGPoint(x: 1, y: 0.5)
            liquid.addSublayer(gradient)
        }
        sweep.colors = [CGFloat(0), 0.55, 0].map { NSColor.white.withAlphaComponent($0).cgColor }
        liquid.mask = edge
        clip.addSublayer(liquid)
        layer?.addSublayer(clip)
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(level: CGFloat, tint: NSColor, cornerRadius: CGFloat) {
        if !tint.matches(self.tint) {
            self.tint = tint
            fill.colors = [tint.withAlphaComponent(0.75).cgColor, tint.cgColor]
        }
        if clip.cornerRadius != cornerRadius { clip.cornerRadius = cornerRadius }
        guard level != self.level else { return }
        self.level = level
        arrange()
    }

    override func setFrameSize(_ newSize: NSSize) {
        let resized = newSize != frame.size
        super.setFrameSize(newSize)
        // Refazer as animações reinicia a onda; mudar só de lugar não precisa disso.
        if resized { arrange() }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Fora da janela o Core Animation pode largar as animações; ao voltar, começam de novo.
        if window != nil { arrange() }
    }

    private func arrange() {
        let size = bounds.size
        guard let level, size.width > 0, size.height > 0 else { return }
        let rect = CGRect(origin: .zero, size: size)
        let amplitude = max(1, size.height * 0.08)
        let sweepWidth = size.width * 0.35
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for sublayer in [clip, liquid, fill, edge] { sublayer.frame = rect }
        edge.path = Self.edgePath(level: level, phase: 0, amplitude: amplitude, in: rect)
        sweep.bounds = CGRect(x: 0, y: 0, width: sweepWidth, height: size.height)
        // Parado, o brilho fica fora da bateria, à esquerda.
        sweep.position = CGPoint(x: -sweepWidth / 2, y: size.height / 2)
        CATransaction.commit()

        edge.removeAnimation(forKey: Self.waveKey)
        sweep.removeAnimation(forKey: Self.sweepKey)
        guard window != nil, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }

        // Uma volta da onda em 24 quadros; o Core Animation preenche o meio.
        let frames = 24
        let wave = CAKeyframeAnimation(keyPath: "path")
        wave.values = (0...frames).map { index in
            Self.edgePath(level: level, phase: 2 * .pi * Double(index) / Double(frames), amplitude: amplitude, in: rect)
        }
        wave.duration = Self.wavePeriod
        edge.add(Self.looping(wave), forKey: Self.waveKey)

        let pass = CABasicAnimation(keyPath: "position.x")
        pass.fromValue = -sweepWidth / 2
        pass.toValue = size.width * 1.05 + sweepWidth / 2
        pass.duration = Self.sweepPeriod
        sweep.add(Self.looping(pass), forKey: Self.sweepKey)
    }

    private static func looping(_ animation: CAAnimation) -> CAAnimation {
        animation.repeatCount = .infinity
        animation.isRemovedOnCompletion = false
        animation.preferredFrameRateRange = CAFrameRateRange(minimum: 15, maximum: 30, preferred: 30)
        return animation
    }

    /// O líquido até o nível, com a borda da direita em onda. A onda sobe conforme a fase anda.
    private static func edgePath(level: CGFloat, phase: Double, amplitude: CGFloat, in rect: CGRect) -> CGPath {
        let surface = max(rect.width * level, 2)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: surface, y: rect.maxY))
        let steps = 12
        for step in 0...steps {
            // Contado de cima para baixo, como no desenho original; o Core Animation conta de baixo.
            let fromTop = CGFloat(step) / CGFloat(steps)
            let wave = sin(Double(fromTop) * .pi * 2 + phase)
            path.addLine(to: CGPoint(x: min(surface + amplitude * CGFloat(wave), rect.maxX), y: rect.maxY - rect.height * fromTop))
        }
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
