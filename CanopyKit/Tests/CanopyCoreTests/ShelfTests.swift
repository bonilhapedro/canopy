import CoreGraphics
import Foundation
import Testing
@testable import CanopyCore

struct ShelfTests {
    private func item(_ path: String) -> ShelfItem {
        ShelfItem(name: (path as NSString).lastPathComponent, path: path)
    }

    @Test func newFilesGoToTheFront() {
        var shelf = Shelf()
        shelf.add([item("/a")])
        shelf.add([item("/b"), item("/c")])
        #expect(shelf.items.map(\.path) == ["/b", "/c", "/a"])
    }

    @Test func aFileAlreadyOnTheShelfMovesUpInsteadOfRepeating() {
        var shelf = Shelf()
        let original = item("/a")
        shelf.add([original, item("/b")])
        let again = item("/a")
        let discarded = shelf.add([again])
        #expect(shelf.items.map(\.path) == ["/a", "/b"])
        #expect(shelf.items.first?.id == original.id)
        #expect(discarded.map(\.id) == [again.id])
    }

    @Test func repeatsInsideOneDropCountOnce() {
        var shelf = Shelf()
        let discarded = shelf.add([item("/a"), item("/a")])
        #expect(shelf.items.count == 1)
        #expect(discarded.count == 1)
    }

    @Test func oldestLeaveWhenFull() {
        var shelf = Shelf()
        // Um de cada vez, para o /0 ser o mais antigo.
        for index in 0..<Shelf.capacity {
            shelf.add([item("/\(index)")])
        }
        let discarded = shelf.add([item("/new")])
        #expect(shelf.items.count == Shelf.capacity)
        #expect(shelf.items.first?.path == "/new")
        #expect(discarded.map(\.path) == ["/0"])
    }

    @Test func removeReturnsWhatLeft() {
        var shelf = Shelf()
        let a = item("/a")
        shelf.add([a, item("/b")])
        #expect(shelf.remove(ids: [a.id]).map(\.path) == ["/a"])
        #expect(shelf.items.map(\.path) == ["/b"])
        #expect(shelf.removeAll().map(\.path) == ["/b"])
        #expect(shelf.isEmpty)
    }

    @Test func updateChangesOnlyThatItem() {
        var shelf = Shelf()
        var a = item("/a")
        shelf.add([a, item("/b")])
        a.path = "/moved/a"
        shelf.update(a)
        #expect(shelf.items.map(\.path) == ["/moved/a", "/b"])
    }

    @Test func survivesASaveAndLoad() throws {
        var shelf = Shelf()
        shelf.add([ShelfItem(name: "a", path: "/a", bookmark: Data([1, 2]), isOwned: true)])
        let data = try JSONEncoder().encode(shelf)
        #expect(try JSONDecoder().decode(Shelf.self, from: data) == shelf)
    }

    @Test func airDropIsTheRightSideOfTheIsland() {
        #expect(ShelfDropLayout.zone(atX: 10, width: 520) == .tray)
        #expect(ShelfDropLayout.zone(atX: 300, width: 520) == .tray)
        #expect(ShelfDropLayout.zone(atX: 400, width: 520) == .airDrop)
    }

    @Test func islandSitsAtTheTopCenterOfThePanel() {
        let layout = IslandLayout(notch: CGSize(width: 185, height: 32))
        let panel = layout.panelFrame(notchRect: CGRect(x: 650, y: 924, width: 185, height: 32)).size
        let closed = layout.islandRect(for: .closed, panelSize: panel)
        #expect(closed == CGRect(x: (panel.width - 185) / 2, y: 0, width: 185, height: 32))
        let expanded = layout.islandRect(for: .expanded, panelSize: panel)
        #expect(expanded.minX == IslandLayout.shadowPadding)
        #expect(expanded.height == 32 + IslandLayout.expandedContentHeight)
    }
}
