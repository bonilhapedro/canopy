import AppKit
import SwiftUI

/// A página inicial da ilha aberta: saudação, hora, data e os próximos eventos.
struct HomePage: View {
    @Environment(CalendarMonitor.self) private var calendar
    @AppStorage(SettingsKey.calendarEnabled) private var calendarEnabled = true

    var body: some View {
        TimelineView(.everyMinute) { context in
            HStack(alignment: .center, spacing: 22) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(greeting(for: context.date))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                    Text(context.date, format: .dateTime.hour().minute())
                        .font(.system(size: 50, weight: .semibold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .shadow(color: .white.opacity(0.25), radius: 12)
                    Text(context.date, format: .dateTime.weekday(.wide).day().month(.wide))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .fixedSize()
                .entrance(0)

                if calendarEnabled {
                    AgendaCard(calendar: calendar, now: context.date)
                        .entrance(1)
                } else {
                    Spacer(minLength: 0)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    private func greeting(for date: Date) -> String {
        switch Calendar.current.component(.hour, from: date) {
        case 5..<12: "Bom dia"
        case 12..<18: "Boa tarde"
        default: "Boa noite"
        }
    }
}

/// Cartão de vidro com os próximos eventos, ou o pedido de acesso à agenda.
private struct AgendaCard: View {
    let calendar: CalendarMonitor
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch calendar.access {
            case .notDetermined:
                prompt(
                    symbol: "calendar.badge.plus",
                    text: "Veja seus próximos eventos aqui",
                    action: "Conectar agenda",
                    perform: calendar.requestAccess
                )
            case .denied:
                prompt(
                    symbol: "calendar.badge.exclamationmark",
                    text: "O Canopy não tem acesso à agenda",
                    action: "Abrir Ajustes",
                    perform: calendar.openPrivacySettings
                )
            case .granted:
                let upcoming = Array(calendar.events.prefix(2))
                if upcoming.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Agenda livre")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Nada marcado até amanhã")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.55))
                        }
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    ForEach(upcoming) { event in
                        EventRow(event: event, now: now)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func prompt(symbol: String, text: String, action: String, perform: @escaping @MainActor () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(text, systemImage: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
            Button(action, action: perform)
                .buttonStyle(CapsuleButtonStyle())
        }
        .frame(maxHeight: .infinity)
    }
}

private struct EventRow: View {
    let event: CalendarMonitor.Event
    let now: Date

    var body: some View {
        HStack(spacing: 9) {
            Capsule()
                .fill(event.color)
                .frame(width: 4)
                .shadow(color: event.color.opacity(0.6), radius: 3)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(when)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(event.isHappening(at: now) ? event.color : .white.opacity(0.55))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if let url = event.meetingURL {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Image(systemName: "video.fill").font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(IslandButtonStyle(size: 26))
            }
        }
        .frame(height: 32)
    }

    private var when: String {
        if event.isAllDay {
            return Calendar.current.isDateInToday(event.start) ? "Hoje, dia inteiro" : "Amanhã, dia inteiro"
        }
        if event.isHappening(at: now) {
            return "Agora · até " + event.end.formatted(date: .omitted, time: .shortened)
        }
        let time = event.start.formatted(date: .omitted, time: .shortened)
        return Calendar.current.isDateInToday(event.start) ? "Hoje, \(time)" : "Amanhã, \(time)"
    }
}
