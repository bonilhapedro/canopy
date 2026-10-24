import CanopyCore
import SwiftUI

/// Agenda de um TimelineView que só atualiza quando o valor mostrado muda: nos instantes
/// `anchor + k * interval`. Uma contagem de timer ancorada no fim muda exatamente no segundo cheio.
struct AlignedSchedule: TimelineSchedule {
    var anchor: Date
    var interval: TimeInterval
    /// Parado (música pausada, timer pausado), a view é desenhada uma vez e pronto.
    var isPaused = false

    /// Cada tique sai um pouquinho depois do instante exato, para a conta já cair do lado novo.
    private static let lag: TimeInterval = 0.02

    func entries(from startDate: Date, mode: TimelineScheduleMode) -> AnyIterator<Date> {
        var next = AlignedTicks.next(after: startDate, anchor: anchor, interval: interval)
        var startPending = true
        let interval = interval
        let isPaused = isPaused
        return AnyIterator {
            if startPending {
                startPending = false
                return startDate
            }
            guard !isPaused else { return nil }
            defer { next = next.addingTimeInterval(interval) }
            return next.addingTimeInterval(Self.lag)
        }
    }
}
