import Foundation

/// Um timer regressivo que pode ser pausado e esticado. Só guarda datas, então não precisa de tique.
public struct CountdownTimer: Sendable, Equatable {
    /// Duração total, incluindo os minutos acrescentados.
    public private(set) var duration: TimeInterval
    /// Quando termina, se estiver correndo.
    public private(set) var endDate: Date?
    /// Quanto faltava quando foi pausado.
    public private(set) var pausedRemaining: TimeInterval?

    public init(duration: TimeInterval, startingAt now: Date) {
        self.duration = max(duration, 0)
        endDate = now.addingTimeInterval(self.duration)
    }

    public var isPaused: Bool { pausedRemaining != nil }

    public func remaining(at date: Date) -> TimeInterval {
        if let pausedRemaining { return pausedRemaining }
        guard let endDate else { return 0 }
        return max(endDate.timeIntervalSince(date), 0)
    }

    public func isFinished(at date: Date) -> Bool {
        !isPaused && remaining(at: date) <= 0
    }

    /// Quanto já passou, de 0 a 1.
    public func progress(at date: Date) -> Double {
        guard duration > 0 else { return 1 }
        return min(max(1 - remaining(at: date) / duration, 0), 1)
    }

    public mutating func pause(at date: Date) {
        guard !isPaused else { return }
        pausedRemaining = remaining(at: date)
        endDate = nil
    }

    public mutating func resume(at date: Date) {
        guard let pausedRemaining else { return }
        endDate = date.addingTimeInterval(pausedRemaining)
        self.pausedRemaining = nil
    }

    public mutating func add(_ seconds: TimeInterval, at date: Date) {
        duration += seconds
        if let pausedRemaining {
            self.pausedRemaining = pausedRemaining + seconds
        } else {
            endDate = date.addingTimeInterval(remaining(at: date) + seconds)
        }
    }

    /// "4:05" ou "1:02:03".
    public static func format(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded(.up))
        let hours = total / 3600
        let minutes = total % 3600 / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
