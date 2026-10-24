/// As telas da ilha aberta, na ordem das abas.
public enum IslandPage: String, CaseIterable, Sendable, Equatable {
    /// A atividade principal em andamento, como a música.
    case now
    /// Hora, data, agenda e bateria.
    case home
    /// Os arquivos guardados na bandeja.
    case tray
    case weather

    /// As páginas disponíveis agora, na ordem em que aparecem.
    public static func available(hasActivity: Bool, showsWeather: Bool, showsTray: Bool = false) -> [IslandPage] {
        allCases.filter { page in
            switch page {
            case .now: hasActivity
            case .tray: showsTray
            case .weather: showsWeather
            case .home: true
            }
        }
    }

    /// A página vizinha em `pages`, sem dar a volta no fim da lista.
    /// Se `self` não estiver na lista, devolve a primeira.
    public func neighbor(_ step: Int, in pages: [IslandPage]) -> IslandPage? {
        guard let index = pages.firstIndex(of: self) else { return pages.first }
        let target = index + step
        guard pages.indices.contains(target) else { return nil }
        return pages[target]
    }
}

/// Transforma o arrastar de dois dedos no trackpad em "próxima" ou "anterior",
/// uma vez por gesto.
public struct SwipeTracker: Sendable, Equatable {
    public enum Phase: Sendable {
        case began, changed, ended
    }

    /// Distância, em pontos, para o gesto valer.
    public static let threshold: Double = 36

    private var accumulated: Double = 0
    private var fired = false

    public init() {}

    /// - Parameter fingerDeltaX: quanto os dedos andaram na horizontal; positivo é para a direita.
    /// - Returns: +1 para a próxima página (dedos para a esquerda), -1 para a anterior, ou nil.
    public mutating func handle(fingerDeltaX: Double, phase: Phase) -> Int? {
        switch phase {
        case .began:
            accumulated = fingerDeltaX
            fired = false
        case .changed:
            accumulated += fingerDeltaX
        case .ended:
            accumulated = 0
            fired = false
            return nil
        }
        guard !fired, abs(accumulated) >= Self.threshold else { return nil }
        fired = true
        return accumulated < 0 ? 1 : -1
    }
}
