import CanopyCore
import Foundation
import IOBluetooth
import Observation

/// Os AirPods que acabaram de conectar: nome, modelo e bateria.
struct AirPodsStatus: Equatable {
    var name: String
    var model: AirPodsModel
    var battery = AirPodsBattery()
}

/// Avisa quando AirPods ou Beats conectam ao Mac e lê a bateria dos fones e do estojo.
///
/// Só trabalha quando o Bluetooth avisa de uma conexão. A bateria chega alguns segundos
/// depois da conexão, então é lida de novo poucas vezes, com pausas cada vez maiores, e para.
@MainActor
@Observable
final class AirPodsMonitor {
    /// Os últimos AirPods conectados. A atividade da ilha lê daqui para a bateria aparecer quando chegar.
    private(set) var status: AirPodsStatus?
    @ObservationIgnored var onConnect: ((AirPodsStatus) -> Void)?
    /// Quando os últimos AirPods conectaram, para o aviso de saída de áudio não repetir o mesmo fone.
    @ObservationIgnored private(set) var connectedAt: Date?

    @ObservationIgnored private var notification: IOBluetoothUserNotification?
    @ObservationIgnored private var receiver: ConnectReceiver?
    /// Ao registrar, o Bluetooth avisa de novo de tudo que já estava conectado. Esses não são novidade.
    @ObservationIgnored private var alreadyConnected: Set<String> = []
    @ObservationIgnored private var lastConnection: (address: String, date: Date)?
    @ObservationIgnored private var batteryTask: Task<Void, Never>?
    @ObservationIgnored private var device: IOBluetoothDevice?

    /// Depois da conexão, quando ler a bateria de novo, em segundos desde a leitura anterior.
    private static let batteryRetries: [Double] = [0.8, 1.5, 3, 5]

    func setEnabled(_ enabled: Bool) {
        if enabled {
            start()
        } else {
            stop()
        }
    }

    private func start() {
        guard notification == nil else { return }
        let devices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? []
        alreadyConnected = Set(devices.filter { $0.isConnected() }.compactMap(\.addressString))
        // O aviso pode chegar numa fila do próprio Bluetooth, fora da thread principal.
        // Só o endereço atravessa; o aparelho é buscado de novo do lado de cá.
        let receiver = ConnectReceiver { [weak self] address in
            Task { @MainActor in self?.deviceConnected(address: address) }
        }
        self.receiver = receiver
        notification = IOBluetoothDevice.register(forConnectNotifications: receiver, selector: #selector(ConnectReceiver.connected(_:device:)))
        // Os avisos repetidos chegam logo; depois disso, uma conexão é sempre nova.
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            self?.alreadyConnected = []
        }
    }

    private func stop() {
        notification?.unregister()
        notification = nil
        receiver = nil
        batteryTask?.cancel()
        batteryTask = nil
        device = nil
    }

    private func deviceConnected(address: String) {
        if alreadyConnected.remove(address) != nil { return }
        let found: IOBluetoothDevice? = IOBluetoothDevice(addressString: address)
        guard let device = found, let model = Self.model(of: device) else { return }
        // Os AirPods às vezes conectam duas vezes seguidas, um perfil de cada vez.
        if let lastConnection, lastConnection.address == address, Date.now.timeIntervalSince(lastConnection.date) < 10 { return }
        lastConnection = (address, .now)
        connectedAt = .now

        self.device = device
        let status = AirPodsStatus(name: device.name ?? model.displayName, model: model, battery: Self.battery(of: device))
        if self.status != status { self.status = status }
        onConnect?(status)
        readBatteryUntilComplete()
    }

    private func readBatteryUntilComplete() {
        batteryTask?.cancel()
        batteryTask = Task { [weak self] in
            for delay in Self.batteryRetries {
                guard let self, self.status?.battery.isComplete == false else { return }
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled, let device = self.device else { return }
                let battery = Self.battery(of: device)
                if !battery.isEmpty, self.status?.battery != battery { self.status?.battery = battery }
            }
        }
    }

    // MARK: - Bluetooth

    private static let appleVendorID = 0x004C
    /// Classe maior "áudio/vídeo" do Bluetooth: fones e caixas. Teclados e mouses da Apple ficam de fora.
    private static let audioMajorClass = 0x04

    /// O modelo, se o aparelho for AirPods ou Beats; nil para qualquer outra coisa.
    private static func model(of device: IOBluetoothDevice) -> AirPodsModel? {
        let name = device.name ?? ""
        let isApple = number(device, "vendorID") == appleVendorID
        let isAudio = Int(device.deviceClassMajor) == audioMajorClass
        guard isAudio, isApple || AirPodsModel.looksLikeAirPods(name: name) else { return nil }
        if let productID = number(device, "productID"), let model = AirPodsModel(productID: productID) {
            return model
        }
        return AirPodsModel(name: name)
    }

    private static func battery(of device: IOBluetoothDevice) -> AirPodsBattery {
        AirPodsBattery(
            left: number(device, "batteryPercentLeft"),
            right: number(device, "batteryPercentRight"),
            chargingCase: number(device, "batteryPercentCase"),
            single: number(device, "batteryPercentSingle")
        )
    }

    /// Lê uma propriedade que o IOBluetooth tem mas não publica. Perguntar antes evita
    /// a exceção do KVC se uma versão do macOS tirar a propriedade.
    private static func number(_ device: IOBluetoothDevice, _ key: String) -> Int? {
        guard device.responds(to: NSSelectorFromString(key)) else { return nil }
        return (device.value(forKey: key) as? NSNumber)?.intValue
    }
}

/// Recebe o aviso do IOBluetooth, que chama um seletor do Objective-C, e passa adiante
/// só o endereço do aparelho. Não pertence à thread principal: o Bluetooth chama de onde quiser.
private final class ConnectReceiver: NSObject {
    private let handler: @Sendable (String) -> Void

    init(handler: @escaping @Sendable (String) -> Void) {
        self.handler = handler
    }

    @objc func connected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        guard let address = device.addressString else { return }
        handler(address)
    }
}

#if BENCHMARK
extension AirPodsMonitor {
    /// AirPods Pro de mentira, com a bateria já lida, para medir a ilha sem fone por perto.
    func simulateConnection() -> AirPodsStatus {
        let status = AirPodsStatus(
            name: "AirPods Pro de Pedro",
            model: .airPodsPro,
            battery: AirPodsBattery(left: 86, right: 84, chargingCase: 52)
        )
        self.status = status
        return status
    }
}
#endif
