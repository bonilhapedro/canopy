import CoreGraphics
import Foundation

/// Onde o notch fica na tela, calculado a partir das medidas do NSScreen.
public struct NotchGeometry: Sendable, Equatable {
    public var rect: CGRect
    public var hasNotch: Bool

    /// Largura da pílula desenhada em telas sem notch.
    public static let fallbackWidth: CGFloat = 180

    public init(rect: CGRect, hasNotch: Bool) {
        self.rect = rect
        self.hasNotch = hasNotch
    }

    /// - Parameters:
    ///   - screenFrame: `NSScreen.frame`.
    ///   - auxiliaryTopLeftArea: `NSScreen.auxiliaryTopLeftArea`, nil em telas sem notch.
    ///   - auxiliaryTopRightArea: `NSScreen.auxiliaryTopRightArea`, nil em telas sem notch.
    ///   - safeAreaTop: `NSScreen.safeAreaInsets.top`, a altura do notch.
    ///   - menuBarHeight: altura usada para a pílula quando não há notch.
    public init(
        screenFrame: CGRect,
        auxiliaryTopLeftArea: CGRect?,
        auxiliaryTopRightArea: CGRect?,
        safeAreaTop: CGFloat,
        menuBarHeight: CGFloat
    ) {
        // Só as larguras das áreas laterais são usadas, para não depender do sistema de coordenadas delas.
        if let left = auxiliaryTopLeftArea, let right = auxiliaryTopRightArea, safeAreaTop > 0 {
            let width = screenFrame.width - left.width - right.width
            if width > 0 {
                self.init(
                    rect: CGRect(
                        x: screenFrame.minX + left.width,
                        y: screenFrame.maxY - safeAreaTop,
                        width: width,
                        height: safeAreaTop
                    ),
                    hasNotch: true
                )
                return
            }
        }
        self.init(
            rect: CGRect(
                x: screenFrame.midX - Self.fallbackWidth / 2,
                y: screenFrame.maxY - menuBarHeight,
                width: Self.fallbackWidth,
                height: menuBarHeight
            ),
            hasNotch: false
        )
    }
}

/// Tamanho da ilha em cada estado, a partir do tamanho do notch.
public struct IslandLayout: Sendable, Equatable {
    public var notch: CGSize

    /// Quanto a ilha compacta cresce para cada lado do notch.
    public static let compactWing: CGFloat = 76
    public static let expandedMinWidth: CGFloat = 520
    public static let expandedContentHeight: CGFloat = 176
    /// Margem da janela em volta da ilha expandida, para a sombra não ser cortada.
    public static let shadowPadding: CGFloat = 24

    public init(notch: CGSize) {
        self.notch = notch
    }

    public func size(for phase: IslandPhase) -> CGSize {
        switch phase {
        case .closed:
            notch
        case .compact:
            CGSize(width: notch.width + 2 * Self.compactWing, height: notch.height)
        case .expanded:
            CGSize(
                width: max(notch.width + 2 * Self.compactWing, Self.expandedMinWidth),
                height: notch.height + Self.expandedContentHeight
            )
        }
    }

    /// A janela tem sempre o tamanho do estado expandido, colada no topo e centrada no notch.
    /// A ilha é desenhada dentro dela; o resto da janela é transparente e deixa os cliques passarem.
    public func panelFrame(notchRect: CGRect) -> CGRect {
        let expanded = size(for: .expanded)
        let width = expanded.width + 2 * Self.shadowPadding
        let height = expanded.height + Self.shadowPadding
        return CGRect(x: notchRect.midX - width / 2, y: notchRect.maxY - height, width: width, height: height)
    }
}
