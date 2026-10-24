import Foundation
import Testing
@testable import CanopyCore

struct MeetingLinkTests {
    @Test func findsTheCallLinkInNotes() {
        let notes = "Pauta no doc https://docs.google.com/x\nEntrar: https://meet.google.com/abc-defg-hij"
        #expect(MeetingLink.find(in: [nil, "Sala 3", notes])?.host == "meet.google.com")
    }

    @Test func acceptsSubdomains() {
        #expect(MeetingLink.find(in: ["https://us02web.zoom.us/j/123456"])?.host == "us02web.zoom.us")
    }

    @Test func ignoresOtherLinks() {
        #expect(MeetingLink.find(in: ["https://example.com/zoom.us", "sem link"]) == nil)
    }
}
