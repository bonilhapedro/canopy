import AppKit
import CoreGraphics
import Darwin
import Foundation
import Observation

/// Lê e muda o brilho da tela embutida do MacBook.
/// O macOS não tem API pública para isso; o Canopy usa a do DisplayServices, como o MonitorControl e o Lunar.
@MainActor
@Observable
final class BrightnessController {
    /// De 0 a 1.
    private(set) var brightness: Float = 0

    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private let api = BrightnessAPI.load()
    @ObservationIgnored private var display: CGDirectDisplayID?
    @ObservationIgnored private var wakeObservers: [NSObjectProtocol] = []
    /// Ao acordar, a tela volta do escuro para o brilho de antes; isso não é o usuário mexendo.
    @ObservationIgnored private var quietUntil = Date.distantPast
    /// Começo da rajada de mudanças atual e o brilho de antes dela.
    @ObservationIgnored private var burst: (start: Date, origin: Float)?

    /// Quem recebe os avisos do DisplayServices, que chegam numa função C sem contexto.
    fileprivate static weak var current: BrightnessController?

    var isAvailable: Bool { api != nil && display != nil }

    func start() {
        Self.current = self
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.screensDidWakeNotification, NSWorkspace.didWakeNotification] {
            wakeObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.quietUntil = .now.addingTimeInterval(3) }
            })
        }
        bindToBuiltInDisplay()
    }

    /// Monitor ligado ou desligado, tampa fechada ou aberta: a tela embutida pode ter mudado.
    func displaysChanged() {
        bindToBuiltInDisplay()
    }

    /// Um passo nas teclas de brilho: 1/16 da escala, ou 1/64 com Option+Shift, como no macOS.
    func step(up: Bool, fine: Bool) {
        guard let current = read() else { return }
        let steps: Float = fine ? 64 : 16
        let target = ((current * steps).rounded() + (up ? 1 : -1)) / steps
        set(min(max(target, 0), 1))
    }

    func set(_ value: Float) {
        guard let api, let display else { return }
        api.set(display, value)
        brightness = value
        onChange?()
    }

    /// Mudanças feitas fora das teclas (Central de Controle, Touch Bar, sensor de luz) chegam por aviso
    /// do macOS, sem precisar ler o brilho de tempos em tempos.
    private func bindToBuiltInDisplay() {
        let builtIn = Self.builtInDisplay()
        guard builtIn != display else { return }
        if let display { api?.stopObserving(display) }
        display = builtIn
        guard let api, let builtIn else { return }
        if let value = api.get(builtIn) { brightness = value }
        api.observe(builtIn)
    }

    fileprivate func changed(to notified: Float?) {
        guard let value = notified ?? read() else { return }
        let delta = abs(value - brightness)
        // O brilho que o próprio Canopy pôs também é avisado; esse já está aqui.
        guard delta > 0.001 else { return }
        let now = Date.now
        // Arrastar o controle ou segurar a tecla manda várias mudanças seguidas: elas contam juntas.
        let origin: Float
        if let burst, now.timeIntervalSince(burst.start) < 0.3 {
            origin = burst.origin
        } else {
            origin = brightness
            burst = (now, brightness)
        }
        brightness = value
        // O sensor de luz ambiente mexe aos pouquinhos; isso não merece aviso na ilha.
        if abs(value - origin) >= 0.03, now >= quietUntil { onChange?() }
    }

    private func read() -> Float? {
        guard let api, let display else { return nil }
        return api.get(display)
    }

    private static func builtInDisplay() -> CGDirectDisplayID? {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return nil }
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &displays, &count) == .success else { return nil }
        return displays.first { CGDisplayIsBuiltin($0) != 0 }
    }
}

/// Chamada pelo DisplayServices a cada mudança de brilho. É uma função solta porque a API só aceita
/// um ponteiro de função C. Pode chegar fora da main thread, então só leva o valor até ela.
private func brightnessDidChange(
    center: CFNotificationCenter?,
    observer: UnsafeMutableRawPointer?,
    name: CFNotificationName?,
    object: UnsafeRawPointer?,
    userInfo: CFDictionary?
) {
    let value = ((userInfo as NSDictionary?)?["value"] as? NSNumber)?.floatValue
    DispatchQueue.main.async {
        MainActor.assumeIsolated { BrightnessController.current?.changed(to: value) }
    }
}

/// As funções privadas de brilho, carregadas na hora: DisplayServices e, de reserva, CoreDisplay.
private struct BrightnessAPI {
    let get: (CGDirectDisplayID) -> Float?
    let set: (CGDirectDisplayID, Float) -> Void
    /// Pede ao macOS para avisar cada mudança de brilho. O CoreDisplay não tem isso;
    /// com ele, só as teclas aparecem na ilha.
    var observe: (CGDirectDisplayID) -> Void = { _ in }
    var stopObserving: (CGDirectDisplayID) -> Void = { _ in }

    private typealias DisplayServicesGet = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias DisplayServicesSet = @convention(c) (CGDirectDisplayID, Float) -> Int32
    private typealias DisplayServicesRegister = @convention(c) (CGDirectDisplayID, CGDirectDisplayID, CFNotificationCallback) -> Int32
    private typealias DisplayServicesUnregister = @convention(c) (CGDirectDisplayID, CGDirectDisplayID) -> Int32
    private typealias CoreDisplayGet = @convention(c) (CGDirectDisplayID) -> Double
    private typealias CoreDisplaySet = @convention(c) (CGDirectDisplayID, Double) -> Void

    static func load() -> BrightnessAPI? {
        if let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY),
           let getSymbol = dlsym(handle, "DisplayServicesGetBrightness"),
           let setSymbol = dlsym(handle, "DisplayServicesSetBrightness") {
            let getBrightness = unsafeBitCast(getSymbol, to: DisplayServicesGet.self)
            let setBrightness = unsafeBitCast(setSymbol, to: DisplayServicesSet.self)
            var api = BrightnessAPI(
                get: { display in
                    var value: Float = 0
                    return getBrightness(display, &value) == 0 ? value : nil
                },
                set: { display, value in _ = setBrightness(display, value) }
            )
            if let registerSymbol = dlsym(handle, "DisplayServicesRegisterForBrightnessChangeNotifications"),
               let unregisterSymbol = dlsym(handle, "DisplayServicesUnregisterForBrightnessChangeNotifications") {
                let register = unsafeBitCast(registerSymbol, to: DisplayServicesRegister.self)
                let unregister = unsafeBitCast(unregisterSymbol, to: DisplayServicesUnregister.self)
                // A própria tela é o "observador"; o aviso volta com ela no lugar do ponteiro.
                api.observe = { display in _ = register(display, display, brightnessDidChange) }
                api.stopObserving = { display in _ = unregister(display, display) }
            }
            return api
        }
        if let handle = dlopen("/System/Library/Frameworks/CoreDisplay.framework/CoreDisplay", RTLD_LAZY),
           let getSymbol = dlsym(handle, "CoreDisplay_Display_GetUserBrightness"),
           let setSymbol = dlsym(handle, "CoreDisplay_Display_SetUserBrightness") {
            let getBrightness = unsafeBitCast(getSymbol, to: CoreDisplayGet.self)
            let setBrightness = unsafeBitCast(setSymbol, to: CoreDisplaySet.self)
            return BrightnessAPI(
                get: { display in Float(getBrightness(display)) },
                set: { display, value in setBrightness(display, Double(value)) }
            )
        }
        return nil
    }
}
