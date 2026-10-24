import CoreGraphics
import Foundation

/// Chaves dos Ajustes no UserDefaults.
enum SettingsKey {
    static let glassIsland = "glassIsland"
    static let glassDarkness = "glassDarkness"
    static let expandOnHover = "expandOnHover"
    static let haptics = "haptics"
    static let hideInFullscreen = "hideInFullscreen"
    static let hideFromCapture = "hideFromCapture"
    static let pillWidthAdjustment = "pillWidthAdjustment"
    static let pillHeightAdjustment = "pillHeightAdjustment"
    static let unlockAnimation = "unlockAnimation"
    static let unlockSound = "unlockSound"
    static let batteryAlerts = "batteryAlerts"
    static let outputAlerts = "outputAlerts"
    static let volumeHUD = "volumeHUD"
    static let brightnessHUD = "brightnessHUD"
    static let replaceSystemHUD = "replaceSystemHUD"
    static let matchSongColor = "matchSongColor"
    static let weatherEnabled = "weatherEnabled"
    static let preciseLocation = "preciseLocation"
    static let fahrenheit = "fahrenheit"
    static let calendarEnabled = "calendarEnabled"
    static let meetingAlerts = "meetingAlerts"
    static let timerSound = "timerSound"
    static let trayEnabled = "trayEnabled"
    static let trayCopiesFiles = "trayCopiesFiles"
    static let trayRemovesAfterDrag = "trayRemovesAfterDrag"
}

/// Valores padrão dos Ajustes e atalhos para ler cada um fora das views.
enum Preferences {
    // Só é lido; o dicionário nunca muda depois de criado.
    nonisolated(unsafe) static let defaults: [String: Any] = [
        SettingsKey.glassIsland: true,
        SettingsKey.glassDarkness: 0.25,
        SettingsKey.expandOnHover: true,
        SettingsKey.haptics: true,
        SettingsKey.hideInFullscreen: false,
        SettingsKey.hideFromCapture: false,
        SettingsKey.pillWidthAdjustment: 0.0,
        SettingsKey.pillHeightAdjustment: 0.0,
        SettingsKey.unlockAnimation: true,
        SettingsKey.unlockSound: false,
        SettingsKey.batteryAlerts: true,
        SettingsKey.outputAlerts: true,
        SettingsKey.volumeHUD: true,
        SettingsKey.brightnessHUD: true,
        SettingsKey.replaceSystemHUD: true,
        SettingsKey.matchSongColor: true,
        SettingsKey.weatherEnabled: true,
        SettingsKey.preciseLocation: false,
        SettingsKey.fahrenheit: false,
        SettingsKey.calendarEnabled: true,
        SettingsKey.meetingAlerts: true,
        SettingsKey.timerSound: true,
        SettingsKey.trayEnabled: true,
        SettingsKey.trayCopiesFiles: false,
        SettingsKey.trayRemovesAfterDrag: true,
    ]

    /// Precisa rodar antes de qualquer leitura, para os padrões valerem também no @AppStorage.
    static func register() {
        UserDefaults.standard.register(defaults: defaults)
    }

    /// Volta tudo ao padrão.
    static func reset() {
        for key in defaults.keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    private static func bool(_ key: String) -> Bool { UserDefaults.standard.bool(forKey: key) }
    private static func double(_ key: String) -> Double { UserDefaults.standard.double(forKey: key) }

    static var expandOnHover: Bool { bool(SettingsKey.expandOnHover) }
    static var haptics: Bool { bool(SettingsKey.haptics) }
    static var hideInFullscreen: Bool { bool(SettingsKey.hideInFullscreen) }
    static var hideFromCapture: Bool { bool(SettingsKey.hideFromCapture) }
    static var pillAdjustment: CGSize {
        CGSize(width: double(SettingsKey.pillWidthAdjustment), height: double(SettingsKey.pillHeightAdjustment))
    }
    static var unlockAnimation: Bool { bool(SettingsKey.unlockAnimation) }
    static var unlockSound: Bool { bool(SettingsKey.unlockSound) }
    static var batteryAlerts: Bool { bool(SettingsKey.batteryAlerts) }
    static var outputAlerts: Bool { bool(SettingsKey.outputAlerts) }
    static var volumeHUD: Bool { bool(SettingsKey.volumeHUD) }
    static var brightnessHUD: Bool { bool(SettingsKey.brightnessHUD) }
    static var replaceSystemHUD: Bool { bool(SettingsKey.replaceSystemHUD) }
    static var matchSongColor: Bool { bool(SettingsKey.matchSongColor) }
    static var weatherEnabled: Bool { bool(SettingsKey.weatherEnabled) }
    static var preciseLocation: Bool { bool(SettingsKey.preciseLocation) }
    static var fahrenheit: Bool { bool(SettingsKey.fahrenheit) }
    static var calendarEnabled: Bool { bool(SettingsKey.calendarEnabled) }
    static var meetingAlerts: Bool { bool(SettingsKey.meetingAlerts) }
    static var timerSound: Bool { bool(SettingsKey.timerSound) }
    static var trayEnabled: Bool { bool(SettingsKey.trayEnabled) }
    static var trayCopiesFiles: Bool { bool(SettingsKey.trayCopiesFiles) }
    static var trayRemovesAfterDrag: Bool { bool(SettingsKey.trayRemovesAfterDrag) }
}
