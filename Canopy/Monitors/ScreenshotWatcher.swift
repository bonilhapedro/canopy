import Foundation

/// Avisa quando o macOS grava uma captura de tela nova, pelo Spotlight (kMDItemIsScreenCapture),
/// esteja ela onde estiver. A consulta fica parada até o Spotlight indexar uma captura nova:
/// nada é conferido de tempos em tempos.
@MainActor
final class ScreenshotWatcher {
    var onCapture: (([URL]) -> Void)?

    private var query: NSMetadataQuery?
    private var observer: NSObjectProtocol?

    func setEnabled(_ enabled: Bool) {
        enabled ? start() : stop()
    }

    private func start() {
        guard query == nil else { return }
        let query = NSMetadataQuery()
        // Só capturas feitas daqui para frente: as antigas nem entram na memória.
        query.predicate = NSPredicate(format: "kMDItemIsScreenCapture == 1 && kMDItemFSCreationDate >= %@", Date.now as NSDate)
        query.searchScopes = [NSMetadataQueryUserHomeScope]
        observer = NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidUpdate,
            object: query,
            queue: .main
        ) { [weak self] note in
            // O userInfo não é Sendable: vira uma lista de caminhos antes de entrar no MainActor.
            let added = note.userInfo?[NSMetadataQueryUpdateAddedItemsKey] as? [NSMetadataItem] ?? []
            let paths = added.compactMap { $0.value(forAttribute: NSMetadataItemPathKey) as? String }
            MainActor.assumeIsolated { self?.captured(paths) }
        }
        query.start()
        self.query = query
    }

    private func stop() {
        query?.stop()
        query = nil
        if let observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
    }

    private func captured(_ paths: [String]) {
        let urls = paths
            .filter { FileManager.default.fileExists(atPath: $0) }
            .map { URL(fileURLWithPath: $0) }
        guard !urls.isEmpty else { return }
        onCapture?(urls)
    }
}
