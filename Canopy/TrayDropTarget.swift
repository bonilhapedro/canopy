import AppKit
import CanopyCore

/// Recebe arquivos arrastados até o notch: a ilha abre na bandeja, e onde o arquivo é solto
/// decide entre guardar e mandar por AirDrop.
@MainActor
final class TrayDropTarget {
    static let types: [NSPasteboard.PasteboardType] =
        [.fileURL] + NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) }

    private let coordinator: IslandCoordinator
    private let tray: FileTray
    private var isInside = false

    init(coordinator: IslandCoordinator, tray: FileTray) {
        self.coordinator = coordinator
        self.tray = tray
    }

    /// Chamado quando o arraste entra na janela e a cada movimento dentro dela.
    func update(_ info: NSDraggingInfo, in view: NSView) -> NSDragOperation {
        // Um item da própria bandeja passando de volta pelo notch não entra de novo.
        guard Preferences.trayEnabled, info.draggingSource == nil, carriesFiles(info) else {
            leave()
            return []
        }
        let point = topLeft(info.draggingLocation, in: view)
        let island = coordinator.layout.islandRect(for: coordinator.phase, panelSize: view.bounds.size)
        // A janela é maior que a ilha; só vale perto dela. A folga ajuda a acertar o notch fechado.
        guard island.insetBy(dx: -16, dy: -16).contains(point) else {
            leave()
            return []
        }
        if !isInside {
            isInside = true
            coordinator.dropEntered()
        }
        let zone = coordinator.phase == .expanded
            ? ShelfDropLayout.zone(atX: point.x - island.minX, width: island.width)
            : .tray
        if zone != coordinator.dropZone, coordinator.dropZone != nil, Preferences.haptics {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
        coordinator.dropMoved(to: zone)
        return .copy
    }

    func perform(_ info: NSDraggingInfo) -> Bool {
        guard isInside else { return false }
        isInside = false
        let zone = coordinator.dropZone ?? .tray
        let pasteboard = info.draggingPasteboard
        let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        // Arquivos de verdade têm preferência; promessas são para apps como o Fotos e o Mail.
        let promises = urls.isEmpty
            ? pasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self]) as? [NSFilePromiseReceiver] ?? []
            : []
        switch zone {
        case .tray:
            tray.add(urls)
            tray.receive(promises)
        case .airDrop:
            if urls.isEmpty {
                tray.receive(promises, thenAirDrop: true)
            } else {
                tray.airDrop(urls)
            }
        }
        coordinator.dropExited(dropped: true)
        return !urls.isEmpty || !promises.isEmpty
    }

    /// O arraste saiu da janela ou terminou em outro lugar.
    func leave() {
        guard isInside else { return }
        isInside = false
        coordinator.dropExited(dropped: false)
    }

    private func carriesFiles(_ info: NSDraggingInfo) -> Bool {
        info.draggingPasteboard.canReadObject(
            forClasses: [NSURL.self, NSFilePromiseReceiver.self],
            options: [.urlReadingFileURLsOnly: true]
        )
    }

    private func topLeft(_ windowPoint: NSPoint, in view: NSView) -> CGPoint {
        let local = view.convert(windowPoint, from: nil)
        return CGPoint(x: local.x, y: view.isFlipped ? local.y : view.bounds.height - local.y)
    }
}
