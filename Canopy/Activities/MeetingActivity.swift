import AppKit
import CanopyCore
import SwiftUI

/// Reunião começando: aparece cinco minutos antes, com a contagem e o botão de entrar.
@MainActor
final class MeetingActivity: IslandActivity {
    static let activityID = "meeting"

    let id = MeetingActivity.activityID
    let priority = ActivityPriority.normal
    let tabSymbol = "calendar"
    private let event: CalendarMonitor.Event

    init(event: CalendarMonitor.Event) {
        self.event = event
    }

    var accent: Color? { event.color }

    var compactLeading: AnyView {
        AnyView(
            Image(systemName: event.meetingURL == nil ? "calendar" : "video.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(event.color)
                .shadow(color: event.color.opacity(0.6), radius: 4)
        )
    }

    var compactTrailing: AnyView {
        AnyView(
            StartsIn(start: event.start)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(event.color)
        )
    }

    var minimal: AnyView {
        AnyView(Circle().fill(event.color).frame(width: 8, height: 8))
    }

    var expanded: AnyView { AnyView(MeetingExpandedView(event: event)) }
}

private struct MeetingExpandedView: View {
    let event: CalendarMonitor.Event

    var body: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(event.color.gradient)
                .frame(width: 6)
                .shadow(color: event.color.opacity(0.7), radius: 6)
                .entrance(0)
            VStack(alignment: .leading, spacing: 4) {
                StartsIn(start: event.start, long: true)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(event.color)
                MarqueeText(text: event.title, size: 22, weight: .bold)
                Text(event.start.formatted(date: .omitted, time: .shortened) + " – " + event.end.formatted(date: .omitted, time: .shortened)
                     + (event.location.map { " · " + $0 } ?? ""))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            }
            .entrance(1)
            Spacer(minLength: 0)
            if let url = event.meetingURL {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Label("Entrar", systemImage: "video.fill")
                }
                .buttonStyle(CapsuleButtonStyle(tint: .green, isProminent: true))
                .entrance(2)
            }
        }
        .foregroundStyle(.white)
        .frame(maxHeight: .infinity)
    }
}

/// "em 4 min", "agora" ou "começou há 1 min".
struct StartsIn: View {
    let start: Date
    var long = false

    var body: some View {
        // Os minutos viram junto com o início da reunião, então é só nesses instantes que o texto muda.
        TimelineView(AlignedSchedule(anchor: start, interval: 60)) { context in
            Text(label(at: context.date))
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: true))
        }
    }

    private func label(at date: Date) -> String {
        let minutes = Int((start.timeIntervalSince(date) / 60).rounded(.up))
        if minutes > 0 { return long ? "Começa em \(minutes) min" : "em \(minutes) min" }
        let ago = -minutes
        if ago == 0 { return long ? "Começando agora" : "agora" }
        return long ? "Começou há \(ago) min" : "há \(ago) min"
    }
}
