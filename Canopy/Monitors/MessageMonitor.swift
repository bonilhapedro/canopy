import AppKit
import CanopyCore
import CoreServices
import Observation
import SQLite3

/// Mensagens novas do WhatsApp e do Slack, lidas do banco da Central de Notificações.
///
/// O macOS não deixa um app receber as notificações de outro. Mas tudo o que chega à Central
/// fica num banco SQLite do usernoted, que apps com Acesso Total ao Disco podem ler. O Canopy
/// só olha esse banco quando o macOS avisa (FSEvents) que ele foi gravado: parado, não gasta nada.
///
/// Com o estilo de alerta do app em "Nenhum" nos Ajustes do Sistema, o macOS não mostra o banner
/// mas continua guardando a notificação, e ela aparece só na ilha.
@MainActor
@Observable
final class MessageMonitor {
    enum Access: Equatable {
        /// Desligado ou ainda não tentou.
        case unknown
        case granted
        /// O banco existe, mas o macOS não deixou abrir.
        case needsFullDiskAccess
        /// Não achou o banco ou ele mudou de formato nesta versão do macOS.
        case unsupported
    }

    private(set) var access = Access.unknown
    /// A mensagem mais nova e quantas chegaram juntas com ela.
    @ObservationIgnored var onMessage: ((AppNotification, Int) -> Void)?

    @ObservationIgnored private var apps: Set<MessagingApp> = []
    @ObservationIgnored private var isEnabled = false
    @ObservationIgnored private var reader: NotificationDatabaseReader?
    @ObservationIgnored private var icons: [String: NSImage] = [:]

    /// Mensagens mais velhas que isso, como as que chegam todas juntas quando o Mac acorda, não aparecem.
    private static let maxAge: TimeInterval = 120

    func configure(enabled: Bool, apps: Set<MessagingApp>) {
        self.apps = apps
        isEnabled = enabled && !apps.isEmpty
        if isEnabled {
            start()
        } else {
            stop()
        }
    }

    /// Tenta de novo, depois de liberar o Acesso Total ao Disco nos Ajustes do Sistema.
    func retry() {
        guard reader == nil, isEnabled else { return }
        start()
    }

    private func start() {
        guard reader == nil else { return }
        let result = NotificationDatabaseReader.open { [weak self] notes in
            Task { @MainActor in self?.received(notes) }
        }
        switch result {
        case .success(let reader):
            self.reader = reader
            setAccess(.granted)
        case .failure(let failure):
            setAccess(failure.access)
        }
    }

    private func stop() {
        reader?.close()
        reader = nil
        setAccess(.unknown)
    }

    private func setAccess(_ access: Access) {
        if self.access != access { self.access = access }
    }

    private func received(_ notes: [AppNotification]) {
        let fresh = notes.filter { apps.contains($0.app) && Date.now.timeIntervalSince($0.date) < Self.maxAge }
        guard let latest = fresh.last else { return }
        onMessage?(latest, fresh.count)
    }

    // MARK: - Apps

    /// O ícone do app que mandou, guardado depois da primeira vez.
    func icon(for bundleID: String) -> NSImage? {
        if let icon = icons[bundleID] { return icon }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icons[bundleID] = icon
        return icon
    }

    func open(_ note: AppNotification) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: note.bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    /// O identificador do app instalado, que pode ser o WhatsApp novo ou o antigo.
    static func installedBundleID(of app: MessagingApp) -> String? {
        app.bundleIDs.first { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) != nil }
    }

    static func openFullDiskAccessSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")
    }

    /// Os ajustes de notificação do próprio app, onde se escolhe o estilo de alerta "Nenhum".
    static func openNotificationSettings(for app: MessagingApp) {
        let id = installedBundleID(of: app) ?? app.bundleIDs[0]
        open("x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(id)")
    }

    private static func open(_ string: String) {
        guard let url = URL(string: string) else { return }
        NSWorkspace.shared.open(url)
    }
}

#if BENCHMARK
extension MessageMonitor {
    /// Uma mensagem de mentira, para medir a ilha sem WhatsApp instalado.
    static func simulatedMessage() -> AppNotification {
        AppNotification(
            id: "benchmark",
            app: .whatsApp,
            bundleID: "net.whatsapp.WhatsApp",
            title: "Ana",
            subtitle: "Família",
            body: "Já saí de casa, chego em 15 minutos. Quer que eu leve alguma coisa?",
            date: .now
        )
    }
}
#endif

// MARK: - Banco da Central de Notificações

/// Lê o banco do usernoted numa fila própria, fora da thread principal. Tudo o que mexe
/// na conexão e no stream de FSEvents acontece nessa fila.
private final class NotificationDatabaseReader: @unchecked Sendable {
    struct Failure: Error {
        let access: MessageMonitor.Access
    }

    private let queue = DispatchQueue(label: "Canopy.MessageMonitor", qos: .utility)
    private let path: String
    private let handler: @Sendable ([AppNotification]) -> Void
    private var db: OpaquePointer?
    private var statement: OpaquePointer?
    private var stream: FSEventStreamRef?
    /// A data de entrega mais nova já vista, no relógio do macOS (segundos desde 2001).
    private var cutoff = Date.now.timeIntervalSinceReferenceDate
    /// Os registros já vistos, para não repetir os que têm a mesma data do corte.
    private var seen: [String] = []
    /// Tamanho e data dos arquivos do banco na última leitura: um aviso do FSEvents sem
    /// gravação de verdade (a própria leitura mexe no arquivo -shm) não vira consulta.
    private var lastStamp: [Int64] = []

    /// Onde o macOS 15 e os seguintes guardam o banco, e onde as versões anteriores guardavam.
    private static var candidates: [String] {
        var paths = [NSHomeDirectory() + "/Library/Group Containers/group.com.apple.usernoted/db2/db"]
        let length = confstr(_CS_DARWIN_USER_DIR, nil, 0)
        if length > 0 {
            var buffer = [CChar](repeating: 0, count: length)
            confstr(_CS_DARWIN_USER_DIR, &buffer, length)
            paths.append(String(cString: buffer) + "com.apple.notificationcenter/db2/db")
        }
        return paths
    }

    /// Só o WhatsApp e o Slack saem do banco; as notificações dos outros apps nem são lidas.
    private static let query: String = {
        let ids = MessagingApp.allCases.flatMap(\.bundleIDs).map { "'\($0.lowercased())'" }.joined(separator: ",")
        return """
        SELECT r.rec_id, r.uuid, a.identifier, r.data, r.delivered_date
        FROM record r JOIN app a ON a.app_id = r.app_id
        WHERE r.delivered_date >= ?1 AND lower(a.identifier) IN (\(ids))
        ORDER BY r.delivered_date
        """
    }()

    static func open(handler: @escaping @Sendable ([AppNotification]) -> Void) -> Result<NotificationDatabaseReader, Failure> {
        var denied = false
        for path in candidates {
            // Sem Acesso Total ao Disco, o open devolve EPERM; sem o arquivo, ENOENT.
            let fd = Darwin.open(path, O_RDONLY)
            if fd < 0 {
                if errno == EPERM || errno == EACCES { denied = true }
                continue
            }
            Darwin.close(fd)
            let reader = NotificationDatabaseReader(path: path, handler: handler)
            guard reader.connect() else {
                reader.close()
                return .failure(Failure(access: .unsupported))
            }
            reader.watch()
            return .success(reader)
        }
        return .failure(Failure(access: denied ? .needsFullDiskAccess : .unsupported))
    }

    private init(path: String, handler: @escaping @Sendable ([AppNotification]) -> Void) {
        self.path = path
        self.handler = handler
    }

    /// Abre só para leitura e prepara a consulta. Falha se as tabelas não forem as esperadas.
    private func connect() -> Bool {
        queue.sync {
            guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK else { return false }
            sqlite3_busy_timeout(db, 250)
            // Cache pequeno: as consultas pegam poucas linhas.
            sqlite3_exec(db, "PRAGMA cache_size = -256", nil, nil, nil)
            guard sqlite3_prepare_v3(db, Self.query, -1, UInt32(SQLITE_PREPARE_PERSISTENT), &statement, nil) == SQLITE_OK else { return false }
            lastStamp = stamp()
            return true
        }
    }

    private func watch() {
        queue.sync {
            let directory = (path as NSString).deletingLastPathComponent
            var context = FSEventStreamContext(
                version: 0,
                info: Unmanaged.passUnretained(self).toOpaque(),
                retain: nil,
                release: nil,
                copyDescription: nil
            )
            let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
                guard let info else { return }
                Unmanaged<NotificationDatabaseReader>.fromOpaque(info).takeUnretainedValue().changed()
            }
            // Sem adiar o primeiro aviso, a mensagem aparece na hora; os seguintes se juntam por 0,3 s.
            guard let stream = FSEventStreamCreate(
                nil,
                callback,
                &context,
                [directory] as CFArray,
                FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
                0.3,
                FSEventStreamCreateFlags(kFSEventStreamCreateFlagNoDefer)
            ) else { return }
            FSEventStreamSetDispatchQueue(stream, queue)
            FSEventStreamStart(stream)
            self.stream = stream
        }
    }

    func close() {
        queue.sync {
            if let stream {
                FSEventStreamStop(stream)
                FSEventStreamInvalidate(stream)
                FSEventStreamRelease(stream)
                self.stream = nil
            }
            sqlite3_finalize(statement)
            statement = nil
            sqlite3_close_v2(db)
            db = nil
        }
    }

    /// Chamado na fila pelo FSEvents.
    private func changed() {
        let stamp = stamp()
        guard stamp != lastStamp else { return }
        lastStamp = stamp
        let notes = readNew()
        if !notes.isEmpty { handler(notes) }
    }

    private func stamp() -> [Int64] {
        [path, path + "-wal"].flatMap { file -> [Int64] in
            var info = stat()
            guard stat(file, &info) == 0 else { return [0, 0] }
            return [Int64(info.st_size), Int64(info.st_mtimespec.tv_sec) * 1_000_000_000 + Int64(info.st_mtimespec.tv_nsec)]
        }
    }

    private func readNew() -> [AppNotification] {
        guard let statement else { return [] }
        defer { sqlite3_reset(statement) }
        sqlite3_bind_double(statement, 1, cutoff)
        var notes: [AppNotification] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = Self.identifier(statement)
            let delivered = sqlite3_column_double(statement, 4)
            guard !seen.contains(id) else { continue }
            seen.append(id)
            cutoff = max(cutoff, delivered)
            guard let bundleID = sqlite3_column_text(statement, 2).map({ String(cString: $0) }),
                  let bytes = sqlite3_column_blob(statement, 3)
            else { continue }
            let data = Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, 3)))
            if let note = AppNotification(id: id, bundleID: bundleID, data: data, deliveredAt: Date(timeIntervalSinceReferenceDate: delivered)) {
                notes.append(note)
            }
        }
        if seen.count > 64 { seen.removeFirst(seen.count - 64) }
        return notes
    }

    /// O uuid do registro, que não se repete; o rec_id pode voltar depois que uma notificação é apagada.
    private static func identifier(_ statement: OpaquePointer) -> String {
        if let bytes = sqlite3_column_blob(statement, 1) {
            let count = Int(sqlite3_column_bytes(statement, 1))
            let buffer = UnsafeRawBufferPointer(start: bytes, count: count)
            return buffer.map { String(format: "%02x", $0) }.joined()
        }
        return "rec-\(sqlite3_column_int64(statement, 0))"
    }
}
