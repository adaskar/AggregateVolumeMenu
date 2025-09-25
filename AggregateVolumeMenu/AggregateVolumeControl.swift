//
//  AggregateVolumeControl.swift
//  AggregateVolumeMenu
//
//  Created by Gurhan Polat on 21.12.2020.
//
import Foundation
import Cocoa
import AVFoundation

class AggregateVolumeControl {
    var address:AudioObjectPropertyAddress = AudioObjectPropertyAddress();
    var propsize:UInt32 = 0;
    var result:OSStatus = 0;
    var audioDeviceID: AudioDeviceID = 0;
    var subDeviceCount:Int = 0;
    var subDevicesID = [AudioDeviceID]()
    
    init() {
        // Get default audio output device
        address = AudioObjectPropertyAddress(
            mSelector:AudioObjectPropertySelector(kAudioHardwarePropertyDefaultOutputDevice),
            mScope:AudioObjectPropertyScope(kAudioObjectPropertyScopeGlobal),
            mElement:AudioObjectPropertyElement(kAudioObjectPropertyElementMain))

        propsize = UInt32(MemoryLayout<AudioDeviceID>.size)
        result = AudioObjectGetPropertyData(AudioDeviceID(kAudioObjectSystemObject), &address, 0, nil, &propsize, &audioDeviceID)

        if (result != 0) {
            print("Error: Could not get default output device. Result: \(result)")
            exit(-1)
        }
    
        // Check if the device is an Aggregate Device
        address = AudioObjectPropertyAddress(
            mSelector:AudioObjectPropertySelector(kAudioDevicePropertyTransportType),
            mScope:AudioObjectPropertyScope(kAudioObjectPropertyScopeGlobal),
            mElement:AudioObjectPropertyElement(kAudioObjectPropertyElementMain))
        var transportType:UInt32 = 0
        propsize = UInt32(MemoryLayout<UInt32>.size)
        result = AudioObjectGetPropertyData(audioDeviceID, &address, 0, nil, &propsize, &transportType)

        if (result != 0) {
            print("Error: Could not get transport type. Result: \(result)")
            exit(-1)
        }

        if (transportType != kAudioDeviceTransportTypeAggregate) {
            print("This tool only works with an Aggregate Audio Device. The current default device is not an aggregate device.")
            exit(1)
        }

        // Get the sub-devices of the Aggregate Audio Device
        address = AudioObjectPropertyAddress(
            mSelector:AudioObjectPropertySelector(kAudioAggregateDevicePropertyActiveSubDeviceList),
            mScope:AudioObjectPropertyScope(kAudioObjectPropertyScopeGlobal),
            mElement:AudioObjectPropertyElement(kAudioObjectPropertyElementMain))
        
        // Pre-allocate a reasonably sized array for sub-device IDs
        subDevicesID = [AudioDeviceID](repeating: 0, count: 32)
        propsize = UInt32(MemoryLayout<AudioDeviceID>.size * subDevicesID.count)
        
        result = AudioObjectGetPropertyData(audioDeviceID, &address, 0, nil, &propsize, &subDevicesID)

        if (result != 0) {
            print("Error: Could not get sub-device list. Result: \(result)")
            exit(-1)
        }

        subDeviceCount = Int(propsize) / MemoryLayout<AudioDeviceID>.size
        subDevicesID.removeSubrange(subDeviceCount..<subDevicesID.count) // Trim the array to the actual count
        
        debugDeviceInfo()
    }
    
    func debugDeviceInfo() {
        print("=== Aggregate Device Debug Info ===")
        print("Main device ID: \(audioDeviceID)")
        print("Sub-device count: \(subDeviceCount)")
        
        for (index, subDevice) in subDevicesID.enumerated() {
            print("\nSub-device \(index): ID \(subDevice)")
            
            var deviceName: CFString = "" as CFString
            var nameAddress = AudioObjectPropertyAddress(
                mSelector: AudioObjectPropertySelector(kAudioDevicePropertyDeviceNameCFString),
                mScope: AudioObjectPropertyScope(kAudioObjectPropertyScopeGlobal),
                mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMain))
            var nameSize = UInt32(MemoryLayout<CFString>.size)
            
            let result = withUnsafeMutablePointer(to: &deviceName) { pointer in
                AudioObjectGetPropertyData(subDevice, &nameAddress, 0, nil, &nameSize, pointer)
            }

            if result == noErr {
                print("  Name: \(deviceName as String)")
            } else {
                print("  Name: <Could not be retrieved>")
            }
            
            let workingChannels = self.getWorkingChannels(subDevice: subDevice)
            print("  Final working channels: \(workingChannels)")
        }
        print("=== End Debug Info ===\n")
    }

    func getWorkingChannels(subDevice: AudioDeviceID) -> [UInt32] {
        var workingChannels: [UInt32] = []
        
        // Test a standard range of channels (e.g., Master, Left, Right)
        let channelsToTest: [UInt32] = [0, 1, 2]
        
        for channel in channelsToTest {
            var address = AudioObjectPropertyAddress(
                mSelector: AudioObjectPropertySelector(kAudioDevicePropertyVolumeScalar),
                mScope: AudioObjectPropertyScope(kAudioDevicePropertyScopeOutput),
                mElement: channel)
            
            // Check if the device reports having a volume property on this channel
            if AudioObjectHasProperty(subDevice, &address) {
                // As a final confirmation, try to read the property's value
                var testVol: Float = 0.0
                var testSize = UInt32(MemoryLayout<Float>.size)
                if AudioObjectGetPropertyData(subDevice, &address, 0, nil, &testSize, &testVol) == noErr {
                    // print("Found working channel \(channel) for device \(subDevice)")
                    workingChannels.append(channel) // Add the working channel to our list
                }
            }
        }
        
        // **Optional Improvement**: Some devices have a master channel (0) and stereo channels (1, 2).
        // In these cases, it's often best to control only the master channel.
        if workingChannels.contains(0) && (workingChannels.contains(1) || workingChannels.contains(2)) {
            print("Info: Found a master channel (0) alongside other channels. Preferring the master channel for control.")
            return [0]
        }
        
        if workingChannels.isEmpty {
            print("Warning: No working volume channels found for device \(subDevice)")
        }
        
        // Return the complete list of found channels
        return workingChannels
    }
    
    func getVolume() -> Float {
        var totalVolume: Float = 0.0
        var controllableDeviceCount = 0
        
        for subDevice in subDevicesID {
            let channels = self.getWorkingChannels(subDevice: subDevice)
            if channels.isEmpty {
                continue
            }
            
            var channelVolume: Float = 0.0
            var validChannelCount = 0
            
            for channel in channels {
                var vol: Float = 0.0
                var address = AudioObjectPropertyAddress(
                    mSelector:AudioObjectPropertySelector(kAudioDevicePropertyVolumeScalar),
                    mScope:AudioObjectPropertyScope(kAudioDevicePropertyScopeOutput),
                    mElement:channel)
                var propsize = UInt32(MemoryLayout<Float>.size)
                
                let result = AudioObjectGetPropertyData(subDevice, &address, 0, nil, &propsize, &vol)
                if result == noErr {
                    channelVolume += vol
                    validChannelCount += 1
                }
            }
            
            if validChannelCount > 0 {
                totalVolume += (channelVolume / Float(validChannelCount))
                controllableDeviceCount += 1
            }
        }

        if controllableDeviceCount > 0 {
            return totalVolume / Float(controllableDeviceCount)
        }
        
        print("Warning: No sub-devices support volume control.")
        return 0.0
    }
    
    func setVolume(volume: Float) {
        let isMuted = getMute()
        
        // If unmuting, make sure to turn mute off
        if isMuted && volume > 0 {
            setMute(false)
        }
        
        var vol = volume
        for subDevice in subDevicesID {
            let channels = self.getWorkingChannels(subDevice: subDevice)
            if channels.isEmpty {
                continue
            }
            
            for channel in channels {
                var address = AudioObjectPropertyAddress(
                    mSelector:AudioObjectPropertySelector(kAudioDevicePropertyVolumeScalar),
                    mScope:AudioObjectPropertyScope(kAudioDevicePropertyScopeOutput),
                    mElement:channel)
                let propsize = UInt32(MemoryLayout<Float>.size)
                
                AudioObjectSetPropertyData(subDevice, &address, 0, nil, propsize, &vol)
            }
        }
        
        // If volume is set to 0, also mute the device
        if volume == 0.0 && !isMuted {
            setMute(true)
        }
    }
    
    func getMute() -> Bool {
        for subDevice in subDevicesID {
            let channels = self.getWorkingChannels(subDevice: subDevice)
            if channels.isEmpty {
                continue
            }
            
            for channel in channels {
                var mute: UInt32 = 0
                var address = AudioObjectPropertyAddress(
                    mSelector:AudioObjectPropertySelector(kAudioDevicePropertyMute),
                    mScope:AudioObjectPropertyScope(kAudioDevicePropertyScopeOutput),
                    mElement:channel)
                var propsize = UInt32(MemoryLayout<UInt32>.size)
                
                // Only check mute status if the property exists
                if AudioObjectHasProperty(subDevice, &address) {
                    let result = AudioObjectGetPropertyData(subDevice, &address, 0, nil, &propsize, &mute)
                    if result == noErr && mute == 1 {
                        return true // If any controllable channel is muted, we consider it muted
                    }
                }
            }
        }
        return false
    }
    
    func switchMute() {
        let shouldMute = !getMute()
        setMute(shouldMute)
    }
    
    private func setMute(_ mute: Bool) {
        var mut: UInt32 = mute ? 1 : 0
        
        for subDevice in subDevicesID {
            let channels = self.getWorkingChannels(subDevice: subDevice)
            if channels.isEmpty {
                continue
            }
            
            for channel in channels {
                var address = AudioObjectPropertyAddress(
                    mSelector:AudioObjectPropertySelector(kAudioDevicePropertyMute),
                    mScope:AudioObjectPropertyScope(kAudioDevicePropertyScopeOutput),
                    mElement:channel)
                
                // Only try to set mute if the device supports it on this channel
                if AudioObjectHasProperty(subDevice, &address) {
                    let propsize = UInt32(MemoryLayout<UInt32>.size)
                    AudioObjectSetPropertyData(subDevice, &address, 0, nil, propsize, &mut)
                } else {
                    print("Info: Channel \(channel) on device \(subDevice) does not support mute control.")
                }
            }
        }
    }
}
