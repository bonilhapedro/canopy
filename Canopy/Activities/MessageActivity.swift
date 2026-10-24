import AppKit
import CanopyCore
import SwiftUI

/// Mensagem nova do WhatsApp ou do Slack, como uma notificação na Dynamic Island do iPhone:
/// fechada, o ícone do app e quem mandou; aberta, a mensagem e o botão para responder no app.
@MainActor
final class MessageActivity: IslandActivity {
    static let activityID = "message"

    let id = MessageActivity.activityID
    let priority = ActivityPriority.alert
    private let note: AppNotification
    private let count: Int
    private let icon: NSImage?
    private let showsBody: Bool
    private let onOpen: () -> Void

    /// - Parameter count: quantas mensagens chegaram seguidas, contando esta.
    init(note: AppNotification, count: Int, icon: NSImage?, showsBody: Bool, onOpen: @escaping () -> Void) {
        self.note = note
        self.count = count
        self.icon = icon
        self.showsBody = showsBody
        self.onOpen = onOpen
    }

    var accent: Color? { note.app.tint }
    var tabSymbol: String { note.app == .slack ? "number" : "message.fill" }

    var compactLeading: AnyView { AnyView(AppIcon(icon: icon, app: note.app, size: 18, bounces: true)) }
    var compactTrailing: AnyView {
        AnyView(
            HStack(spacing: 5) {
                Text(note.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                if count > 1 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .frame(minWidth: 16, minHeight: 16)
                        .background(Capsule().fill(note.app.tint))
                        .contentTransition(.numericText())
                }
            }
            .frame(maxWidth: 110, alignment: .trailing)
        )
    }
    var minimal: AnyView { AnyView(AppIcon(icon: icon, app: note.app, size: 13, bounces: false)) }

    var expanded: AnyView {
        AnyView(
            HStack(alignment: .center, spacing: 16) {
                AppIcon(icon: icon, app: note.app, size: 52, bounces: true)
                    .frame(width: 64)
                    .entrance(0)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(note.title)
                            .font(.system(size: 16, weight: .bold))
                            .lineLimit(1)
                        if count > 1 {
                            Text("+\(count - 1)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(note.app.tint)
                        }
                        Spacer(minLength: 8)
                        Text(note.date, format: .dateTime.hour().minute())
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    if let subtitle = note.subtitle {
                        Text(subtitle)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                    Text(showsBody ? note.body : "Nova mensagem")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(showsBody ? 0.9 : 0.55))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .entrance(1)
                Button("Abrir", action: onOpen)
                    .buttonStyle(CapsuleButtonStyle(tint: note.app.tint, isProminent: true))
                    .entrance(2)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        )
    }
}

extension MessagingApp {
    /// A cor de cada app, que tinge o brilho da ilha aberta.
    var tint: Color {
        switch self {
        case .whatsApp: Color(red: 0.15, green: 0.83, blue: 0.40)
        case .slack: Color(red: 0.88, green: 0.12, blue: 0.35)
        }
    }

    var fallbackSymbol: String {
        switch self {
        case .whatsApp: "message.fill"
        case .slack: "number.square.fill"
        }
    }
}

/// O ícone do app, que entra com um pulinho uma vez só.
private struct AppIcon: View {
    let icon: NSImage?
    let app: MessagingApp
    let size: CGFloat
    let bounces: Bool
    @State private var isShown = false

    var body: some View {
        Group {
            if let icon {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: app.fallbackSymbol)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(app.tint)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: app.tint.opacity(isShown && size > 30 ? 0.45 : 0), radius: size * 0.25)
        .scaleEffect(isShown || !bounces ? 1 : 0.5)
        .opacity(isShown || !bounces ? 1 : 0)
        .onAppear {
            guard bounces else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) { isShown = true }
        }
    }
}
