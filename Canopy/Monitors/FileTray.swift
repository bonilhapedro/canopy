import AppKit
import CanopyCore
import Observation
import QuickLookThumbnailing

/// A bandeja de arquivos: o que é arrastado até o notch fica aqui até sair para outro app ou pelo AirDrop.
/// Só a lista fica em disco. Nada roda enquanto ninguém mexe na bandeja: conferir se os arquivos
/// ainda existem e gerar miniaturas acontece quando a página dela abre.
@MainActor
@Observable
final class FileTray {
    private(set) var shelf = Shelf()
    /// Miniaturas prontas, por item.
    private(set) var thumbnails: [UUID: NSImage] = [:]
    /// Arquivos que ainda estão sendo copiados ou recebidos de outro app.
    private(set) var pending = 0

    @ObservationIgnored private var persists = true
    @ObservationIgnored private var loadingThumbnails: Set<UUID> = []

    var items: [ShelfItem] { shelf.items }

    /// Application Support/Canopy, onde ficam a lista e as cópias.
    nonisolated private static let directory = URL.applicationSupportDirectory.appending(path: "Canopy", directoryHint: .isDirectory)
    nonisolated private static let indexURL = directory.appending(path: "tray.json")
    /// Cada cópia fica numa pasta só dela, para dois arquivos de mesmo nome não brigarem.
    nonisolated private static let filesDirectory = directory.appending(path: "Tray", directoryHint: .isDirectory)
    nonisolated static let thumbnailSize = CGSize(width: 56, height: 56)

    func start() {
        if let data = try? Data(contentsOf: Self.indexURL),
           let saved = try? JSONDecoder().decode(Shelf.self, from: data) {
            shelf = saved
        }
        validate()
        removeOrphanCopies()
    }

    nonisolated func url(for item: ShelfItem) -> URL {
        URL(fileURLWithPath: item.path)
    }

    // MARK: - Entrar

    /// Arquivos soltos no notch. Sem a cópia ligada nos Ajustes, guarda só o caminho e um bookmark.
    func add(_ urls: [URL]) {
        let files = urls.filter(\.isFileURL)
        guard !files.isEmpty else { return }
        guard Preferences.trayCopiesFiles else {
            insert(files.map { url in
                ShelfItem(name: url.lastPathComponent, path: url.path(percentEncoded: false), bookmark: try? url.bookmarkData())
            })
            return
        }
        pending += files.count
        Task {
            for url in files {
                // Copiar um arquivo grande pode demorar; fica fora da thread principal.
                let copy = await Task.detached(priority: .userInitiated) { Self.copyIntoTray(url) }.value
                pending = max(pending - 1, 0)
                if let copy { insert([Self.ownedItem(at: copy)]) }
            }
        }
    }

    /// Arquivos prometidos por outro app, como fotos do Fotos ou anexos do Mail:
    /// eles só existem depois que o app os grava numa pasta do Canopy.
    func receive(_ receivers: [NSFilePromiseReceiver], thenAirDrop airDrop: Bool = false) {
        guard !receivers.isEmpty else { return }
        let counts = receivers.map { max($0.fileNames.count, 1) }
        let batch = PromiseBatch(remaining: counts.reduce(0, +), airDrop: airDrop)
        pending += batch.remaining
        for (receiver, count) in zip(receivers, counts) {
            guard let staging = Self.makeSlot() else {
                for _ in 0..<count { received(nil, in: batch) }
                continue
            }
            let queue = OperationQueue()
            queue.qualityOfService = .userInitiated
            // O bloco roda na fila acima, fora da thread principal: precisa ser @Sendable,
            // senão o Swift o prende ao MainActor e o app cai ao chamá-lo de outra thread.
            receiver.receivePromisedFiles(atDestination: staging, options: [:], operationQueue: queue) { @Sendable url, error in
                // Cada arquivo vai para a sua pasta, para sair da bandeja sem levar os outros junto.
                let moved = error == nil ? Self.moveIntoOwnSlot(url, from: staging) : nil
                Task { @MainActor [weak self] in self?.received(moved, in: batch) }
            }
        }
    }

    private func received(_ url: URL?, in batch: PromiseBatch) {
        pending = max(pending - 1, 0)
        batch.remaining -= 1
        if let url {
            insert([Self.ownedItem(at: url)])
            batch.urls.append(url)
        }
        if batch.remaining <= 0, batch.airDrop, !batch.urls.isEmpty {
            batch.airDrop = false
            airDrop(batch.urls)
        }
    }

    private func insert(_ new: [ShelfItem]) {
        let discarded = shelf.add(new)
        forget(discarded)
        save()
    }

    // MARK: - Sair

    func remove(_ id: UUID) {
        forget(shelf.remove(ids: [id]))
        save()
    }

    func removeAll() {
        forget(shelf.removeAll())
        save()
    }

    /// O item foi solto em outro app. Quem recebeu pode ler o arquivo só depois, como um
    /// navegador enviando um anexo, então uma cópia nossa ainda fica um tempo no disco.
    func draggedOut(_ ids: [UUID]) {
        guard Preferences.trayRemovesAfterDrag else { return }
        forget(shelf.remove(ids: Set(ids)), after: .seconds(600))
        save()
    }

    func open(_ item: ShelfItem) {
        NSWorkspace.shared.open(url(for: item))
    }

    func reveal(_ items: [ShelfItem]) {
        NSWorkspace.shared.activateFileViewerSelecting(items.map { url(for: $0) })
    }

    func airDrop(_ urls: [URL]) {
        guard !urls.isEmpty,
              let service = NSSharingService(named: .sendViaAirDrop),
              service.canPerform(withItems: urls)
        else {
            NSSound.beep()
            return
        }
        // A janela do AirDrop só aparece na frente com o app ativo.
        NSApp.activate()
        service.perform(withItems: urls)
    }

    /// Tira as miniaturas da memória e apaga as cópias que eram só da bandeja.
    private func forget(_ items: [ShelfItem], after delay: Duration? = nil) {
        for item in items where thumbnails[item.id] != nil {
            thumbnails[item.id] = nil
        }
        let slots = items.filter(\.isOwned).compactMap { Self.slot(of: $0.path) }
        guard !slots.isEmpty else { return }
        Task.detached(priority: .utility) {
            if let delay { try? await Task.sleep(for: delay) }
            for slot in slots {
                try? FileManager.default.removeItem(at: slot)
            }
        }
    }

    // MARK: - Conferir

    /// Tira da bandeja o que foi apagado e acompanha o que mudou de lugar.
    /// Roda ao abrir a página da bandeja, nunca de tempos em tempos.
    func validate() {
        let before = shelf
        var missing: Set<UUID> = []
        for var item in shelf.items where !FileManager.default.fileExists(atPath: item.path) {
            var isStale = false
            guard let bookmark = item.bookmark,
                  let url = try? URL(resolvingBookmarkData: bookmark, options: [.withoutUI, .withoutMounting], bookmarkDataIsStale: &isStale),
                  FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
            else {
                missing.insert(item.id)
                continue
            }
            item.path = url.path(percentEncoded: false)
            item.name = url.lastPathComponent
            if isStale { item.bookmark = try? url.bookmarkData() }
            shelf.update(item)
        }
        if !missing.isEmpty { forget(shelf.remove(ids: missing)) }
        if shelf != before { save() }
    }

    // MARK: - Miniaturas

    func loadThumbnail(for item: ShelfItem, scale: CGFloat) async {
        guard thumbnails[item.id] == nil, !loadingThumbnails.contains(item.id) else { return }
        loadingThumbnails.insert(item.id)
        defer { loadingThumbnails.remove(item.id) }
        let url = url(for: item)
        let thumbnail = await Self.thumbnail(of: url, scale: scale)
        // O item pode ter saído enquanto a miniatura era feita.
        guard shelf.items.contains(where: { $0.id == item.id }) else { return }
        thumbnails[item.id] = thumbnail.map { NSImage(cgImage: $0.image, size: Self.thumbnailSize) }
            ?? NSWorkspace.shared.icon(forFile: url.path(percentEncoded: false))
    }

    /// A miniatura do Quick Look: a primeira página de um PDF, a foto, o ícone do app.
    nonisolated private static func thumbnail(of url: URL, scale: CGFloat) async -> Thumbnail? {
        let request = QLThumbnailGenerator.Request(fileAt: url, size: thumbnailSize, scale: scale, representationTypes: .all)
        return await withCheckedContinuation { continuation in
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, _ in
                continuation.resume(returning: representation.map { Thumbnail(image: $0.cgImage) })
            }
        }
    }

    // MARK: - Disco

    private func save() {
        guard persists else { return }
        do {
            try FileManager.default.createDirectory(at: Self.directory, withIntermediateDirectories: true)
            try JSONEncoder().encode(shelf).write(to: Self.indexURL, options: .atomic)
        } catch {
            NSLog("Canopy: não deu para salvar a bandeja: \(error)")
        }
    }

    /// Apaga cópias que ficaram para trás, como as que esperavam para sair quando o app fechou.
    private func removeOrphanCopies() {
        let kept = Set(shelf.items.filter(\.isOwned).compactMap { Self.slot(of: $0.path)?.lastPathComponent })
        Task.detached(priority: .background) {
            let slots = (try? FileManager.default.contentsOfDirectory(at: Self.filesDirectory, includingPropertiesForKeys: nil)) ?? []
            for slot in slots where !kept.contains(slot.lastPathComponent) {
                try? FileManager.default.removeItem(at: slot)
            }
        }
    }

    nonisolated private static func ownedItem(at url: URL) -> ShelfItem {
        ShelfItem(name: url.lastPathComponent, path: url.path(percentEncoded: false), isOwned: true)
    }

    /// Uma pasta nova dentro de Application Support/Canopy/Tray.
    nonisolated private static func makeSlot() -> URL? {
        let slot = filesDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        do {
            try FileManager.default.createDirectory(at: slot, withIntermediateDirectories: true)
            return slot
        } catch {
            return nil
        }
    }

    /// A pasta da cópia, só se ela estiver mesmo dentro da pasta da bandeja.
    /// Assim um caminho estranho na lista nunca leva a apagar outra coisa.
    nonisolated private static func slot(of path: String) -> URL? {
        let slot = URL(fileURLWithPath: path).deletingLastPathComponent().standardizedFileURL
        guard slot.deletingLastPathComponent().path(percentEncoded: false) == filesDirectory.standardizedFileURL.path(percentEncoded: false) else {
            return nil
        }
        return slot
    }

    nonisolated private static func copyIntoTray(_ url: URL) -> URL? {
        guard let slot = makeSlot() else { return nil }
        let destination = slot.appending(path: url.lastPathComponent)
        do {
            try FileManager.default.copyItem(at: url, to: destination)
            return destination
        } catch {
            try? FileManager.default.removeItem(at: slot)
            return nil
        }
    }

    nonisolated private static func moveIntoOwnSlot(_ url: URL, from staging: URL) -> URL? {
        guard let slot = makeSlot() else { return nil }
        let destination = slot.appending(path: url.lastPathComponent)
        do {
            try FileManager.default.moveItem(at: url, to: destination)
        } catch {
            try? FileManager.default.removeItem(at: slot)
            return nil
        }
        // A pasta de chegada fica vazia quando o último arquivo sai dela.
        if (try? FileManager.default.contentsOfDirectory(atPath: staging.path(percentEncoded: false)))?.isEmpty == true {
            try? FileManager.default.removeItem(at: staging)
        }
        return destination
    }
}

/// Os arquivos prometidos numa mesma soltura, para o AirDrop mandar todos de uma vez.
@MainActor
private final class PromiseBatch {
    var remaining: Int
    var airDrop: Bool
    var urls: [URL] = []

    init(remaining: Int, airDrop: Bool) {
        self.remaining = remaining
        self.airDrop = airDrop
    }
}

/// O CGImage não muda depois de criado, então passar de uma thread para outra é seguro.
private struct Thumbnail: @unchecked Sendable {
    let image: CGImage
}

#if BENCHMARK
extension FileTray {
    /// Alguns arquivos do sistema na bandeja, sem gravar nada na lista do usuário.
    func simulateItems() {
        persists = false
        shelf = Shelf()
        shelf.add(["/System/Applications/Calculator.app", "/System/Applications/Notes.app", "/etc/hosts"].map {
            ShelfItem(name: ($0 as NSString).lastPathComponent, path: $0)
        })
    }
}
#endif
