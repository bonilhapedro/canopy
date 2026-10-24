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
            .navigationSplitViewColumnWidth(200)
        } detail: {
            Group {
                switch section ?? .general {
                case .general: GeneralSettings()
                case .appearance: AppearanceSettings()
                case .media: MediaSettings()
                case .fileTray:
                    ComingSoon(
                        section: .fileTray,
                        text: "Arraste arquivos até o notch para guardá-los na ilha e soltá-los depois em outro app ou no AirDrop."
                    )
                case .battery: BatterySettings()
                case .audio: AudioSettings()
                case .calendar: CalendarSettings()
                case .weather: WeatherSettings()
                case .timer: TimerSettings()
                case .touchID: TouchIDSettings()
                }
            }
            .navigationTitle((section ?? .general).title)
        }
        .frame(width: 760, height: 540)
    }
}

enum SettingsSection: String, Identifiable, Hashable {
    case general, appearance, media, fileTray
    case battery, audio, calendar, weather, timer, touchID

    static let main: [SettingsSection] = [.general, .appearance, .media, .fileTray]
    static let overlays: [SettingsSection] = [.battery, .audio, .calendar, .weather, .timer, .touchID]

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "Geral"
        case .appearance: "Aparência"
        case .media: "Mídia"
        case .fileTray: "Bandeja de arquivos"
        case .battery: "Bateria"
        case .audio: "Volume e saída"
        case .calendar: "Agenda"
        case .weather: "Clima"
        case .timer: "Timer"
        case .touchID: "Touch ID"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .appearance: "paintbrush"
        case .media: "music.note"
        case .fileTray: "tray.full"
        case .battery: "battery.75percent"
        case .audio: "airpodspro"
        case .calendar: "calendar"
        case .weather: "cloud.sun"
        case .timer: "timer"
        case .touchID: "touchid"
        }
    }
}

// MARK: - Geral

private struct GeneralSettings: View {
    @Environment(IslandCoordinator.self) private var coordinator
    @AppStorage(SettingsKey.expandOnHover) private var expandOnHover = true
    @AppStorage(SettingsKey.haptics) private var haptics = true
    @AppStorage(SettingsKey.hideInFullscreen) private var hideInFullscreen = false
    @AppStorage(SettingsKey.hideFromCapture) private var hideFromCapture = false
    @State private var launchesAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?
    @State private var confirmsReset = false

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
            Section("Comportamento") {
                Toggle("Abrir a ilha ao passar o mouse", isOn: $expandOnHover)
                Toggle("Vibração no trackpad", isOn: $haptics)
                Toggle("Esconder com app em tela cheia", isOn: $hideInFullscreen)
                Toggle("Esconder de gravações e capturas de tela", isOn: $hideFromCapture)
            } footer: {
                Text("Com o mouse desligado, a ilha abre com um clique. Com a ilha aberta, arraste dois dedos para os lados no trackpad para trocar de página.")
            }
            Section("Desenvolvimento") {
                Toggle("Mostrar atividade de teste", isOn: $coordinator.showsDemoActivity)
            }
            Section {
                Button("Restaurar todos os ajustes…", role: .destructive) { confirmsReset = true }
            }
        }
        .formStyle(.grouped)
        .confirmationDialog("Voltar todos os ajustes ao padrão?", isPresented: $confirmsReset) {
            Button("Restaurar", role: .destructive) { Preferences.reset() }
        }
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

// MARK: - Aparência

private struct AppearanceSettings: View {
    @AppStorage(SettingsKey.glassIsland) private var glassIsland = true
    @AppStorage(SettingsKey.glassDarkness) private var glassDarkness = 0.25
    @AppStorage(SettingsKey.pillWidthAdjustment) private var pillWidth = 0.0
    @AppStorage(SettingsKey.pillHeightAdjustment) private var pillHeight = 0.0

    var body: some View {
        Form {
            Section {
                GlassPreview(darkness: glassDarkness, isGlass: glassIsland)
                    .frame(height: 150)
                    .listRowInsets(EdgeInsets())
            }
            Section("Liquid Glass") {
                Toggle("Liquid Glass na ilha aberta", isOn: $glassIsland)
                LabeledContent("Vidro") {
                    HStack {
                        Text("Claro").foregroundStyle(.secondary)
                        Slider(value: $glassDarkness, in: 0...1)
                        Text("Escuro").foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: 300)
                }
                .disabled(!glassIsland)
            }
            Section {
                LabeledContent("Largura") {
                    Slider(value: $pillWidth, in: -40...60, step: 2) {
                        EmptyView()
                    } minimumValueLabel: {
                        Text("−").foregroundStyle(.secondary)
                    } maximumValueLabel: {
                        Text("+").foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: 300)
                }
                LabeledContent("Altura") {
                    Slider(value: $pillHeight, in: -6...8, step: 1) {
                        EmptyView()
                    } minimumValueLabel: {
                        Text("−").foregroundStyle(.secondary)
                    } maximumValueLabel: {
                        Text("+").foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: 300)
                }
                Button("Tamanho padrão") {
                    pillWidth = 0
                    pillHeight = 0
                }
                .disabled(pillWidth == 0 && pillHeight == 0)
            } header: {
                Text("Ilha fechada")
            } footer: {
                Text("Ajuste fino da pílula que fica sempre visível, em pontos: \(Int(pillWidth)) de largura, \(Int(pillHeight)) de altura.")
            }
        }
        .formStyle(.grouped)
    }
}

/// Uma miniatura da ilha aberta sobre um fundo colorido, para ver o vidro mudar ao vivo.
private struct GlassPreview: View {
    let darkness: Double
    let isGlass: Bool

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [.purple, .blue, .teal, .orange],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            HStack(spacing: 18) {
                ForEach(0..<5) { index in
                    Circle()
                        .fill(Color.white.opacity(0.35))
                        .frame(width: 26 + CGFloat(index % 3) * 14)
                }
            }
            .offset(y: 70)
            let shape = NotchShape(earRadius: 10, bottomRadius: 26)
            ZStack(alignment: .top) {
                if isGlass {
                    Color.clear.glassEffect(.clear.tint(Color.black.opacity(0.06 + 0.6 * darkness)), in: shape)
                    LinearGradient(colors: [.black, .black.opacity(0)], startPoint: .top, endPoint: .bottom)
                        .frame(height: 26)
                } else {
                    Color.black
                }
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 8).fill(.pink.gradient).frame(width: 36, height: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Música").font(.system(size: 12, weight: .bold))
                        Text("Artista").font(.system(size: 10)).foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                    Image(systemName: "pause.fill").font(.system(size: 16))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
                .padding(.top, 34)
            }
            .frame(width: 300, height: 100)
            .clipShape(shape)
            .overlay(shape.stroke(Color.white.opacity(isGlass ? 0.25 : 0), lineWidth: 1))
            .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
        }
        .clipped()
        .animation(.smooth, value: darkness)
        .animation(.smooth, value: isGlass)
        .fontDesign(.rounded)
    }
}

// MARK: - Mídia

private struct MediaSettings: View {
    @AppStorage(SettingsKey.matchSongColor) private var matchSongColor = true

    var body: some View {
        Form {
            Section {
                LabeledContent("Players", value: "Apple Music e Spotify")
                Toggle("Volume na cor da música", isOn: $matchSongColor)
            } footer: {
                Text("Na primeira vez que tocar algo, o macOS pede para o Canopy controlar o player. Se negar, libere em Ajustes do Sistema › Privacidade e Segurança › Automação. Favoritar só funciona no Apple Music.")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Sobreposições

private struct BatterySettings: View {
    @AppStorage(SettingsKey.batteryAlerts) private var batteryAlerts = true

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    BatteryGlyph(percent: 64, isCharging: true, tint: .green, width: 120, isLive: true)
                        .shadow(color: .green.opacity(0.5), radius: 12)
                        .padding(.vertical, 18)
                    Spacer()
                }
                .background(Color.black, in: RoundedRectangle(cornerRadius: 12))
            }
            Section {
                Toggle("Avisar ao ligar e desligar o carregador", isOn: $batteryAlerts)
            } footer: {
                Text("Mostra também quando a bateria chega a 10%.")
            }
        }
        .formStyle(.grouped)
    }
}

private struct AudioSettings: View {
    @AppStorage(SettingsKey.volumeHUD) private var volumeHUD = true
    @AppStorage(SettingsKey.outputAlerts) private var outputAlerts = true

    var body: some View {
        Form {
            Section {
                Toggle("Mostrar o volume na ilha", isOn: $volumeHUD)
                Toggle("Avisar quando a saída de áudio mudar", isOn: $outputAlerts)
            } footer: {
                Text("Ao conectar AirPods, fones ou um monitor, a ilha mostra o aparelho novo com o ícone dele.")
            }
        }
        .formStyle(.grouped)
    }
}

private struct CalendarSettings: View {
    @Environment(CalendarMonitor.self) private var calendar
    @AppStorage(SettingsKey.calendarEnabled) private var calendarEnabled = true
    @AppStorage(SettingsKey.meetingAlerts) private var meetingAlerts = true

    var body: some View {
        Form {
            Section {
                Toggle("Mostrar os próximos eventos", isOn: $calendarEnabled)
                Toggle("Avisar 5 minutos antes de cada evento", isOn: $meetingAlerts)
                    .disabled(!calendarEnabled)
            } footer: {
                Text("Se o evento tiver link do Zoom, Meet, Teams ou FaceTime, a ilha mostra o botão Entrar.")
            }
            Section("Acesso") {
                LabeledContent("Agenda") {
                    switch calendar.access {
                    case .granted:
                        Text("Permitido").foregroundStyle(.green)
                    case .denied:
                        Button("Abrir Ajustes do Sistema", action: calendar.openPrivacySettings)
                    case .notDetermined:
                        Button("Permitir acesso", action: calendar.requestAccess)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onChange(of: calendarEnabled) { calendar.refresh() }
        .onChange(of: meetingAlerts) { calendar.refresh() }
    }
}

private struct WeatherSettings: View {
    @Environment(WeatherService.self) private var weather
    @AppStorage(SettingsKey.weatherEnabled) private var weatherEnabled = true
    @AppStorage(SettingsKey.preciseLocation) private var preciseLocation = false
    @AppStorage(SettingsKey.fahrenheit) private var fahrenheit = false

    var body: some View {
        Form {
            Section {
                Toggle("Página do clima na ilha", isOn: $weatherEnabled)
                Toggle("Localização precisa", isOn: $preciseLocation)
                    .disabled(!weatherEnabled)
                Picker("Unidade", selection: $fahrenheit) {
                    Text("Celsius").tag(false)
                    Text("Fahrenheit").tag(true)
                }
                .pickerStyle(.segmented)
                .disabled(!weatherEnabled)
            } footer: {
                Text("Sem a localização precisa, a cidade vem da sua conexão de internet e o macOS não pede permissão. A previsão é do Open-Meteo.")
            }
            Section("Agora") {
                LabeledContent(weather.city ?? "Sua região") {
                    if let forecast = weather.forecast {
                        Label(
                            "\(WeatherService.degrees(forecast.temperature)) · \(forecast.condition.description)",
                            systemImage: forecast.condition.symbol
                        )
                        .symbolRenderingMode(.multicolor)
                    } else if weather.isLoading {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Sem dados").foregroundStyle(.secondary)
                    }
                }
                Button("Atualizar agora", action: weather.refresh)
                    .disabled(!weatherEnabled || weather.isLoading)
            }
        }
        .formStyle(.grouped)
        .onChange(of: preciseLocation) { weather.refresh() }
    }
}

private struct TimerSettings: View {
    @AppStorage(SettingsKey.timerSound) private var timerSound = true

    var body: some View {
        Form {
            Section {
                Toggle("Tocar som quando o timer terminar", isOn: $timerSound)
            } footer: {
                Text("Comece um timer pela página do timer na ilha aberta ou pelo menu do Canopy na barra de menus.")
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
