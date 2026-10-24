import AppKit
import SwiftUI

/// Arrastar arquivos para fora da ilha. Feito no AppKit para o arquivo sair como arquivo de verdade
/// (Finder, Mail, navegador) e para saber quando o arraste termina.
struct TrayDragSource: NSViewRepresentable {
    let urls: [URL]
    let image: NSImage?
    var onOpen: (() -> Void)?
    var menu: (() -> NSMenu)?
    let onDragged: () -> Void

    func makeNSView(context: Context) -> DragSourceView {
        DragSourceView()
    }

    func updateNSView(_ view: DragSourceView, context: Context) {
        view.urls = urls
        view.image = image
        view.onOpen = onOpen
        view.makeMenu = menu
        view.onDragged = onDragged
    }
}

final class DragSourceView: NSView, NSDraggingSource {
    var urls: [URL] = []
    var image: NSImage?
    var onOpen: (() -> Void)?
    var makeMenu: (() -> NSMenu)?
    var onDragged: (() -> Void)?

    private var mouseDownLocation: NSPoint?

    /// A origem do arraste em andamento. O AppKit não promete segurá-la, e a ilha pode fechar
    /// no meio do caminho, levando a view junto.
    private static var active: DragSourceView?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        mouseDownLocation = event.locationInWindow
        if event.clickCount == 2 { onOpen?() }
    }

    override func mouseUp(with event: NSEvent) {
        mouseDownLocation = nil
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = mouseDownLocation, !urls.isEmpty else { return }
        let location = event.locationInWindow
        // Um tremido no clique não vira arraste.
        guard hypot(location.x - start.x, location.y - start.y) > 4 else { return }
        mouseDownLocation = nil

        let size = CGSize(width: 56, height: 56)
        let center = convert(location, from: nil)
        let items = urls.enumerated().map { index, url in
            let item = NSDraggingItem(pasteboardWriter: url as NSURL)
            let offset = CGFloat(min(index, 4)) * 4
            let frame = NSRect(
                x: center.x - size.width / 2 + offset,
                y: center.y - size.height / 2 - offset,
                width: size.width,
                height: size.height
            )
            let contents = index == 0 ? image : nil
            item.setDraggingFrame(frame, contents: contents ?? NSWorkspace.shared.icon(forFile: url.path(percentEncoded: false)))
            return item
        }
        let session = beginDraggingSession(with: items, event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
        session.draggingFormation = .stack
        Self.active = self
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        makeMenu?()
    }

    nonisolated func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        // Só cópia: soltar no Finder nunca move o original para outro lugar.
        context == .outsideApplication ? .copy : []
    }

    nonisolated func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        MainActor.assumeIsolated {
            if operation != [] { onDragged?() }
            Self.active = nil
        }
    }
}

/// Item de menu que roda um bloco, para montar menus de contexto sem target e selector à parte.
final class ActionMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(_ title: String, symbol: String? = nil, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        target = self
        if let symbol {
            image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        }
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func run() {
        handler()
    }
}
