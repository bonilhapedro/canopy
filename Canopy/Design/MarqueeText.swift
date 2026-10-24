import AppKit
import SwiftUI

/// Texto de uma linha que rola devagar quando não cabe, como no Apple Music.
/// A rolagem é uma animação do Core Animation: o app desenha o texto uma vez e não faz mais nada.
struct MarqueeText: View {
    let text: String
    var size: CGFloat
    var weight: NSFont.Weight = .regular
    var color: Color = .white

    var body: some View {
        MarqueeLabel(text: text, font: .rounded(size: size, weight: weight), color: color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement()
            .accessibilityLabel(text)
    }
}

extension NSFont {
    /// A fonte do sistema no desenho arredondado, a mesma do `.fontDesign(.rounded)` da ilha.
    static func rounded(size: CGFloat, weight: NSFont.Weight) -> NSFont {
        let font = NSFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = font.fontDescriptor.withDesign(.rounded) else { return font }
        return NSFont(descriptor: descriptor, size: size) ?? font
    }
}

private struct MarqueeLabel: NSViewRepresentable {
    let text: String
    let font: NSFont
    let color: Color

    func makeNSView(context: Context) -> MarqueeView {
        MarqueeView()
    }

    func updateNSView(_ view: MarqueeView, context: Context) {
        view.update(text: text, font: font, color: NSColor(color))
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: MarqueeView, context: Context) -> CGSize? {
        let height = MarqueeView.lineHeight(of: font)
        if let width = proposal.width, width.isFinite { return CGSize(width: width, height: height) }
        return CGSize(width: MarqueeView.width(of: text, font: font), height: height)
    }
}

final class MarqueeView: NSView {
    private var text = ""
    private var font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
    private var color = NSColor.white
    private var textWidth: CGFloat = 0
    /// Quanto a animação instalada anda; nil quando ela precisa ser refeita.
    private var installedDistance: CGFloat?

    private let content = CALayer()
    private let scroller = CALayer()
    private let leading = CATextLayer()
    /// A cópia que vem atrás, para a volta emendar sem salto.
    private let trailing = CATextLayer()
    private let fade = CAGradientLayer()

    private static let gap: CGFloat = 36
    /// Pontos por segundo.
    private static let speed: CGFloat = 28
    /// Parada no começo de cada volta, em segundos.
    private static let pause: CFTimeInterval = 2.2
    private static let scrollKey = "marquee"

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        content.masksToBounds = true
        content.anchorPoint = .zero
        scroller.anchorPoint = .zero
        for label in [leading, trailing] {
            label.anchorPoint = .zero
            label.isWrapped = false
            label.truncationMode = .none
            label.alignmentMode = .left
            scroller.addSublayer(label)
        }
        content.addSublayer(scroller)
        layer?.addSublayer(content)
        // Some aos poucos nas pontas, como no SwiftUI antes.
        fade.startPoint = CGPoint(x: 0, y: 0.5)
        fade.endPoint = CGPoint(x: 1, y: 0.5)
        fade.colors = [NSColor.clear.cgColor, NSColor.black.cgColor, NSColor.black.cgColor, NSColor.clear.cgColor]
        fade.locations = [0, 0.04, 0.9, 1]
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(text: String, font: NSFont, color: NSColor) {
        let textChanged = text != self.text || font != self.font
        guard textChanged || !color.matches(self.color) else { return }
        self.text = text
        self.font = font
        self.color = color
        let string = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color])
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        leading.string = string
        trailing.string = string
        CATransaction.commit()
        guard textChanged else { return }
        textWidth = ceil(string.size().width)
        // Texto novo recomeça parado no início, como numa troca de faixa.
        installedDistance = nil
        arrange()
    }

    static func lineHeight(of font: NSFont) -> CGFloat {
        ceil(font.ascender - font.descender + font.leading)
    }

    static func width(of text: String, font: NSFont) -> CGFloat {
        ceil(NSAttributedString(string: text, attributes: [.font: font]).size().width)
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        arrange()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateScale()
        // Fora da janela o Core Animation pode largar a animação; ao voltar, ela é refeita.
        installedDistance = nil
        arrange()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        updateScale()
    }

    private func updateScale() {
        let scale = window?.backingScaleFactor ?? 2
        leading.contentsScale = scale
        trailing.contentsScale = scale
    }

    private func arrange() {
        let lineHeight = Self.lineHeight(of: font)
        let overflows = textWidth > bounds.width + 1
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        content.frame = bounds
        scroller.frame = CGRect(
            x: 0,
            y: ((bounds.height - lineHeight) / 2).rounded(),
            width: overflows ? 2 * textWidth + Self.gap : textWidth,
            height: lineHeight
        )
        leading.frame = CGRect(x: 0, y: 0, width: textWidth, height: lineHeight)
        trailing.frame = CGRect(x: textWidth + Self.gap, y: 0, width: textWidth, height: lineHeight)
        trailing.isHidden = !overflows
        fade.frame = content.bounds
        content.mask = overflows ? fade : nil
        CATransaction.commit()
        scroll(overflows ? textWidth + Self.gap : 0)
    }

    /// Para no começo, anda até a cópia ocupar o lugar do texto e recomeça; o salto não aparece.
    private func scroll(_ distance: CGFloat) {
        let distance = window != nil && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? distance : 0
        guard distance != installedDistance else { return }
        installedDistance = distance
        scroller.removeAnimation(forKey: Self.scrollKey)
        guard distance > 0 else { return }
        let period = Self.pause + CFTimeInterval(distance / Self.speed)
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.values = [0, 0, -distance]
        animation.keyTimes = [0, NSNumber(value: Self.pause / period), 1]
        animation.duration = period
        animation.repeatCount = .infinity
        animation.isRemovedOnCompletion = false
        scroller.add(animation, forKey: Self.scrollKey)
    }
}
