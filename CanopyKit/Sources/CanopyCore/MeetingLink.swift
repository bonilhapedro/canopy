import Foundation

/// Acha o link de uma videochamada nos campos de um evento da agenda.
public enum MeetingLink {
    private static let hosts = [
        "zoom.us",
        "meet.google.com",
        "teams.microsoft.com",
        "teams.live.com",
        "facetime.apple.com",
        "webex.com",
        "whereby.com",
        "meet.jit.si",
    ]

    /// Criado uma vez só: montar o detector custa bem mais do que usá-lo, e ele é só de leitura.
    nonisolated(unsafe) private static let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

    /// O primeiro link de chamada encontrado, na ordem dos textos.
    public static func find(in texts: [String?]) -> URL? {
        guard let detector else { return nil }
        // Notas que não citam nenhum dos serviços nem passam pelo detector.
        for text in texts.compactMap({ $0 }) where mentionsService(text) {
            let range = NSRange(text.startIndex..., in: text)
            for match in detector.matches(in: text, range: range) {
                guard let url = match.url, isMeeting(url) else { continue }
                return url
            }
        }
        return nil
    }

    private static func mentionsService(_ text: String) -> Bool {
        let lowered = text.lowercased()
        return hosts.contains { lowered.contains($0) }
    }

    public static func isMeeting(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return hosts.contains { host == $0 || host.hasSuffix("." + $0) }
    }
}
