import AppKit

/// Escolhe, entre nomes de SF Symbols, o primeiro que existe neste macOS.
/// Os símbolos de AirPods mudaram de nome entre versões; um nome que não existe desenha nada.
@MainActor
enum SymbolName {
    private static var cache: [[String]: String] = [:]

    static func first(of candidates: [String]) -> String {
        if let known = cache[candidates] { return known }
        let found = candidates.first { NSImage(systemSymbolName: $0, accessibilityDescription: nil) != nil }
            ?? candidates.last ?? "questionmark"
        cache[candidates] = found
        return found
    }
}
