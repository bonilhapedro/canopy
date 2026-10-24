import AppKit
import CoreGraphics
import Darwin
import Foundation
import Observation

/// Lê e muda o brilho da tela embutida do MacBook.
/// O macOS não tem API pública para isso; o Canopy usa a do DisplayServices, como o MonitorControl.
@MainActor
@Observable
final class BrightnessController {
    /// De 0 a 1.
    private(set) var brightness: Float = 0

    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private let api = BrightnessAPI.load()
    @ObservationIgnored private var pollTask: Task<Void, Never>?
    @ObservationIgnored private var wakeObservers: [NSObjectProtocol] = []
    /// Ao acordar, a tela volta do escuro para o brilho de antes; isso não é o usuário mexendo.
    @ObservationIgnored private var quietUntil = Date.distantPast

    var isAvailable: Bool { api != nil && Self.builtInDisplay() != nil }

    func start() {
        brightness = read() ?? 0
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.screensDidWakeNotification, NSWorkspace.didWakeNotification] {
            wakeObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.quietUntil = .now.addingTimeInterval(3) }
            })
        }
        // Mudanças feitas fora das teclas (Central de Controle, Touch Bar) só aparecem lendo de tempos em tempos.
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                self?.poll()
            }
        }
    }

    /// Um passo nas teclas de brilho: 1/16 da escala, ou 1/64 com Option+Shift, como no macOS.
    func step(up: Bool, fine: Bool) {
        guard let current = read() else { return }
        let steps: Float = fine ? 64 : 16
        let target = ((current * steps).rounded() + (up ? 1 : -1)) / steps
        set(min(max(target, 0), 1))
    }

    func set(_ value: Float) {
        guard let api, let display = Self.builtInDisplay() else { return }
        api.set(display, value)
        brightness = value
        onChange?()
    }

    private func poll() {
        guard let value = read() else { return }
        let delta = abs(value - brightness)
        guard delta > 0.001 else { return }
        brightness = value
        // O sensor de luz ambiente mexe aos pouquinhos; isso não merece aviso na ilha.
        if delta >= 0.03, Date.now >= quietUntil { onChange?() }
    }

    private func read() -> Float? {
        guard let api, let display = Self.builtInDisplay() else { return nil }
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

/// As funções privadas de brilho, carregadas na hora: DisplayServices e, de reserva, CoreDisplay.
private struct BrightnessAPI {
    let get: (CGDirectDisplayID) -> Float?
    let set: (CGDirectDisplayID, Float) -> Void

    private typealias DisplayServicesGet = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias DisplayServicesSet = @convention(c) (CGDirectDisplayID, Float) -> Int32
    private typealias CoreDisplayGet = @convention(c) (CGDirectDisplayID) -> Double
    private typealias CoreDisplaySet = @convention(c) (CGDirectDisplayID, Double) -> Void

    static func load() -> BrightnessAPI? {
        if let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY),
           let getSymbol = dlsym(handle, "DisplayServicesGetBrightness"),
           let setSymbol = dlsym(handle, "DisplayServicesSetBrightness") {
            let getBrightness = unsafeBitCast(getSymbol, to: DisplayServicesGet.self)
            let setBrightness = unsafeBitCast(setSymbol, to: DisplayServicesSet.self)
            return BrightnessAPI(
                get: { display in
                    var value: Float = 0
                    return getBrightness(display, &value) == 0 ? value : nil
                },
                set: { display, value in _ = setBrightness(display, value) }
            )
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
