import AppKit
import CanopyCore
import Observation

/// O timer da ilha: um por vez, com pausa, mais um minuto e alarme no fim.
@MainActor
@Observable
final class TimerController {
    private(set) var timer: CountdownTimer?
    /// O timer chegou a zero e o alarme ainda não foi dispensado.
    private(set) var isRinging = false
    /// Duração do último timer iniciado, para o "terminou" dizer de quanto era.
    private(set) var lastDuration: TimeInterval = 0

    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private var finishTask: Task<Void, Never>?
    @ObservationIgnored private var alarmTask: Task<Void, Never>?

    /// Atalhos de duração mostrados na página do timer, em minutos.
    static let presets = [1, 3, 5, 10, 15, 25, 45, 60]

    var isRunning: Bool { timer.map { !$0.isPaused } ?? false }

    func start(minutes: Int) {
        stopAlarm()
        lastDuration = TimeInterval(minutes * 60)
        timer = CountdownTimer(duration: lastDuration, startingAt: .now)
        scheduleFinish()
        onChange?()
    }

    func togglePause() {
        guard var timer else { return }
        if timer.isPaused {
            timer.resume(at: .now)
        } else {
            timer.pause(at: .now)
        }
        self.timer = timer
        scheduleFinish()
        onChange?()
    }

    func addMinute() {
        if isRinging {
            start(minutes: 1)
            return
        }
        guard var timer else { return }
        timer.add(60, at: .now)
        self.timer = timer
        lastDuration = timer.duration
        scheduleFinish()
        onChange?()
    }

    func cancel() {
        finishTask?.cancel()
        stopAlarm()
        timer = nil
        onChange?()
    }

    // MARK: - Fim

    private func scheduleFinish() {
        finishTask?.cancel()
        guard let timer, !timer.isPaused else { return }
        let remaining = timer.remaining(at: .now)
        finishTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(remaining))
            guard !Task.isCancelled else { return }
            self?.finish()
        }
    }

    private func finish() {
        timer = nil
        isRinging = true
        onChange?()
        if Preferences.haptics {
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        }
        guard Preferences.timerSound else { return }
        // Toca algumas vezes, como um despertador, até ser dispensado.
        alarmTask = Task { [weak self] in
            for _ in 0..<4 {
                guard let self, self.isRinging, !Task.isCancelled else { return }
                NSSound(named: "Glass")?.play()
                try? await Task.sleep(for: .seconds(1.4))
            }
        }
    }

    func stopAlarm() {
        alarmTask?.cancel()
        guard isRinging else { return }
        isRinging = false
        onChange?()
    }
}
