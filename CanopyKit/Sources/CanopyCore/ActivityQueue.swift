import Foundation

public struct ActivityPriority: RawRepresentable, Comparable, Hashable, Sendable {
    public var rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Informação de fundo, como clima ou o próximo evento.
    public static let background = ActivityPriority(rawValue: 0)
    /// Algo em andamento, como música ou um timer.
    public static let normal = ActivityPriority(rawValue: 50)
    /// Aviso rápido que passa na frente, como o HUD de volume.
    public static let alert = ActivityPriority(rawValue: 100)

    public static func < (lhs: ActivityPriority, rhs: ActivityPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct ActivityEntry: Identifiable, Hashable, Sendable {
    public var id: String
    public var priority: ActivityPriority
    public var startedAt: Date

    public init(id: String, priority: ActivityPriority, startedAt: Date) {
        self.id = id
        self.priority = priority
        self.startedAt = startedAt
    }
}

/// Decide qual atividade ocupa o notch: maior prioridade primeiro, e entre iguais a mais recente.
public struct ActivityQueue: Sendable, Equatable {
    public private(set) var entries: [ActivityEntry] = []

    public init() {}

    public var isEmpty: Bool { entries.isEmpty }

    public var ordered: [ActivityEntry] {
        entries.sorted { ($0.priority, $0.startedAt) > ($1.priority, $1.startedAt) }
    }

    public var primary: ActivityEntry? { ordered.first }

    public func contains(id: String) -> Bool {
        entries.contains { $0.id == id }
    }

    public mutating func upsert(_ entry: ActivityEntry) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
        } else {
            entries.append(entry)
        }
    }

    public mutating func remove(id: String) {
        entries.removeAll { $0.id == id }
    }
}
