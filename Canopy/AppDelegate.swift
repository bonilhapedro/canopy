import AppKit
import CanopyCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let coordinator = IslandCoordinator()
    let touchID = TouchIDAuthenticator()
    let calendar = CalendarMonitor()
    let weather = WeatherService()
    let timer = TimerController()

    let battery = BatteryMonitor()
    let tray = FileTray()

    private let music = MusicController()
    private let privacy = PrivacyMonitor()
    private let volume = VolumeMonitor()
    private let brightness = BrightnessController()
    private let mediaKeys = MediaKeyInterceptor()
    private let lock = LockMonitor()
    private let output = AudioOutputMonitor()
    private let fullscreen = FullscreenMonitor()

    private var windowController: NotchWindowController?
    private var screenObserver: NSObjectProtocol?
    private var defaultsObserver: NSObjectProtocol?
    private var clickMonitor: Any?
    private var musicPauseTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = NotchWindowController(
            coordinator: coordinator,
            services: IslandServices(calendar: calendar, weather: weather, timer: timer, battery: battery, tray: tray)
        )
        windowController = controller
        startModules()
        applyPreferences()
        controller.show()

        // Monitor ligado, desligado ou resolução trocada: reposiciona a ilha.
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.windowController?.reposition()
                self?.brightness.displaysChanged()
            }
        }

        // Ajustes mudaram: aplica na hora, sem reiniciar.
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.applyPreferences() }
        }

        coordinator.onPhaseChange = { [weak self] phase in self?.phaseChanged(phase) }

        #if BENCHMARK
        runBenchmark()
        #endif
    }

    /// Chamado a cada mudança nos UserDefaults, inclusive as que não são dos Ajustes;
    /// por isso cada passo só faz alguma coisa quando o valor dele mudou mesmo.
    private func applyPreferences() {
        let adjustment = Preferences.pillAdjustment
        if coordinator.closedAdjustment != adjustment { coordinator.closedAdjustment = adjustment }
        let showsWeather = Preferences.weatherEnabled
        if coordinator.showsWeather != showsWeather { coordinator.showsWeather = showsWeather }
        let showsTray = Preferences.trayEnabled
        if coordinator.showsTray != showsTray { coordinator.showsTray = showsTray }
        windowController?.applyPreferences()
        mediaKeys.setEnabled(Preferences.replaceSystemHUD && (Preferences.volumeHUD || Preferences.brightnessHUD))
        // Sem esconder em tela cheia, ninguém precisa saber quando um app entra em tela cheia.
        fullscreen.setEnabled(Preferences.hideInFullscreen)
    }

    /// O que só precisa existir com a ilha aberta.
    private func phaseChanged(_ phase: IslandPhase) {
        if phase == .expanded {
            // Um clique em qualquer outro app fecha a ilha aberta. Fechada, os cliques do Mac
            // inteiro não precisam passar pelo Canopy.
            if clickMonitor == nil {
                clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                    MainActor.assumeIsolated { self?.coordinator.dismiss() }
                }
            }
            // O clima só é buscado quando alguém pode olhar para ele.
            weather.refreshIfNeeded()
        } else if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
    }

    private func startModules() {
        music.onChange = { [weak self] in self?.musicChanged() }
        music.start()

        battery.onEvent = { [weak self] event, snapshot in
            guard Preferences.batteryAlerts else { return }
            self?.coordinator.flash(BatteryActivity(event: event, snapshot: snapshot), for: .seconds(event == .pluggedIn ? 5 : 4))
        }
        battery.start()

        privacy.onChange = { [weak self] in self?.privacyChanged() }
        privacy.start()

        volume.onChange = { [weak self] in self?.showVolume() }
        volume.start()

        brightness.onChange = { [weak self] in self?.showBrightness() }
        brightness.start()

        mediaKeys.handler = { [weak self] key, fine in
            self?.mediaKeyPressed(key, fine: fine) ?? false
        }

        output.onChange = { [weak self] kind, name in
            guard Preferences.outputAlerts else { return }
            self?.coordinator.flash(OutputActivity(kind: kind, name: name), for: .seconds(3))
        }
        output.start()

        lock.onUnlock = { [weak self] in
            guard Preferences.unlockAnimation else { return }
            self?.coordinator.flash(UnlockActivity(), for: .seconds(1.8))
            if Preferences.unlockSound {
                NSSound(named: "Pop")?.play()
            }
        }
        lock.start()

        touchID.onChange = { [weak self] in self?.touchIDChanged() }

        timer.onChange = { [weak self] in self?.timerChanged() }

        calendar.onUpcomingChange = { [weak self] in self?.meetingChanged() }
        calendar.start()

        tray.start()

        fullscreen.screenSize = { [weak self] in self?.windowController?.screen?.frame.size }
        fullscreen.onChange = { [weak self] isFullscreen in
            self?.windowController?.setHidden(isFullscreen)
        }
    }

    private func showVolume() {
        guard Preferences.volumeHUD else { return }
        let tint = Preferences.matchSongColor && music.nowPlaying?.isPlaying == true ? music.accent ?? .white : .white
        coordinator.flash(VolumeActivity(volume: volume, tint: tint), for: .seconds(1.5))
    }

    private func showBrightness() {
        guard Preferences.brightnessHUD else { return }
        coordinator.flash(BrightnessActivity(brightness: brightness), for: .seconds(1.5))
    }

    /// As teclas de volume e brilho, já tiradas do macOS. Devolver false deixa a tecla seguir para ele,
    /// como numa saída de áudio sem controle de volume (HDMI) ou com o indicador da ilha desligado.
    private func mediaKeyPressed(_ key: MediaKeyInterceptor.Key, fine: Bool) -> Bool {
        switch key {
        case .volumeUp, .volumeDown:
            guard Preferences.volumeHUD, volume.canSetVolume else { return false }
            volume.step(up: key == .volumeUp, fine: fine)
            // No máximo ou no zero o volume não muda, mas o indicador aparece mesmo assim, como no macOS.
            showVolume()
        case .mute:
            guard Preferences.volumeHUD, volume.canMute else { return false }
            volume.setMuted(!volume.isMuted)
            showVolume()
        case .brightnessUp, .brightnessDown:
            guard Preferences.brightnessHUD, brightness.isAvailable else { return false }
            brightness.step(up: key == .brightnessUp, fine: fine)
        }
        return true
    }

    /// Pausada, a música continua na ilha por 30 segundos antes de sair.
    private func musicChanged() {
        musicPauseTask?.cancel()
        guard let track = music.nowPlaying else {
            coordinator.end(id: MusicActivity.activityID)
            return
        }
        if !coordinator.isActive(id: MusicActivity.activityID) {
            coordinator.start(MusicActivity(music: music))
        }
        if !track.isPlaying {
            musicPauseTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { return }
                self?.coordinator.end(id: MusicActivity.activityID)
            }
        }
    }

    private func privacyChanged() {
        if privacy.isAnyInUse {
            if !coordinator.isActive(id: PrivacyActivity.activityID) {
                coordinator.start(PrivacyActivity(privacy: privacy))
            }
        } else {
            coordinator.end(id: PrivacyActivity.activityID)
        }
    }

    /// Enquanto lê o dedo, a ilha fica com a digital; o resultado aparece por um instante e sai.
    private func touchIDChanged() {
        switch touchID.state {
        case .idle:
            coordinator.end(id: TouchIDActivity.activityID)
        case .scanning:
            coordinator.start(TouchIDActivity(touchID: touchID))
        case .success, .failure:
            coordinator.flash(TouchIDActivity(touchID: touchID), for: .seconds(1.6))
        }
    }

    /// Timer correndo fica na ilha; ao terminar, o alarme entra na frente até ser dispensado.
    private func timerChanged() {
        if timer.timer != nil {
            if !coordinator.isActive(id: TimerActivity.activityID) {
                coordinator.start(TimerActivity(timer: timer))
            }
        } else {
            coordinator.end(id: TimerActivity.activityID)
        }
        if timer.isRinging {
            if !coordinator.isActive(id: TimerDoneActivity.activityID) {
                coordinator.start(TimerDoneActivity(timer: timer))
            }
        } else {
            coordinator.end(id: TimerDoneActivity.activityID)
        }
    }

    private func meetingChanged() {
        if let event = calendar.upcoming {
            coordinator.start(MeetingActivity(event: event))
        } else {
            coordinator.end(id: MeetingActivity.activityID)
        }
    }
}

#if BENCHMARK
// MARK: - Medição

/// Cenários fixos para medir memória e CPU sem ninguém mexendo no Mac, como no CI.
/// Só existem nos builds com BENCHMARK; veja scripts/benchmark.sh.
extension AppDelegate {
    private func runBenchmark() {
        let scenario = UserDefaults.standard.string(forKey: "benchmarkScenario") ?? "idle"
        switch scenario {
        case "music":
            music.simulatePlayback()
        case "music-expanded":
            music.simulatePlayback()
            coordinator.click()
        case "timer":
            timer.start(minutes: 25)
        case "privacy":
            privacy.simulateMicrophone()
        case "charging-expanded":
            let snapshot = BatterySnapshot(percent: 64, isCharging: true, isPluggedIn: true)
            coordinator.start(BatteryActivity(event: .pluggedIn, snapshot: snapshot))
            coordinator.click()
        case "home":
            coordinator.click()
        case "tray":
            tray.simulateItems()
            coordinator.click()
            coordinator.select(.tray)
        default:
            break
        }
        // Prova no log que a ilha está mesmo na tela, e onde capturá-la: o screencapture conta de cima.
        let screens = NSScreen.screens.map { "\($0.frame)" }.joined(separator: ", ")
        let panel = windowController?.panelFrame ?? .zero
        let top = NSScreen.screens.first?.frame.maxY ?? 0
        let capture = [panel.minX, top - panel.maxY, panel.width, panel.height].map { "\(Int($0))" }.joined(separator: ",")
        FileHandle.standardError.write(Data("benchmark: scenario=\(scenario) phase=\(coordinator.phase) screens=[\(screens)] panel=\(panel) capture=\(capture)\n".utf8))
    }
}
#endif
