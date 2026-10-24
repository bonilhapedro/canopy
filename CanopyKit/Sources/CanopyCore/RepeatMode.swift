/// Modo de repetição do player. O Spotify só tem ligado e desligado pelo AppleScript.
public enum RepeatMode: String, Sendable, Equatable {
    case off, all, one

    /// O próximo modo ao tocar no botão.
    public func next(supportsOne: Bool) -> RepeatMode {
        switch self {
        case .off: .all
        case .all: supportsOne ? .one : .off
        case .one: .off
        }
    }

    public var symbol: String {
        self == .one ? "repeat.1" : "repeat"
    }
}
