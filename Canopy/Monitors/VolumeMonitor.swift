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
    /// Saídas que já têm ouvinte. Voltar para uma delas não pode ligar um ouvinte repetido.
    @ObservationIgnored private var listenedDevices: Set<AudioObjectID> = []

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
        guard device != kAudioObjectUnknown, !listenedDevices.contains(device) else { return }
        listenedDevices.insert(device)
        let listened = device
        for selector in [kAudioHardwareServiceDeviceProperty_VirtualMainVolume, kAudioDevicePropertyMute] {
            var address = Self.outputAddress(selector)
            AudioObjectAddPropertyListenerBlock(listened, &address, .main) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.volumeDidChange(on: listened) }
            }
        }
    }

    /// Se a saída atual deixa mudar o volume por software. HDMI e alguns USB não deixam.
    var canSetVolume: Bool { isSettable(kAudioHardwareServiceDeviceProperty_VirtualMainVolume) }
    var canMute: Bool { isSettable(kAudioDevicePropertyMute) }

    private func isSettable(_ selector: AudioObjectPropertySelector) -> Bool {
        guard device != kAudioObjectUnknown else { return false }
        var address = Self.outputAddress(selector)
        var settable: DarwinBoolean = false
        return AudioObjectIsPropertySettable(device, &address, &settable) == noErr && settable.boolValue
    }

    /// Um passo nas teclas de volume: 1/16 da escala, ou 1/64 com Option+Shift, como no macOS.
    func step(up: Bool, fine: Bool) {
        let steps: Float = fine ? 64 : 16
        let target = ((volume * steps).rounded() + (up ? 1 : -1)) / steps
        setVolume(min(max(target, 0), 1))
        // Subir o volume tira do mudo, como no macOS.
        if up, isMuted { setMuted(false) }
    }

    func setVolume(_ value: Float) {
        var level = Float32(value)
        var address = Self.outputAddress(kAudioHardwareServiceDeviceProperty_VirtualMainVolume)
        AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &level)
        read()
    }

    func setMuted(_ muted: Bool) {
        var value: UInt32 = muted ? 1 : 0
        var address = Self.outputAddress(kAudioDevicePropertyMute)
        AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value)
        read()
    }

    /// O aviso também chega para o que o próprio Canopy mudou, e aí o valor já está aqui:
    /// só avisa a ilha quando algo mudou de fato, fora das teclas (Central de Controle, outro app).
    private func volumeDidChange(on changed: AudioObjectID) {
        // Os ouvintes de saídas antigas continuam ligados; só a saída atual conta.
        guard changed == device, read() else { return }
        onChange?()
    }

    /// Lê o volume e o mudo. Devolve se algum dos dois mudou.
    @discardableResult
    private func read() -> Bool {
        var level: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        var address = Self.outputAddress(kAudioHardwareServiceDeviceProperty_VirtualMainVolume)
        let newVolume = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &level) == noErr ? level : volume
        var muted: UInt32 = 0
        size = UInt32(MemoryLayout<UInt32>.size)
        address = Self.outputAddress(kAudioDevicePropertyMute)
        let newMuted = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &muted) == noErr && muted != 0
        guard newVolume != volume || newMuted != isMuted else { return false }
        if newVolume != volume { volume = newVolume }
        if newMuted != isMuted { isMuted = newMuted }
        return true
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
