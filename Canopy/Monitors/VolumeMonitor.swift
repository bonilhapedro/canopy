import AudioToolbox
import CoreAudio
import Foundation
import Observation

/// Lê o volume da saída de áudio atual e avisa quando ele muda.
@MainActor
@Observable
final class VolumeMonitor {
    /// De 0 a 1.
    private(set) var volume: Float = 0
    private(set) var isMuted = false

    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private var device = AudioObjectID(kAudioObjectUnknown)

    func start() {
        // Fones conectados ou desconectados trocam a saída padrão.
        var defaultDevice = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &defaultDevice, .main) { [weak self] _, _ in
            MainActor.assumeIsolated { self?.bindToDefaultDevice() }
        }
        bindToDefaultDevice()
    }

    private func bindToDefaultDevice() {
        device = Self.defaultOutputDevice()
        read()
        guard device != kAudioObjectUnknown else { return }
        for selector in [kAudioHardwareServiceDeviceProperty_VirtualMainVolume, kAudioDevicePropertyMute] {
            var address = Self.outputAddress(selector)
            AudioObjectAddPropertyListenerBlock(device, &address, .main) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.volumeDidChange() }
            }
        }
    }

    private func volumeDidChange() {
        read()
        onChange?()
    }

    private func read() {
        var level: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        var address = Self.outputAddress(kAudioHardwareServiceDeviceProperty_VirtualMainVolume)
        if AudioObjectGetPropertyData(device, &address, 0, nil, &size, &level) == noErr {
            volume = level
        }
        var muted: UInt32 = 0
        size = UInt32(MemoryLayout<UInt32>.size)
        address = Self.outputAddress(kAudioDevicePropertyMute)
        isMuted = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &muted) == noErr && muted != 0
    }

    private static func outputAddress(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private static func defaultOutputDevice() -> AudioObjectID {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var device = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device)
        return device
    }
}
