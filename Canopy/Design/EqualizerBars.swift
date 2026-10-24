import AppKit
import SwiftUI

/// Barrinhas na cor da capa que pulam enquanto a música toca.
/// Quem anima é o Core Animation, fora do app: o SwiftUI não redesenha nada a cada quadro.
struct EqualizerBars: NSViewRepresentable {
    var isPlaying: Bool
    var tint: Color
    var bars = 4
    var barWidth: CGFloat = 3
    var maxHeight: CGFloat = 16

    private var style: EqualizerView.Style {
        EqualizerView.Style(bars: bars, barWidth: barWidth, maxHeight: maxHeight)
    }

    func makeNSView(context: Context) -> EqualizerView {
        EqualizerView()
    }

    func updateNSView(_ view: EqualizerView, context: Context) {
        view.update(style: style, tint: NSColor(tint), isPlaying: isPlaying)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: EqualizerView, context: Context) -> CGSize? {
        CGSize(width: style.width, height: maxHeight)
    }
}

final class EqualizerView: NSView {
    struct Style: Equatable {
        var bars: Int
        var barWidth: CGFloat
        var maxHeight: CGFloat

        var spacing: CGFloat { barWidth * 0.8 }
        var width: CGFloat { CGFloat(bars) * barWidth + CGFloat(max(bars - 1, 0)) * spacing }
    }

    private var style = Style(bars: 0, barWidth: 0, maxHeight: 0)
    private var tint = NSColor.white
    private var isPlaying = false
    private let container = CALayer()
    private var barLayers: [CALayer] = []

    private static let bounceKey = "bounce"
    private static let settleKey = "settle"

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        // O brilho na cor da capa em volta das barras.
        container.shadowOffset = .zero
        container.shadowRadius = 4
        container.shadowOpacity = 0.6
        layer?.addSublayer(container)
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(style: Style, tint: NSColor, isPlaying: Bool) {
        let styleChanged = style != self.style
        let tintChanged = !tint.matches(self.tint)
        let playingChanged = isPlaying != self.isPlaying
        self.style = style
        self.tint = tint
        self.isPlaying = isPlaying
        if styleChanged { rebuildBars() }
        if styleChanged || tintChanged { applyTint() }
        if styleChanged || playingChanged { applyMotion() }
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        centerContainer()
    }

    private func centerContainer() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        container.frame = CGRect(
            x: (bounds.width - style.width) / 2,
            y: (bounds.height - style.maxHeight) / 2,
            width: style.width,
            height: style.maxHeight
        )
        CATransaction.commit()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Fora da janela o Core Animation pode largar as animações; ao voltar, começam de novo.
        if window != nil { applyMotion() }
    }

    private func rebuildBars() {
        barLayers.forEach { $0.removeFromSuperlayer() }
        barLayers = (0..<style.bars).map { index in
            let bar = CALayer()
            bar.cornerRadius = style.barWidth / 2
            bar.bounds = CGRect(x: 0, y: 0, width: style.barWidth, height: style.barWidth)
            bar.position = CGPoint(
                x: CGFloat(index) * (style.barWidth + style.spacing) + style.barWidth / 2,
                y: style.maxHeight / 2
            )
            container.addSublayer(bar)
            return bar
        }
        centerContainer()
    }

    private func applyTint() {
        let color = tint.cgColor
        container.shadowColor = color
        barLayers.forEach { $0.backgroundColor = color }
    }

    private func applyMotion() {
        let animates = isPlaying && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        for (index, bar) in barLayers.enumerated() {
            // Parte da altura em que a barra está agora, para não dar um salto.
            let current = bar.presentation()?.bounds.height ?? bar.bounds.height
            bar.removeAnimation(forKey: Self.bounceKey)
            bar.removeAnimation(forKey: Self.settleKey)
            let resting = isPlaying ? Self.restingHeight(index: index, style: style) : style.barWidth
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            bar.bounds.size.height = resting
            CATransaction.commit()
            if animates {
                bar.add(Self.bounce(index: index, style: style), forKey: Self.bounceKey)
            } else if abs(current - resting) > 0.5 {
                let settle = CABasicAnimation(keyPath: "bounds.size.height")
                settle.fromValue = current
                settle.toValue = resting
                settle.duration = 0.3
                settle.timingFunction = CAMediaTimingFunction(name: .easeOut)
                bar.add(settle, forKey: Self.settleKey)
            }
        }
    }

    /// Com o movimento reduzido nos Ajustes, as barras ficam paradas em alturas variadas.
    private static func restingHeight(index: Int, style: Style) -> CGFloat {
        let levels: [CGFloat] = [0.55, 0.9, 0.4, 0.75, 0.6, 0.85]
        return style.barWidth + (style.maxHeight - style.barWidth) * levels[index % levels.count]
    }

    /// A mesma onda que as barras tinham no SwiftUI, amostrada 12 vezes por segundo e repetida.
    /// Cada barra tem o seu laço, de tamanhos diferentes, para o conjunto quase nunca se repetir.
    private static func bounce(index: Int, style: Style) -> CAKeyframeAnimation {
        let floor = Double(style.barWidth)
        let peak = Double(style.maxHeight)
        let speed = 5 + Double((index * 37) % 40) / 10
        let rate = 12.0
        let duration = 3.2 + Double(index % 3) * 0.7
        let steps = Int(duration * rate)
        let values = (0...steps).map { step -> Double in
            let time = Double(step % steps) / rate
            let wave = abs(sin(time * speed + Double(index))) * 0.65 + abs(sin(time * speed * 0.37)) * 0.35
            return floor + (peak - floor) * wave
        }
        let animation = CAKeyframeAnimation(keyPath: "bounds.size.height")
        animation.values = values
        animation.duration = Double(steps) / rate
        animation.calculationMode = .cubic
        animation.repeatCount = .infinity
        animation.isRemovedOnCompletion = false
        // Barrinhas pulando não precisam de 120 quadros por segundo.
        animation.preferredFrameRateRange = CAFrameRateRange(minimum: 15, maximum: 30, preferred: 30)
        return animation
    }
}

extension NSColor {
    /// Mesma cor na tela. Duas conversões da mesma Color do SwiftUI nem sempre dão objetos iguais.
    func matches(_ other: NSColor) -> Bool {
        guard let lhs = usingColorSpace(.sRGB), let rhs = other.usingColorSpace(.sRGB) else { return self == other }
        return abs(lhs.redComponent - rhs.redComponent) < 0.002
            && abs(lhs.greenComponent - rhs.greenComponent) < 0.002
            && abs(lhs.blueComponent - rhs.blueComponent) < 0.002
            && abs(lhs.alphaComponent - rhs.alphaComponent) < 0.002
    }
}
