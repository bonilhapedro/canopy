import Foundation
import Testing
@testable import CanopyCore

struct AppNotificationTests {
    private func plist(_ request: [String: Any]) throws -> Data {
        try PropertyListSerialization.data(fromPropertyList: ["app": "x", "req": request], format: .binary, options: 0)
    }

    @Test func recognizesTheMessagingApps() {
        #expect(MessagingApp(bundleID: "net.whatsapp.WhatsApp") == .whatsApp)
        #expect(MessagingApp(bundleID: "net.whatsapp.whatsapp") == .whatsApp)
        #expect(MessagingApp(bundleID: "desktop.WhatsApp") == .whatsApp)
        #expect(MessagingApp(bundleID: "com.tinyspeck.slackmacgap") == .slack)
        #expect(MessagingApp(bundleID: "com.apple.iCal") == nil)
    }

    @Test func readsTitleSubtitleAndBody() throws {
        let data = try plist(["titl": "Ana", "subt": "Família", "body": "Chego às 8"])
        let note = try #require(AppNotification(id: "1", bundleID: "net.whatsapp.WhatsApp", data: data, deliveredAt: .distantPast))
        #expect(note.app == .whatsApp)
        #expect(note.title == "Ana")
        #expect(note.subtitle == "Família")
        #expect(note.body == "Chego às 8")
    }

    @Test func fallsBackToTheAppNameWithoutTitle() throws {
        let data = try plist(["body": "  novo arquivo  ", "subt": ""])
        let note = try #require(AppNotification(id: "2", bundleID: "com.tinyspeck.slackmacgap", data: data, deliveredAt: .distantPast))
        #expect(note.title == "Slack")
        #expect(note.subtitle == nil)
        #expect(note.body == "novo arquivo")
    }

    @Test func ignoresOtherAppsAndEmptyNotifications() throws {
        let data = try plist(["titl": "Oi"])
        #expect(AppNotification(id: "3", bundleID: "com.apple.MobileSMS", data: data, deliveredAt: .distantPast) == nil)
        let empty = try plist(["iden": "abc"])
        #expect(AppNotification(id: "4", bundleID: "com.tinyspeck.slackmacgap", data: empty, deliveredAt: .distantPast) == nil)
        #expect(AppNotification(id: "5", bundleID: "com.tinyspeck.slackmacgap", data: Data("lixo".utf8), deliveredAt: .distantPast) == nil)
    }
}
