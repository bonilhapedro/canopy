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

    /// O primeiro link de chamada encontrado, na ordem dos textos.
    public static func find(in texts: [String?]) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        for text in texts.compactMap({ $0 }) where !text.isEmpty {
            let range = NSRange(text.startIndex..., in: text)
            for match in detector.matches(in: text, range: range) {
                guard let url = match.url, isMeeting(url) else { continue }
                return url
            }
        }
        return nil
    }

    public static func isMeeting(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return hosts.contains { host == $0 || host.hasSuffix("." + $0) }
    }
}
