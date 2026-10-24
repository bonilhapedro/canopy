import CanopyCore
import Foundation
import IOKit.ps

/// Avisa quando o carregador é ligado ou desligado e quando a bateria fica fraca.
@MainActor
final class BatteryMonitor {
    var onEvent: ((BatteryEvent, BatterySnapshot) -> Void)?
    private var last: BatterySnapshot?
    private var source: CFRunLoopSource?

    func start() {
        last = Self.read()
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
        guard let snapshot = Self.read() else { return }
        defer { last = snapshot }
        if let event = BatteryEvent.between(last, snapshot) {
            onEvent?(event, snapshot)
        }
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
