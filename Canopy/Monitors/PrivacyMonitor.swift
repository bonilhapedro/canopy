import AppKit
import CoreAudio
import CoreMediaIO
import Foundation
import Observation

/// Descobre se algum app está usando o microfone ou a câmera.
/// O CoreAudio e o CoreMediaIO avisam cada mudança, então nada é lido de tempos em tempos.
@MainActor
@Observable
final class PrivacyMonitor {
    private(set) var isMicrophoneInUse = false
    private(set) var isCameraInUse = false

    var isAnyInUse: Bool { isMicrophoneInUse || isCameraInUse }

    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private var microphone = AudioObjectID(kAudioObjectUnknown)
    /// Microfones e câmeras que já têm ouvinte, para não ligar outro repetido.
    @ObservationIgnored private var listenedMicrophones: Set<AudioObjectID> = []
    @ObservationIgnored private var listenedCameras: Set<CMIOObjectID> = []
    @ObservationIgnored private var wakeObserver: NSObjectProtocol?
    #if BENCHMARK
    @ObservationIgnored private var isSimulating = false
    #endif

    func start() {
        // O microfone padrão muda ao conectar um fone com microfone.
        var defaultInput = Self.address(kAudioHardwarePropertyDefaultInputDevice, scope: kAudioObjectPropertyScopeGlobal)
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &defaultInput, .main) { [weak self] _, _ in
            MainActor.assumeIsolated { self?.bindToDefaultMicrophone() }
        }
        // Câmeras entram e saem (iPhone como câmera, webcam USB).
        var devices = Self.cameraAddress(kCMIOHardwarePropertyDevices)
        CMIOObjectAddPropertyListenerBlock(CMIOObjectID(kCMIOObjectSystemObject), &devices, .main) { [weak self] _, _ in
            MainActor.assumeIsolated { self?.bindToCameras() }
        }
        // Depois de dormir, confere uma vez: um app pode ter soltado a câmera enquanto isso.
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        bindToDefaultMicrophone()
        bindToCameras()
    }

    #if BENCHMARK
    /// Microfone "em uso" sem gravar nada, para medir a ilha nesse estado.
    func simulateMicrophone() {
        isSimulating = true
        isMicrophoneInUse = true
        onChange?()
    }
    #endif

    private func bindToDefaultMicrophone() {
        var address = Self.address(kAudioHardwarePropertyDefaultInputDevice, scope: kAudioObjectPropertyScopeGlobal)
        var device = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device)
        microphone = device
        if device != kAudioObjectUnknown, !listenedMicrophones.contains(device) {
            listenedMicrophones.insert(device)
            var running = Self.address(kAudioDevicePropertyDeviceIsRunningSomewhere, scope: kAudioObjectPropertyScopeGlobal)
            AudioObjectAddPropertyListenerBlock(device, &running, .main) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
        }
        refresh()
    }

    private func bindToCameras() {
        let cameras = Self.cameras()
        // Câmera desconectada leva o ouvinte junto; o número dela pode voltar num aparelho novo.
        listenedCameras.formIntersection(cameras)
        for camera in cameras where !listenedCameras.contains(camera) {
            listenedCameras.insert(camera)
            var running = Self.cameraAddress(kCMIODevicePropertyDeviceIsRunningSomewhere)
            CMIOObjectAddPropertyListenerBlock(camera, &running, .main) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
        }
        refresh()
    }

    private func refresh() {
        #if BENCHMARK
        if isSimulating { return }
        #endif
        let microphoneInUse = Self.isRunning(microphone)
        let cameraInUse = Self.cameras().contains(where: Self.isRunning(camera:))
        guard microphoneInUse != isMicrophoneInUse || cameraInUse != isCameraInUse else { return }
        isMicrophoneInUse = microphoneInUse
        isCameraInUse = cameraInUse
        onChange?()
    }

    // MARK: - CoreAudio e CoreMediaIO

    private static func address(_ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    private static func cameraAddress(_ selector: some BinaryInteger) -> CMIOObjectPropertyAddress {
        CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(selector),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
    }

    private static func isRunning(_ device: AudioObjectID) -> Bool {
        guard device != kAudioObjectUnknown else { return false }
        var address = address(kAudioDevicePropertyDeviceIsRunningSomewhere, scope: kAudioObjectPropertyScopeGlobal)
        var running: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &running) == noErr else { return false }
        return running != 0
    }

    private static func cameras() -> [CMIOObjectID] {
        var address = cameraAddress(kCMIOHardwarePropertyDevices)
        let system = CMIOObjectID(kCMIOObjectSystemObject)
        var size: UInt32 = 0
        guard CMIOObjectGetPropertyDataSize(system, &address, 0, nil, &size) == 0, size > 0 else { return [] }
        var devices = [CMIOObjectID](repeating: 0, count: Int(size) / MemoryLayout<CMIOObjectID>.size)
        var used: UInt32 = 0
        guard CMIOObjectGetPropertyData(system, &address, 0, nil, size, &used, &devices) == 0 else { return [] }
        return devices
    }

    private static func isRunning(camera: CMIOObjectID) -> Bool {
        var address = cameraAddress(kCMIODevicePropertyDeviceIsRunningSomewhere)
        var value: UInt32 = 0
        var used: UInt32 = 0
        let status = CMIOObjectGetPropertyData(camera, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &used, &value)
        return status == 0 && value != 0
    }
}
