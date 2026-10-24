/// Que tipo de saída de áudio acabou de ser escolhida, para mostrar o ícone certo.
public enum AudioOutputKind: Sendable, Equatable {
    case airPodsMax, airPodsPro, airPods, beats, headphones, builtInSpeakers, display, airPlay, speaker

    /// Como o CoreAudio diz que o aparelho está ligado ao Mac.
    public enum Transport: Sendable {
        case builtIn, bluetooth, hdmiOrDisplayPort, airPlay, usb, other
    }

    public init(name: String, transport: Transport) {
        let name = name.lowercased()
        if name.contains("airpods max") {
            self = .airPodsMax
        } else if name.contains("airpods pro") {
            self = .airPodsPro
        } else if name.contains("airpods") {
            self = .airPods
        } else if name.contains("beats") || name.contains("powerbeats") {
            self = .beats
        } else {
            switch transport {
            case .builtIn:
                // Fone no conector de 3,5 mm também aparece como embutido.
                self = name.contains("headphone") || name.contains("fone") ? .headphones : .builtInSpeakers
            case .bluetooth:
                self = name.contains("speaker") || name.contains("caixa") ? .speaker : .headphones
            case .hdmiOrDisplayPort:
                self = .display
            case .airPlay:
                self = .airPlay
            case .usb, .other:
                self = name.contains("headphone") || name.contains("headset") ? .headphones : .speaker
            }
        }
    }

    /// AirPods ou Beats, que o aviso de AirPods já mostra ao conectar.
    public var isAppleHeadphones: Bool {
        switch self {
        case .airPodsMax, .airPodsPro, .airPods, .beats: true
        default: false
        }
    }

    public var symbol: String {
        switch self {
        case .airPodsMax: "airpodsmax"
        case .airPodsPro: "airpodspro"
        case .airPods: "airpods"
        case .beats: "beats.headphones"
        case .headphones: "headphones"
        case .builtInSpeakers: "laptopcomputer"
        case .display: "tv"
        case .airPlay: "airplayaudio"
        case .speaker: "hifispeaker.fill"
        }
    }

    /// Nome curto para caber ao lado do notch.
    public var shortName: String {
        switch self {
        case .airPodsMax: "AirPods Max"
        case .airPodsPro: "AirPods Pro"
        case .airPods: "AirPods"
        case .beats: "Beats"
        case .headphones: "Fones"
        case .builtInSpeakers: "Mac"
        case .display: "Monitor"
        case .airPlay: "AirPlay"
        case .speaker: "Caixa"
        }
    }
}
