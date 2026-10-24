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
    /// Uma atividade abre a ilha sozinha por um instante, como os AirPods conectando no iPhone.
    case presentationStarted
    case presentationEnded
}

/// Regras de transição entre os estados da ilha, sem depender de AppKit.
public struct IslandStateMachine: Sendable, Equatable {
    public private(set) var phase: IslandPhase = .closed
    public private(set) var hasActivity = false
    /// Aberto por clique: continua aberto quando o mouse sai.
    public private(set) var isPinned = false
    /// Aberta sozinha por uma atividade: não fecha quando o mouse sai, só quando ela termina.
    public private(set) var isPresenting = false
    /// O mouse está sobre a ilha. Ao fim de uma apresentação, a ilha fica aberta se ele estiver.
    public private(set) var isPointerInside = false
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
            isPointerInside = true
            phase = .expanded
        case .pointerExited:
            isPointerInside = false
            if !isPinned && !isPresenting { phase = restingPhase }
        case .clicked:
            isPinned = true
            phase = .expanded
        case .dismissed:
            isPinned = false
            isPresenting = false
            phase = restingPhase
        case .activitiesChanged(let hasActivity):
            self.hasActivity = hasActivity
            if phase != .expanded { phase = restingPhase }
        case .presentationStarted:
            isPresenting = true
            phase = .expanded
        case .presentationEnded:
            guard isPresenting else { return }
            isPresenting = false
            if !isPinned && !isPointerInside { phase = restingPhase }
        }
    }
}
