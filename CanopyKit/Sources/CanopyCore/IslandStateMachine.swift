/// Os três tamanhos que a ilha pode ter, como no Dynamic Island do iPhone.
public enum IslandPhase: Sendable, Equatable {
    /// Só o notch físico: nada para mostrar.
    case closed
    /// Uma atividade em andamento aparece dos dois lados do notch.
    case compact
    /// Painel aberto pelo mouse ou por um clique.
    case expanded

    /// Ordem de tamanho: fechado < compacto < expandido.
    public var order: Int {
        switch self {
        case .closed: 0
        case .compact: 1
        case .expanded: 2
        }
    }
}

public enum IslandEvent: Sendable, Equatable {
    case pointerEntered
    case pointerExited
    case clicked
    case dismissed
    case activitiesChanged(hasActivity: Bool)
}

/// Regras de transição entre os estados da ilha, sem depender de AppKit.
public struct IslandStateMachine: Sendable, Equatable {
    public private(set) var phase: IslandPhase = .closed
    public private(set) var hasActivity = false
    /// Aberto por clique: continua aberto quando o mouse sai.
    public private(set) var isPinned = false
    /// Se a última troca de estado aumentou a ilha. Crescer pode quicar; encolher não,
    /// porque o quique passaria do tamanho final e a ilha sumiria por um instante.
    public private(set) var lastChangeGrew = false

    public init() {}

    private var restingPhase: IslandPhase {
        hasActivity ? .compact : .closed
    }

    public mutating func handle(_ event: IslandEvent) {
        let previous = phase
        defer {
            if phase != previous { lastChangeGrew = phase.order > previous.order }
        }
        switch event {
        case .pointerEntered:
            phase = .expanded
        case .pointerExited:
            if !isPinned { phase = restingPhase }
        case .clicked:
            isPinned = true
            phase = .expanded
        case .dismissed:
            isPinned = false
            phase = restingPhase
        case .activitiesChanged(let hasActivity):
            self.hasActivity = hasActivity
            if phase != .expanded { phase = restingPhase }
        }
    }
}
