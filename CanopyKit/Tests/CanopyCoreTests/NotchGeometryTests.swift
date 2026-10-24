import CoreGraphics
import Foundation
import Testing
@testable import CanopyCore

struct NotchGeometryTests {
    // Medidas de um MacBook Air de 13" em resolução padrão.
    private let screen = CGRect(x: 0, y: 0, width: 1470, height: 956)

    @Test func notchSitsBetweenTheTwoMenuBarAreas() {
        let geometry = NotchGeometry(
            screenFrame: screen,
            auxiliaryTopLeftArea: CGRect(x: 0, y: 924, width: 650, height: 32),
            auxiliaryTopRightArea: CGRect(x: 835, y: 924, width: 635, height: 32),
            safeAreaTop: 32,
            menuBarHeight: 24
        )
        #expect(geometry.hasNotch)
        #expect(geometry.rect == CGRect(x: 650, y: 924, width: 185, height: 32))
    }

    @Test func screensWithoutNotchGetACenteredPill() {
        let geometry = NotchGeometry(
            screenFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            auxiliaryTopLeftArea: nil,
            auxiliaryTopRightArea: nil,
            safeAreaTop: 0,
            menuBarHeight: 24
        )
        #expect(!geometry.hasNotch)
        #expect(geometry.rect.midX == 960)
        #expect(geometry.rect.maxY == 1080)
        #expect(geometry.rect.height == 24)
    }

    @Test func layoutGrowsFromClosedToExpanded() {
        let layout = IslandLayout(notch: CGSize(width: 185, height: 32))
        #expect(layout.size(for: .closed) == CGSize(width: 185, height: 32))
        #expect(layout.size(for: .compact).width == 185 + 2 * IslandLayout.compactWing)
        #expect(layout.size(for: .expanded).width == IslandLayout.expandedMinWidth)
        #expect(layout.size(for: .expanded).height > layout.size(for: .compact).height)
    }

    @Test func panelIsCenteredOnTheNotchAndTouchesTheTop() {
        let layout = IslandLayout(notch: CGSize(width: 185, height: 32))
        let notch = CGRect(x: 650, y: 924, width: 185, height: 32)
        let frame = layout.panelFrame(notchRect: notch)
        #expect(frame.midX == notch.midX)
        #expect(frame.maxY == notch.maxY)
    }

    @Test func pillIsSmallerWhenClosedOnScreensWithoutNotch() {
        let layout = IslandLayout(notch: CGSize(width: 180, height: 24), hasNotch: false)
        let closed = layout.size(for: .closed)
        #expect(closed.width < 180)
        #expect(closed.height < 24)
        #expect(layout.size(for: .compact).height == 24)
    }
}
