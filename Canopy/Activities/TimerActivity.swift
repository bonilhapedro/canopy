import CanopyCore
import SwiftUI

/// Timer correndo: anel laranja à esquerda e a contagem à direita do notch.
@MainActor
final class TimerActivity: IslandActivity {
    static let activityID = "timer"

    let id = TimerActivity.activityID
    let priority = ActivityPriority.normal
    let accent: Color? = .orange
    let tabSymbol = "timer"
    private let timer: TimerController

    init(timer: TimerController) {
        self.timer = timer
    }

    var compactLeading: AnyView { AnyView(TimerRing(timer: timer, size: 18, lineWidth: 2.5)) }
    var compactTrailing: AnyView {
        AnyView(
            TimerCountdown(timer: timer)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.orange)
        )
    }
    var minimal: AnyView { AnyView(TimerRing(timer: timer, size: 14, lineWidth: 2)) }
    var expanded: AnyView { AnyView(TimerPage(timer: timer)) }
}

/// O alarme tocando: sino balançando até alguém dispensar.
@MainActor
final class TimerDoneActivity: IslandActivity {
    static let activityID = "timer.done"

    let id = TimerDoneActivity.activityID
    let priority = ActivityPriority.alert
    let accent: Color? = .orange
    let tabSymbol = "bell.fill"
    private let timer: TimerController

    init(timer: TimerController) {
        self.timer = timer
    }

    var compactLeading: AnyView { AnyView(RingingBell(size: 15)) }
    var compactTrailing: AnyView {
        AnyView(
            Text("Fim")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.orange)
        )
    }
    var minimal: AnyView { AnyView(RingingBell(size: 11)) }
    var expanded: AnyView {
        AnyView(
            HStack(spacing: 18) {
                RingingBell(size: 46)
                    .frame(width: 70)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Timer terminou")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                    Text(CountdownTimer.format(timer.lastDuration))
                        .font(.system(size: 38, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(.orange)
                }
                .entrance(1)
                Spacer(minLength: 0)
                HStack(spacing: 10) {
                    Button("+1 min", action: timer.addMinute)
                        .buttonStyle(CapsuleButtonStyle())
                    Button("Parar", action: timer.stopAlarm)
                        .buttonStyle(CapsuleButtonStyle(tint: .orange, isProminent: true))
                }
                .entrance(2)
            }
            .foregroundStyle(.white)
            .frame(maxHeight: .infinity)
        )
    }
}

/// A página do timer: atalhos quando parado, contagem e controles quando correndo.
struct TimerPage: View {
    let timer: TimerController

    var body: some View {
        if timer.timer != nil {
            HStack(spacing: 20) {
                TimerRing(timer: timer, size: 84, lineWidth: 7)
                    .overlay {
                        Image(systemName: timer.isRunning ? "timer" : "pause.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.orange)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .entrance(0)
                VStack(alignment: .leading, spacing: 2) {
                    Text(timer.isRunning ? "Timer" : "Pausado")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                        .contentTransition(.opacity)
                    TimerCountdown(timer: timer, rolls: true)
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(.white)
                }
                .entrance(1)
                Spacer(minLength: 0)
                GlassEffectContainer(spacing: 8) {
                    HStack(spacing: 4) {
                        Button(action: timer.addMinute) {
                            Text("+1").font(.system(size: 13, weight: .bold))
                        }
                        .buttonStyle(IslandButtonStyle(size: 38))
                        Button(action: timer.togglePause) {
                            Image(systemName: timer.isRunning ? "pause.fill" : "play.fill")
                                .font(.system(size: 22))
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .buttonStyle(IslandButtonStyle(size: 44))
                        Button(action: timer.cancel) {
                            Image(systemName: "xmark").font(.system(size: 15, weight: .bold))
                        }
                        .buttonStyle(IslandButtonStyle(size: 38))
                    }
                }
                .entrance(2)
            }
            .frame(maxHeight: .infinity)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "timer")
                        .foregroundStyle(.orange)
                    Text("Novo timer")
                        .foregroundStyle(.white.opacity(0.8))
                }
                .font(.system(size: 15, weight: .semibold))
                .entrance(0)
                GlassEffectContainer(spacing: 10) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                        ForEach(Array(TimerController.presets.enumerated()), id: \.element) { index, minutes in
                            Button {
                                timer.start(minutes: minutes)
                            } label: {
                                Text(minutes == 60 ? "1 h" : "\(minutes) min")
                                    .font(.system(size: 14, weight: .semibold))
                                    .monospacedDigit()
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(CapsuleButtonStyle())
                            .entrance(1 + index / 4)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

/// Anel que esvazia conforme o tempo passa.
struct TimerRing: View {
    let timer: TimerController
    let size: CGFloat
    let lineWidth: CGFloat
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        let countdown = timer.timer
        TimelineView(schedule(for: countdown)) { context in
            let remaining = 1 - (countdown?.progress(at: context.date) ?? 1)
            ZStack {
                Circle()
                    .stroke(Color.orange.opacity(0.22), lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: remaining)
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: .orange.opacity(0.6), radius: lineWidth)
            }
        }
        .frame(width: size, height: size)
    }

    /// O anel só muda na tela quando a ponta anda um pixel. Num timer de 25 minutos isso leva
    /// segundos; redesenhar mais vezes que isso, até no máximo uma por segundo, não muda nada.
    private func schedule(for countdown: CountdownTimer?) -> AlignedSchedule {
        guard let countdown, let end = countdown.endDate else {
            return AlignedSchedule(anchor: .now, interval: 1, isPaused: true)
        }
        let pixels = max(Double(size) * .pi * Double(displayScale), 1)
        return AlignedSchedule(anchor: end, interval: min(max(countdown.duration / pixels, 1.0 / 15), 1))
    }
}

/// A contagem em texto, redesenhada só quando o segundo vira.
struct TimerCountdown: View {
    let timer: TimerController
    /// Na página do timer os números rolam; na ilha compacta, que fica na tela o tempo todo, só trocam.
    var rolls = false

    var body: some View {
        let countdown = timer.timer
        let end = countdown?.endDate
        TimelineView(AlignedSchedule(anchor: end ?? .now, interval: 1, isPaused: end == nil)) { context in
            let remaining = countdown?.remaining(at: context.date) ?? 0
            Text(CountdownTimer.format(remaining))
                .monospacedDigit()
                .contentTransition(rolls ? .numericText(countsDown: true) : .identity)
                .animation(rolls ? .snappy : nil, value: Int(remaining.rounded(.up)))
        }
    }
}

struct RingingBell: View {
    let size: CGFloat
    @State private var rings = 0

    var body: some View {
        Image(systemName: "bell.fill")
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(.orange)
            .shadow(color: .orange.opacity(0.6), radius: size * 0.3)
            .symbolEffect(.wiggle, value: rings)
            // Balança junto com o som do alarme e depois sossega: um sino balançando
            // sem parar, com ninguém olhando, gastaria CPU à toa.
            .task {
                for _ in 0..<6 {
                    rings += 1
                    do {
                        try await Task.sleep(for: .seconds(1.4))
                    } catch {
                        return
                    }
                }
            }
    }
}
