import SwiftUI

@main
struct CanopyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Canopy", systemImage: "capsule.fill") {
            MenuContent()
                .environment(appDelegate.coordinator)
        }

        Settings {
            SettingsView()
                .environment(appDelegate.coordinator)
        }
    }
}

private struct MenuContent: View {
    @Environment(IslandCoordinator.self) private var coordinator

    var body: some View {
        @Bindable var coordinator = coordinator
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
