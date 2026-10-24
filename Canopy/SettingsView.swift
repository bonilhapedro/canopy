import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Environment(IslandCoordinator.self) private var coordinator
    @State private var launchesAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        @Bindable var coordinator = coordinator
        Form {
            Toggle("Abrir o Canopy ao iniciar sessão", isOn: launchAtLoginBinding)
            if let loginError {
                Text(loginError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            Toggle("Mostrar atividade de teste", isOn: $coordinator.showsDemoActivity)
        }
        .formStyle(.grouped)
        .frame(width: 420)
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding {
            launchesAtLogin
        } set: { enabled in
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
                loginError = nil
            } catch {
                loginError = error.localizedDescription
            }
            launchesAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
