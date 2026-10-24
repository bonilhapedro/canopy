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

    private let music = MusicController()
    private let battery = BatteryMonitor()
    private let privacy = PrivacyMonitor()
    private let volume = VolumeMonitor()
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
            services: IslandServices(calendar: calendar, weather: weather, timer: timer)
        )
        windowController = controller
        applyPreferences()
        controller.show()

        // Monitor ligado, desligado ou resolução trocada: reposiciona a ilha.
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.windowController?.reposition() }
        }

        // Ajustes mudaram: aplica na hora, sem reiniciar.
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.applyPreferences() }
        }

        // Um clique em qualquer outro app fecha a ilha aberta.
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.coordinator.dismiss() }
        }

        startModules()
    }

    private func applyPreferences() {
        let adjustment = Preferences.pillAdjustment
        if coordinator.closedAdjustment != adjustment { coordinator.closedAdjustment = adjustment }
        let showsWeather = Preferences.weatherEnabled
        if coordinator.showsWeather != showsWeather { coordinator.showsWeather = showsWeather }
        windowController?.applyPreferences()
        if !Preferences.hideInFullscreen { windowController?.setHidden(false) }
        fullscreen.check()
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

        volume.onChange = { [weak self] in
            guard let self, Preferences.volumeHUD else { return }
            let tint = Preferences.matchSongColor && music.nowPlaying?.isPlaying == true ? music.accent ?? .white : .white
            coordinator.flash(VolumeActivity(volume: volume, tint: tint), for: .seconds(1.5))
        }
        volume.start()

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

        weather.start()

        fullscreen.screenSize = { [weak self] in self?.windowController?.screen?.frame.size }
        fullscreen.onChange = { [weak self] isFullscreen in
            self?.windowController?.setHidden(isFullscreen && Preferences.hideInFullscreen)
        }
        fullscreen.start()
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
