import Foundation

/// Os apps de mensagem que o Canopy mostra na ilha. Os outros apps continuam só no macOS.
public enum MessagingApp: String, CaseIterable, Sendable {
    case whatsApp, slack

    /// Todos os identificadores conhecidos de cada app: o WhatsApp nativo, o antigo feito
    /// em Electron e o Slack da App Store ou do site, que usam o mesmo.
    public var bundleIDs: [String] {
        switch self {
        case .whatsApp: ["net.whatsapp.WhatsApp", "desktop.WhatsApp", "WhatsApp"]
        case .slack: ["com.tinyspeck.slackmacgap"]
        }
    }

    /// A Central de Notificações já guardou identificadores em minúsculas; a comparação ignora isso.
    public init?(bundleID: String) {
        let id = bundleID.lowercased()
        guard let app = Self.allCases.first(where: { $0.bundleIDs.contains { $0.lowercased() == id } }) else { return nil }
        self = app
    }

    public var displayName: String {
        switch self {
        case .whatsApp: "WhatsApp"
        case .slack: "Slack"
        }
    }
}

/// Uma notificação de um app de mensagem, como o macOS guardou na Central de Notificações.
public struct AppNotification: Sendable, Equatable, Identifiable {
    /// O identificador do registro na Central de Notificações, único enquanto ela guardar a notificação.
    public let id: String
    public let app: MessagingApp
    public let bundleID: String
    /// Quem mandou, ou o nome do grupo ou canal.
    public var title: String
    public var subtitle: String?
    public var body: String
    public var date: Date

    public init(id: String, app: MessagingApp, bundleID: String, title: String, subtitle: String? = nil, body: String, date: Date) {
        self.id = id
        self.app = app
        self.bundleID = bundleID
        self.title = title
        self.subtitle = subtitle
        self.body = body
        self.date = date
    }

    /// Lê o plist binário da coluna `data` da tabela `record`. O texto fica em `req`:
    /// `titl` (título), `subt` (subtítulo) e `body` (mensagem).
    /// - Returns: nil se o app não for WhatsApp ou Slack ou se não houver texto nenhum.
    public init?(id: String, bundleID: String, data: Data, deliveredAt: Date) {
        guard let app = MessagingApp(bundleID: bundleID),
              let root = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let request = root["req"] as? [String: Any]
        else { return nil }
        let title = Self.text(request["titl"])
        let subtitle = Self.text(request["subt"])
        let body = Self.text(request["body"])
        guard title != nil || body != nil else { return nil }
        self.init(
            id: id,
            app: app,
            bundleID: bundleID,
            title: title ?? app.displayName,
            subtitle: subtitle,
            body: body ?? "",
            date: deliveredAt
        )
    }

    private static func text(_ value: Any?) -> String? {
        guard let string = value as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
