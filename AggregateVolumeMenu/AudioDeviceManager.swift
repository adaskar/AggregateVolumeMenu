//
//  AudioDeviceManager.swift
//  AggregateVolumeMenu
//
//  Created by Gurhan Polat on 22.12.2020.
//

import Foundation
import CoreAudio

/// Helper to create a FourCharCode from a 4-character String.
private func fourCharCode(fromString string: String) -> FourCharCode {
    assert(string.count == 4, "FourCharCode string must be exactly 4 characters long")
    var result: FourCharCode = 0
    for char in string.utf8 {
        result = (result << 8) + FourCharCode(char)
    }
    return result
}

let kAudioHardwareServiceDeviceProperty_VirtualMainVolume = AudioObjectPropertySelector(fourCharCode(fromString: "vvol"))

class AudioDeviceManager: ObservableObject {
    static let shared = AudioDeviceManager()
    
    @Published var outputDevices: [AudioDevice] = []
    @Published var currentDevice: AudioDevice?
    @Published var currentVolume: Float = 0.0
    @Published var isMuted: Bool = false
    
    private init() {
        refreshDevices()
        refreshCurrentDevice()
    }
    
    static func getVolumeIcon(for volume: Float, isMuted: Bool) -> String {
        if isMuted || volume == 0 {
            return "speaker.slash.fill"
        }
        
        switch volume {
        case 0..<0.33:
            return "speaker.wave.1.fill"
        case 0.33..<0.66:
            return "speaker.wave.2.fill"
        case 0.66...1.0:
            return "speaker.wave.3.fill"
        default:
            return "speaker.wave.2.fill"
        }
    }
    
    func refreshDevices() {
        outputDevices = getOutputDevices()
    }
    
    func refreshCurrentDevice() {
        currentDevice = getDefaultOutputDevice()
        if let device = currentDevice {
            currentVolume = getVolume(for: device) ?? 0.0
            isMuted = getMute(for: device) ?? false
        }
    }
    
    func selectDevice(_ device: AudioDevice) {
        setDefaultOutputDevice(device)
        currentDevice = device
        currentVolume = getVolume(for: device) ?? 0.0
        isMuted = getMute(for: device) ?? false
    }
    
    func setCurrentVolume(_ volume: Float) {
        guard let device = currentDevice else { return }
        currentVolume = max(0, min(1, volume))
        setVolume(currentVolume, for: device)
    }
    
    func adjustVolume(by delta: Float) {
        guard let device = currentDevice else { return }
        let newVolume = max(0, min(1, currentVolume + delta))
        currentVolume = newVolume
        setVolume(newVolume, for: device)
    }
    
    func toggleMute() {
        guard let device = currentDevice else { return }
        isMuted.toggle()
        setMute(isMuted, for: device)
    }
    
    private func getOutputDevices() -> [AudioDevice] {
        var devices = [AudioDevice]()
        
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        
        var propsize: UInt32 = 0
        var result = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propsize)
        if result != noErr {
            print("Error: Could not get size of device list. Result: \(result)")
            return []
        }
        
        let deviceCount = Int(propsize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        
        result = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propsize, &deviceIDs)
        if result != noErr {
            print("Error: Could not get device list. Result: \(result)")
            return []
        }
        
        for deviceID in deviceIDs {
            // Check if the device has output channels
            var streamAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain)
            
            var streamPropsize: UInt32 = 0
            result = AudioObjectGetPropertyDataSize(deviceID, &streamAddress, 0, nil, &streamPropsize)
            if result != noErr || streamPropsize == 0 {
                continue // Not an output device
            }
            
            // Get device name
            var name: CFString = "" as CFString
            var nameAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceNameCFString,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain)
            var nameSize = UInt32(MemoryLayout<CFString>.size)
            
            result = withUnsafeMutablePointer(to: &name) { pointer in
                AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &nameSize, pointer)
            }
            
            if result == noErr {
                devices.append(AudioDevice(id: deviceID, name: name as String))
            }
        }
        return devices
    }
    
    private func getDefaultOutputDevice() -> AudioDevice? {
        var deviceID: AudioDeviceID = 0
        var propsize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        
        let result = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propsize, &deviceID)
        if result != noErr {
            return nil
        }
        
        return getOutputDevices().first { $0.id == deviceID }
    }
    
    private func setDefaultOutputDevice(_ device: AudioDevice) {
        var deviceID = device.id
        let propsize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        
        AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, propsize, &deviceID)
    }
    
    private func getVolumeForSingleDevice(deviceID: AudioDeviceID) -> Float? {
        var volume: Float = 0.0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain) // Default to master channel
        
        for channel in [0, 1, 2] { // Check Master, Left, Right
            address.mElement = UInt32(channel)
            if AudioObjectHasProperty(deviceID, &address) {
                var propsize = UInt32(MemoryLayout<Float>.size)
                let result = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &propsize, &volume)
                return result == noErr ? volume : nil
            }
        }
        return nil
    }
    
    private func getVolume(for device: AudioDevice) -> Float? {
        var volume: Float = 0.0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain)
        
        // First, try the modern 'virtual main volume' property
        if !AudioObjectHasProperty(device.id, &address) {
            // If that fails, check if it's an aggregate device
            if isAggregateDevice(deviceID: device.id) {
                let subDevices = getSubDevices(for: device.id)
                if subDevices.isEmpty { return nil }
                
                var totalVolume: Float = 0.0
                var controllableSubDeviceCount = 0
                
                for subDeviceID in subDevices {
                    if let subVolume = getVolumeForSingleDevice(deviceID: subDeviceID) {
                        totalVolume += subVolume
                        controllableSubDeviceCount += 1
                    }
                }
                
                return controllableSubDeviceCount > 0 ? (totalVolume / Float(controllableSubDeviceCount)) : nil
            } else {
                // It's a normal device, try the scalar property on channels
                return getVolumeForSingleDevice(deviceID: device.id)
            }
        }
        
        // The 'virtual main volume' property exists, so we use it
        var propsize = UInt32(MemoryLayout<Float>.size)
        let result = AudioObjectGetPropertyData(device.id, &address, 0, nil, &propsize, &volume)
        return result == noErr ? volume : nil
    }
    
    private func setVolume(_ volume: Float, for device: AudioDevice) {
        var newVolume = volume
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain)
        
        // First, try the modern 'virtual main volume' property
        if !AudioObjectHasProperty(device.id, &address) {
            // If that fails, check if it's an aggregate device
            if isAggregateDevice(deviceID: device.id) {
                let subDevices = getSubDevices(for: device.id)
                for subDeviceID in subDevices {
                    // Recursively set volume for each sub-device
                    setVolumeForSingleDevice(newVolume, for: subDeviceID)
                }
                return
            } else {
                // It's a normal device, try the scalar property on channels
                setVolumeForSingleDevice(newVolume, for: device.id)
                return
            }
        }
        
        // The 'virtual main volume' property exists, so we use it
        let propsize = UInt32(MemoryLayout<Float>.size)
        AudioObjectSetPropertyData(device.id, &address, 0, nil, propsize, &newVolume)
    }
    
    private func setVolumeForSingleDevice(_ volume: Float, for deviceID: AudioDeviceID) {
        var newVolume = volume
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyVolumeScalar, mScope: kAudioDevicePropertyScopeOutput, mElement: 0)
        let propsize = UInt32(MemoryLayout<Float>.size)
        
        for channel in [0, 1, 2] { // Set on Master, Left, and Right if they exist
            address.mElement = UInt32(channel)
            if AudioObjectHasProperty(deviceID, &address) {
                AudioObjectSetPropertyData(deviceID, &address, 0, nil, propsize, &newVolume)
            }
        }
    }
    
    private func setMute(_ isMuted: Bool, for device: AudioDevice) {
        var muteVal: UInt32 = isMuted ? 1 : 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain)
        
        if AudioObjectHasProperty(device.id, &address) {
            let propsize = UInt32(MemoryLayout<UInt32>.size)
            AudioObjectSetPropertyData(device.id, &address, 0, nil, propsize, &muteVal)
        }
    }
    
    private func getMute(for device: AudioDevice) -> Bool? {
        var muteVal: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain)
        
        if AudioObjectHasProperty(device.id, &address) {
            var propsize = UInt32(MemoryLayout<UInt32>.size)
            let result = AudioObjectGetPropertyData(device.id, &address, 0, nil, &propsize, &muteVal)
            return result == noErr ? (muteVal == 1) : nil
        }
        return nil
    }
    
    // MARK: - Aggregate Device Helpers
    
    private func isAggregateDevice(deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var transportType: UInt32 = 0
        var propsize = UInt32(MemoryLayout<UInt32>.size)
        let result = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &propsize, &transportType)
        
        return result == noErr && transportType == kAudioDeviceTransportTypeAggregate
    }
    
    private func getSubDevices(for deviceID: AudioDeviceID) -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioAggregateDevicePropertyActiveSubDeviceList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        
        var propsize: UInt32 = 0
        var result = AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &propsize)
        if result != noErr || propsize == 0 {
            return []
        }
        
        let subDeviceCount = Int(propsize) / MemoryLayout<AudioDeviceID>.size
        var subDeviceIDs = [AudioDeviceID](repeating: 0, count: subDeviceCount)
        
        result = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &propsize, &subDeviceIDs)
        if result != noErr {
            return []
        }
        
        return subDeviceIDs
    }
}
