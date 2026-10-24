import SwiftUI

@main
struct CanopyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        Preferences.register()
    }

    var body: some Scene {
        MenuBarExtra("Canopy", systemImage: "capsule.fill") {
            MenuContent()
                .environment(appDelegate.coordinator)
                .environment(appDelegate.timer)
        }

        Settings {
            SettingsView()
                .environment(appDelegate.coordinator)
                .environment(appDelegate.touchID)
                .environment(appDelegate.calendar)
                .environment(appDelegate.weather)
                .environment(appDelegate.tray)
        }
    }
}

private struct MenuContent: View {
    @Environment(IslandCoordinator.self) private var coordinator
    @Environment(TimerController.self) private var timer

    var body: some View {
        @Bindable var coordinator = coordinator
        Menu("Timer") {
            ForEach([1, 5, 10, 25], id: \.self) { minutes in
                Button("\(minutes) min") { timer.start(minutes: minutes) }
            }
            if timer.timer != nil {
                Divider()
                Button("Cancelar timer", action: timer.cancel)
            }
        }
        Toggle("Atividade de teste", isOn: $coordinator.showsDemoActivity)
        SettingsLink {
            Text("Ajustes…")
        }
        .keyboardShortcut(",")
        Divider()
        Button("Sair do Canopy") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
