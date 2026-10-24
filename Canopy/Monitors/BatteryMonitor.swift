import CanopyCore
import Foundation
import IOKit.ps
import Observation

/// Acompanha a bateria pelos avisos do macOS e conta quando o carregador é ligado ou desligado
/// e quando a bateria fica fraca. Nada é lido de tempos em tempos.
@MainActor
@Observable
final class BatteryMonitor {
    /// A última leitura da bateria interna; nil em Macs sem bateria.
    private(set) var snapshot: BatterySnapshot?

    @ObservationIgnored var onEvent: ((BatteryEvent, BatterySnapshot) -> Void)?
    @ObservationIgnored private var source: CFRunLoopSource?

    func start() {
        snapshot = Self.read()
        let context = Unmanaged.passUnretained(self).toOpaque()
        let callback: IOPowerSourceCallbackType = { context in
            guard let context else { return }
            let monitor = Unmanaged<BatteryMonitor>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { monitor.update() }
        }
        guard let source = IOPSNotificationCreateRunLoopSource(callback, context)?.takeRetainedValue() else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        self.source = source
    }

    private func update() {
        guard let fresh = Self.read() else { return }
        let previous = snapshot
        // O macOS avisa também mudanças que não aparecem aqui, como a temperatura da bateria.
        guard fresh != previous else { return }
        snapshot = fresh
        if let event = BatteryEvent.between(previous, fresh) {
            onEvent?(event, fresh)
        }
    }

    /// Minutos até a carga completa, se o macOS já tiver a estimativa.
    static func minutesToFull() -> Int? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                  let minutes = description[kIOPSTimeToFullChargeKey] as? Int, minutes > 0
            else { continue }
            return minutes
        }
        return nil
    }

    /// Lê a bateria interna. Devolve nil em Macs sem bateria.
    static func read() -> BatterySnapshot? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType
            else { continue }
            let current = description[kIOPSCurrentCapacityKey] as? Int ?? 0
            let maximum = description[kIOPSMaxCapacityKey] as? Int ?? 100
            return BatterySnapshot(
                percent: maximum > 0 ? current * 100 / maximum : current,
                isCharging: description[kIOPSIsChargingKey] as? Bool ?? false,
                isPluggedIn: description[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
            )
        }
        return nil
    }
}
