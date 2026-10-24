import CoreGraphics
import Foundation

/// Um arquivo guardado na bandeja da ilha.
public struct ShelfItem: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    /// Onde o arquivo estava da última vez. O bookmark acha o arquivo se ele mudar de lugar.
    public var path: String
    public var bookmark: Data?
    /// A cópia mora na pasta do Canopy e é apagada quando sai da bandeja.
    public var isOwned: Bool
    public var addedAt: Date

    public init(id: UUID = UUID(), name: String, path: String, bookmark: Data? = nil, isOwned: Bool = false, addedAt: Date = .now) {
        self.id = id
        self.name = name
        self.path = path
        self.bookmark = bookmark
        self.isOwned = isOwned
        self.addedAt = addedAt
    }
}

/// Os arquivos da bandeja, do mais novo para o mais antigo.
public struct Shelf: Codable, Equatable, Sendable {
    /// Mais que isso e os mais antigos saem.
    public static let capacity = 24

    public private(set) var items: [ShelfItem]

    public init(items: [ShelfItem] = []) {
        self.items = items
    }

    public var isEmpty: Bool { items.isEmpty }

    /// Os novos entram na frente. Um arquivo que já estava na bandeja sobe para a frente, sem repetir.
    /// - Returns: os itens que sobraram: repetidos que não entraram e os mais antigos além da capacidade.
    ///   Quem chamou apaga as cópias deles.
    @discardableResult
    public mutating func add(_ new: [ShelfItem]) -> [ShelfItem] {
        var discarded: [ShelfItem] = []
        var front: [ShelfItem] = []
        for item in new {
            if front.contains(where: { $0.path == item.path }) {
                discarded.append(item)
            } else if let index = items.firstIndex(where: { $0.path == item.path }) {
                front.append(items.remove(at: index))
                discarded.append(item)
            } else {
                front.append(item)
            }
        }
        items = front + items
        if items.count > Self.capacity {
            discarded += items[Self.capacity...]
            items.removeSubrange(Self.capacity...)
        }
        return discarded
    }

    @discardableResult
    public mutating func remove(ids: Set<UUID>) -> [ShelfItem] {
        let removed = items.filter { ids.contains($0.id) }
        items.removeAll { ids.contains($0.id) }
        return removed
    }

    @discardableResult
    public mutating func removeAll() -> [ShelfItem] {
        defer { items = [] }
        return items
    }

    /// Troca os dados de um item que já está na bandeja, como o caminho novo de um arquivo que mudou de lugar.
    public mutating func update(_ item: ShelfItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }), items[index] != item else { return }
        items[index] = item
    }
}

/// As duas áreas da ilha aberta enquanto um arquivo é arrastado até ela.
public enum ShelfDropZone: Sendable, Equatable {
    /// Guardar na bandeja.
    case tray
    /// Mandar direto por AirDrop.
    case airDrop
}

public enum ShelfDropLayout {
    /// Quanto da largura da ilha aberta, à direita, é a área do AirDrop.
    public static let airDropFraction: CGFloat = 0.32

    /// Qual área está sob o mouse.
    /// - Parameters:
    ///   - x: posição horizontal dentro da ilha, a partir da borda esquerda.
    ///   - width: largura da ilha.
    public static func zone(atX x: CGFloat, width: CGFloat) -> ShelfDropZone {
        x >= width * (1 - airDropFraction) ? .airDrop : .tray
    }
}
