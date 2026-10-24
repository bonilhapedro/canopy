public struct BatterySnapshot: Sendable, Equatable {
    public var percent: Int
    public var isCharging: Bool
    public var isPluggedIn: Bool

    public init(percent: Int, isCharging: Bool, isPluggedIn: Bool) {
        self.percent = percent
        self.isCharging = isCharging
        self.isPluggedIn = isPluggedIn
    }
}

public enum BatteryEvent: Sendable, Equatable {
    case pluggedIn
    case unplugged
    case low

    /// Nível em que a bateria fraca é avisada, em porcento.
    public static let lowThreshold = 10

    /// O que vale avisar na passagem de uma leitura para a seguinte.
    public static func between(_ old: BatterySnapshot?, _ new: BatterySnapshot) -> BatteryEvent? {
        guard let old else { return nil }
        if !old.isPluggedIn && new.isPluggedIn { return .pluggedIn }
        if old.isPluggedIn && !new.isPluggedIn { return .unplugged }
        if !new.isPluggedIn && old.percent > lowThreshold && new.percent <= lowThreshold { return .low }
        return nil
    }
}
