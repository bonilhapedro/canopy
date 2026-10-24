import ServiceManagement
import SwiftUI

/// Ajustes com barra lateral, no estilo do Canopy original.
struct SettingsView: View {
    @State private var section: SettingsSection? = .general

    var body: some View {
        NavigationSplitView {
            List(selection: $section) {
                Section {
                    ForEach(SettingsSection.main) { item in
                        Label(item.title, systemImage: item.symbol).tag(item)
                    }
                }
                Section("Sobreposições") {
                    ForEach(SettingsSection.overlays) { item in
                        Label(item.title, systemImage: item.symbol).tag(item)
                    }
                }
            }
            .navigationSplitViewColumnWidth(190)
        } detail: {
            Group {
                switch section ?? .general {
                case .general: GeneralSettings()
                case .media: MediaSettings()
                case .fileTray: ComingSoon(section: .fileTray, text: "Arraste arquivos até o notch para guardá-los na ilha e soltá-los depois em outro app ou no AirDrop.")
                case .touchID: TouchIDSettings()
                }
            }
            .navigationTitle((section ?? .general).title)
        }
        .frame(width: 720, height: 500)
    }
}

enum SettingsSection: String, Identifiable, Hashable {
    case general, media, fileTray, touchID

    static let main: [SettingsSection] = [.general, .media, .fileTray]
    static let overlays: [SettingsSection] = [.touchID]

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "Geral"
        case .media: "Mídia"
        case .fileTray: "Bandeja de arquivos"
        case .touchID: "Touch ID"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .media: "music.note"
        case .fileTray: "tray.full"
        case .touchID: "touchid"
        }
    }
}

private struct GeneralSettings: View {
    @Environment(IslandCoordinator.self) private var coordinator
    @AppStorage(SettingsKey.glassIsland) private var glassIsland = true
    @AppStorage(SettingsKey.glassDarkness) private var glassDarkness = 0.25
    @State private var launchesAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        @Bindable var coordinator = coordinator
        Form {
            Section {
                Toggle("Abrir o Canopy ao iniciar sessão", isOn: launchAtLoginBinding)
                if let loginError {
                    Text(loginError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            Section("Aparência") {
                Toggle("Liquid Glass na ilha aberta", isOn: $glassIsland)
                LabeledContent("Vidro") {
                    HStack {
                        Text("Claro").foregroundStyle(.secondary)
                        Slider(value: $glassDarkness, in: 0...1)
                        Text("Escuro").foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: 280)
                }
                .disabled(!glassIsland)
            }
            Section("Desenvolvimento") {
                Toggle("Mostrar atividade de teste", isOn: $coordinator.showsDemoActivity)
            }
        }
        .formStyle(.grouped)
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

private struct MediaSettings: View {
    var body: some View {
        Form {
            Section {
                LabeledContent("Players", value: "Apple Music e Spotify")
                Text("Na primeira vez que tocar algo, o macOS pede para o Canopy controlar o player. Se negar, libere em Ajustes do Sistema › Privacidade e Segurança › Automação.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

private struct TouchIDSettings: View {
    @Environment(TouchIDAuthenticator.self) private var touchID
    @AppStorage(SettingsKey.unlockAnimation) private var unlockAnimation = true
    @AppStorage(SettingsKey.unlockSound) private var unlockSound = false

    var body: some View {
        Form {
            Section {
                Toggle("Animação de desbloqueio na ilha", isOn: $unlockAnimation)
                Toggle("Som ao desbloquear", isOn: $unlockSound)
                    .disabled(!unlockAnimation)
            } footer: {
                Text("Quando você desbloqueia o Mac com o Touch ID, a ilha mostra o cadeado se abrindo, como o Face ID no iPhone. O macOS não deixa apps aparecerem na própria tela de bloqueio, então a animação vem logo depois.")
            }
            Section {
                LabeledContent("Sensor") {
                    Text(touchID.isAvailable ? "Disponível" : "Indisponível")
                        .foregroundStyle(touchID.isAvailable ? .green : .secondary)
                }
                Button("Testar Touch ID") {
                    touchID.authenticate(reason: "testar o Touch ID no Canopy")
                }
                .disabled(!touchID.isAvailable || touchID.state == .scanning)
            }
        }
        .formStyle(.grouped)
    }
}

/// Página de um recurso que ainda vai ser feito.
private struct ComingSoon: View {
    let section: SettingsSection
    let text: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: section.symbol)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.secondary)
                .frame(width: 96, height: 96)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            Text("Em breve")
                .font(.title2.weight(.semibold))
            Text(text)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

enum SettingsKey {
    static let glassIsland = "glassIsland"
    static let glassDarkness = "glassDarkness"
    static let unlockAnimation = "unlockAnimation"
    static let unlockSound = "unlockSound"
}
