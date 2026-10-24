/// Qual modelo de AirPods (ou Beats) acabou de conectar, para desenhar o ícone certo.
public enum AirPodsModel: Sendable, Equatable {
    case airPods, airPods3, airPods4, airPodsPro, airPodsMax, beatsEarbuds, beatsHeadphones

    /// Pelo ID de produto que o Bluetooth informa. A lista é a dos modelos conhecidos;
    /// um ID novo devolve nil e o modelo sai do nome.
    public init?(productID: Int) {
        switch productID {
        case 0x2002, 0x200F: self = .airPods
        case 0x2013: self = .airPods3
        case 0x2019, 0x201B: self = .airPods4
        case 0x200E, 0x2014, 0x2024, 0x2027: self = .airPodsPro
        case 0x200A, 0x201F: self = .airPodsMax
        case 0x2003, 0x2005, 0x200B, 0x200D, 0x2010, 0x2011, 0x2012, 0x2016: self = .beatsEarbuds
        case 0x2006, 0x2009, 0x200C, 0x2017: self = .beatsHeadphones
        default: return nil
        }
    }

    /// Pelo nome do aparelho. Renomeado ("Fones do Pedro"), cai nos AirPods comuns.
    public init(name: String) {
        let name = name.lowercased()
        if name.contains("max") {
            self = .airPodsMax
        } else if name.contains("pro") && !name.contains("beats") && !name.contains("powerbeats") {
            self = .airPodsPro
        } else if name.contains("solo") || name.contains("studio pro") || name.contains("studio3") {
            self = .beatsHeadphones
        } else if name.contains("beats") {
            self = .beatsEarbuds
        } else if name.contains("4") {
            self = .airPods4
        } else if name.contains("3") {
            self = .airPods3
        } else {
            self = .airPods
        }
    }

    /// Se o nome parece de AirPods ou Beats, para quando o Bluetooth não diz o fabricante.
    public static func looksLikeAirPods(name: String) -> Bool {
        let name = name.lowercased()
        return name.contains("airpods") || name.contains("beats")
    }

    public var displayName: String {
        switch self {
        case .airPods: "AirPods"
        case .airPods3: "AirPods (3ª geração)"
        case .airPods4: "AirPods 4"
        case .airPodsPro: "AirPods Pro"
        case .airPodsMax: "AirPods Max"
        case .beatsEarbuds, .beatsHeadphones: "Beats"
        }
    }

    /// Fone de cabeça: uma bateria só e nenhum estojo.
    public var isHeadphones: Bool {
        self == .airPodsMax || self == .beatsHeadphones
    }

    // Os SF Symbols mudaram de nome entre versões do macOS; cada lista vai do mais novo
    // ao mais antigo e termina num que sempre existe. Quem desenha usa o primeiro que houver.

    public var pairSymbols: [String] {
        switch self {
        case .airPods: ["airpods", "headphones"]
        case .airPods3: ["airpods.gen3", "airpods", "headphones"]
        case .airPods4: ["airpods.gen4", "airpods.gen3", "airpods", "headphones"]
        case .airPodsPro: ["airpods.pro", "airpodspro", "headphones"]
        case .airPodsMax: ["airpods.max", "airpodsmax", "headphones"]
        case .beatsEarbuds: ["beats.earphones", "beats.powerbeatspro", "earbuds", "headphones"]
        case .beatsHeadphones: ["beats.headphones", "headphones"]
        }
    }

    public var caseSymbols: [String] {
        switch self {
        case .airPods:
            ["airpods.chargingcase.fill", "airpods.chargingcase", "case.fill"]
        case .airPods3:
            ["airpods.gen3.chargingcase.wireless.fill", "airpods.chargingcase.wireless.fill", "airpods.chargingcase.fill", "case.fill"]
        case .airPods4:
            ["airpods.gen4.chargingcase.wireless.fill", "airpods.gen3.chargingcase.wireless.fill", "airpods.chargingcase.wireless.fill", "case.fill"]
        case .airPodsPro:
            ["airpods.pro.chargingcase.wireless.fill", "airpodspro.chargingcase.wireless.fill", "airpods.chargingcase.wireless.fill", "case.fill"]
        case .beatsEarbuds:
            ["beats.powerbeatspro.chargingcase.fill", "beats.earphones.chargingcase.fill", "case.fill"]
        case .airPodsMax, .beatsHeadphones:
            ["case.fill"]
        }
    }

    public func budSymbols(left: Bool) -> [String] {
        let side = left ? "left" : "right"
        switch self {
        case .airPods: return ["airpod.\(side)", "airpods"]
        case .airPods3: return ["airpod.gen3.\(side)", "airpod.\(side)", "airpods"]
        case .airPods4: return ["airpod.gen4.\(side)", "airpod.gen3.\(side)", "airpod.\(side)", "airpods"]
        case .airPodsPro: return ["airpod.pro.\(side)", "airpodpro.\(side)", "airpodspro"]
        case .beatsEarbuds: return ["beats.powerbeatspro.\(side)", "earbud.\(side)", "earbuds"]
        case .airPodsMax, .beatsHeadphones: return pairSymbols
        }
    }
}

/// Os níveis de bateria que os AirPods informam. nil quando ainda não chegou ou não existe,
/// como o estojo fechado longe dos fones.
public struct AirPodsBattery: Sendable, Equatable {
    public var left: Int?
    public var right: Int?
    public var chargingCase: Int?
    /// Fones de cabeça, como os AirPods Max, têm uma bateria só.
    public var single: Int?

    public init(left: Int? = nil, right: Int? = nil, chargingCase: Int? = nil, single: Int? = nil) {
        self.left = left.flatMap(Self.valid)
        self.right = right.flatMap(Self.valid)
        self.chargingCase = chargingCase.flatMap(Self.valid)
        self.single = single.flatMap(Self.valid)
    }

    /// O Bluetooth usa 0 para "não sei" e nunca passa de 100.
    private static func valid(_ percent: Int) -> Int? {
        (1...100).contains(percent) ? percent : nil
    }

    public var isEmpty: Bool {
        left == nil && right == nil && chargingCase == nil && single == nil
    }

    /// Já chegou tudo o que vale esperar: os fones e, se houver, o estojo.
    public var isComplete: Bool {
        single != nil || (left != nil && right != nil && chargingCase != nil)
    }

    /// O que a ilha mostra, como no iPhone: os dois fones juntos quando estão quase iguais,
    /// separados quando não, e o estojo por último.
    public var gauges: [AirPodsGauge] {
        var gauges: [AirPodsGauge] = []
        if let single {
            gauges.append(AirPodsGauge(part: .headphones, percent: single))
        } else if let left, let right {
            if abs(left - right) <= Self.togetherTolerance {
                gauges.append(AirPodsGauge(part: .buds, percent: min(left, right)))
            } else {
                gauges.append(AirPodsGauge(part: .left, percent: left))
                gauges.append(AirPodsGauge(part: .right, percent: right))
            }
        } else if let left {
            gauges.append(AirPodsGauge(part: .left, percent: left))
        } else if let right {
            gauges.append(AirPodsGauge(part: .right, percent: right))
        }
        if let chargingCase {
            gauges.append(AirPodsGauge(part: .chargingCase, percent: chargingCase))
        }
        return gauges
    }

    /// Diferença, em pontos, até a qual os dois fones aparecem como um só.
    public static let togetherTolerance = 5

    /// A carga dos fones, a que importa ao lado do notch: o mais fraco dos dois.
    public var budsPercent: Int? {
        if let single { return single }
        switch (left, right) {
        case let (left?, right?): return min(left, right)
        case let (left?, nil): return left
        case let (nil, right?): return right
        case (nil, nil): return chargingCase
        }
    }
}

public struct AirPodsGauge: Sendable, Equatable, Identifiable {
    public enum Part: Sendable, Equatable {
        case buds, left, right, chargingCase, headphones

        public var label: String {
            switch self {
            case .buds: "Fones"
            case .left: "Esquerdo"
            case .right: "Direito"
            case .chargingCase: "Estojo"
            case .headphones: "Fone"
            }
        }
    }

    public var part: Part
    public var percent: Int

    public var id: String { part.label }

    /// Abaixo disso o anel fica vermelho, como no iPhone.
    public static let lowThreshold = 20
    public var isLow: Bool { percent <= Self.lowThreshold }
}
