/// Os três tamanhos que a ilha pode ter, como no Dynamic Island do iPhone.
public enum IslandPhase: Sendable, Equatable {
    /// Só o notch físico: nada para mostrar.
    case closed
    /// Uma atividade em andamento aparece dos dois lados do notch.
    case compact
    /// Painel aberto pelo mouse ou por um clique.
    case expanded
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

    public init() {}

    private var restingPhase: IslandPhase {
        hasActivity ? .compact : .closed
    }

    public mutating func handle(_ event: IslandEvent) {
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
