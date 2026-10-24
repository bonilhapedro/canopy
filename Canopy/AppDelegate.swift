import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let coordinator = IslandCoordinator()
    private let music = MusicController()
    private let battery = BatteryMonitor()
    private let privacy = PrivacyMonitor()
    private let volume = VolumeMonitor()

    private var windowController: NotchWindowController?
    private var screenObserver: NSObjectProtocol?
    private var clickMonitor: Any?
    private var musicPauseTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = NotchWindowController(coordinator: coordinator)
        controller.show()
        windowController = controller

        // Monitor ligado, desligado ou resolução trocada: reposiciona a ilha.
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.windowController?.reposition() }
        }

        // Um clique em qualquer outro app fecha a ilha aberta.
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.coordinator.dismiss() }
        }

        startModules()
    }

    private func startModules() {
        music.onChange = { [weak self] in self?.musicChanged() }
        music.start()

        battery.onEvent = { [weak self] event, snapshot in
            self?.coordinator.flash(BatteryActivity(event: event, snapshot: snapshot), for: .seconds(4))
        }
        battery.start()

        privacy.onChange = { [weak self] in self?.privacyChanged() }
        privacy.start()

        volume.onChange = { [weak self] in
            guard let self else { return }
            coordinator.flash(VolumeActivity(volume: volume), for: .seconds(1.5))
        }
        volume.start()
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
}
