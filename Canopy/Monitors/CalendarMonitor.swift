import AppKit
import CanopyCore
import EventKit
import Observation
import SwiftUI

/// Lê os próximos eventos da agenda do Mac e avisa quando uma reunião está para começar.
@MainActor
@Observable
final class CalendarMonitor {
    enum Access {
        case notDetermined, granted, denied
    }

    struct Event: Identifiable, Equatable {
        let id: String
        let title: String
        let start: Date
        let end: Date
        let isAllDay: Bool
        let color: Color
        let location: String?
        let meetingURL: URL?

        func isHappening(at date: Date) -> Bool { start <= date && date < end }
    }

    private(set) var access = Access.notDetermined
    /// Eventos de hoje e amanhã que ainda não terminaram, em ordem.
    private(set) var events: [Event] = []
    /// A reunião que começa nos próximos minutos, para o aviso na ilha.
    private(set) var upcoming: Event?

    @ObservationIgnored var onUpcomingChange: (() -> Void)?
    @ObservationIgnored private let store = EKEventStore()
    @ObservationIgnored private var observer: NSObjectProtocol?
    @ObservationIgnored private var tickTask: Task<Void, Never>?

    /// Quanto antes do início a reunião aparece na ilha.
    static let warningLead: TimeInterval = 5 * 60
    /// Quanto depois do início ela ainda fica, para dar tempo de entrar.
    static let warningTail: TimeInterval = 2 * 60

    func start() {
        updateAccess()
        observer = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: store,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.refresh()
                try? await Task.sleep(for: .seconds(20))
            }
        }
    }

    func requestAccess() {
        store.requestFullAccessToEvents { _, _ in
            Task { @MainActor in
                self.updateAccess()
                self.refresh()
            }
        }
    }

    func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }

    private func updateAccess() {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: access = .granted
        case .notDetermined: access = .notDetermined
        default: access = .denied
        }
    }

    func refresh() {
        guard access == .granted, Preferences.calendarEnabled else {
            if !events.isEmpty { events = [] }
            setUpcoming(nil)
            return
        }
        let now = Date.now
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        guard let endOfTomorrow = calendar.date(byAdding: .day, value: 2, to: startOfToday) else { return }
        let predicate = store.predicateForEvents(withStart: startOfToday, end: endOfTomorrow, calendars: nil)
        let fresh = store.events(matching: predicate)
            .filter { $0.endDate > now && $0.status != .canceled }
            .sorted { lhs, rhs in
                // Eventos de dia inteiro vão para o fim do dia deles.
                if lhs.isAllDay != rhs.isAllDay, calendar.isDate(lhs.startDate, inSameDayAs: rhs.startDate) {
                    return !lhs.isAllDay
                }
                return lhs.startDate < rhs.startDate
            }
            .prefix(8)
            .map { event in
                Event(
                    id: "\(event.calendarItemIdentifier)-\(event.startDate.timeIntervalSince1970)",
                    title: event.title.flatMap { $0.isEmpty ? nil : $0 } ?? "Sem título",
                    start: event.startDate,
                    end: event.endDate,
                    isAllDay: event.isAllDay,
                    color: Color(nsColor: event.calendar?.color ?? .systemBlue),
                    location: event.location,
                    meetingURL: MeetingLink.find(in: [event.url?.absoluteString, event.location, event.notes])
                )
            }
        if fresh != events { events = fresh }

        let soon = fresh.first { event in
            !event.isAllDay
                && event.start.timeIntervalSince(now) <= Self.warningLead
                && now.timeIntervalSince(event.start) <= Self.warningTail
        }
        setUpcoming(Preferences.meetingAlerts ? soon : nil)
    }

    private func setUpcoming(_ event: Event?) {
        guard event != upcoming else { return }
        upcoming = event
        onUpcomingChange?()
    }
}
