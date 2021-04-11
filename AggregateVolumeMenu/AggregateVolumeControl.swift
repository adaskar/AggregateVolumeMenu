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
    var audioDeviceUID:CFString? = nil;
    var subDeviceCount:Int = 0;
    var subDevicesID = [AudioDeviceID]()
    
    init() {
        
        // get default audio output device
        address = AudioObjectPropertyAddress(
            mSelector:AudioObjectPropertySelector(kAudioHardwarePropertyDefaultOutputDevice),
            mScope:AudioObjectPropertyScope(kAudioObjectPropertyScopeGlobal),
            mElement:AudioObjectPropertyElement(kAudioObjectPropertyElementMaster))

        audioDeviceID = 0
        propsize = UInt32(MemoryLayout<AudioDeviceID>.size)
        result = AudioObjectGetPropertyData(AudioDeviceID(kAudioObjectSystemObject), &address, 0, nil, &propsize, &audioDeviceID)

        if (result != 0) {
            print("kAudioHardwarePropertyDefaultOutputDevice result:\(result)")
            exit(-1)
        }

        // get default audio output device uid
        address = AudioObjectPropertyAddress(
            mSelector:AudioObjectPropertySelector(kAudioDevicePropertyDeviceUID),
            mScope:AudioObjectPropertyScope(kAudioObjectPropertyScopeGlobal),
            mElement:AudioObjectPropertyElement(kAudioObjectPropertyElementMaster))

        
        propsize = UInt32(MemoryLayout<CFString?>.size)
        result = AudioObjectGetPropertyData(audioDeviceID, &address, 0, nil, &propsize, &audioDeviceUID)

        if (result != 0) {
            print("kAudioDevicePropertyDeviceUID result:\(result)")
            exit(-1)
        }

        // get default audio output device transport type
        address = AudioObjectPropertyAddress(
            mSelector:AudioObjectPropertySelector(kAudioDevicePropertyTransportType),
            mScope:AudioObjectPropertyScope(kAudioObjectPropertyScopeGlobal),
            mElement:AudioObjectPropertyElement(kAudioObjectPropertyElementMaster))
        var transportType:UInt32 = 0
        propsize = UInt32(MemoryLayout<UInt32>.size)
        result = AudioObjectGetPropertyData(audioDeviceID, &address, 0, nil, &propsize, &transportType)

        if (result != 0) {
            print("kAudioDevicePropertyTransportType result:\(result)")
            exit(-1)
        }

        // if transportType is not Aggregate then exit the tool
        if (transportType != kAudioDeviceTransportTypeAggregate) {
            print("audioDeviceID: \(audioDeviceID) uid: \(audioDeviceUID as String? ?? "") transportType: \(transportType == kAudioDeviceTransportTypeAggregate)")
            print("this tool only works with a kAudioDeviceTransportTypeAggregate result:\(result)")
            exit(1)
        }

        // get the sublist of the Aggregate Audio Device
        address = AudioObjectPropertyAddress(
            mSelector:AudioObjectPropertySelector(kAudioAggregateDevicePropertyActiveSubDeviceList),
            mScope:AudioObjectPropertyScope(kAudioObjectPropertyScopeGlobal),
            mElement:AudioObjectPropertyElement(kAudioObjectPropertyElementMaster))
        for _ in 0..<32 {
            subDevicesID.append(AudioDeviceID())
        }
        propsize = UInt32(MemoryLayout<AudioDeviceID>.size * 32)
        result = AudioObjectGetPropertyData(audioDeviceID, &address, 0, nil, &propsize, &subDevicesID)

        if (result != 0) {
            print("kAudioAggregateDevicePropertyActiveSubDeviceList result:\(result)")
            exit(-1)
        }

        subDeviceCount = Int((propsize / UInt32(MemoryLayout<AudioDeviceID>.size)))
    }
    
    func getChannels(subDevice: AudioDeviceID) -> [UInt32] {
        var channelNumbers = [UInt32]()
        
        for _ in 0..<32 {
            channelNumbers.append(UInt32())
        }
        
        address = AudioObjectPropertyAddress(
            mSelector:AudioObjectPropertySelector(kAudioDevicePropertyPreferredChannelsForStereo),
            mScope:AudioObjectPropertyScope(kAudioDevicePropertyScopeOutput),
            mElement:AudioObjectPropertyElement(kAudioObjectPropertyElementMaster))
        
        propsize = UInt32(MemoryLayout<UInt32>.size * 32)
        result = AudioObjectGetPropertyData(subDevice, &address, 0, nil, &propsize, &channelNumbers)
        if (result != 0) {
            print("kAudioDevicePropertyPreferredChannelsForStereo result:\(result)")
            exit(-1)
        }
        
        if ((Int(propsize) / MemoryLayout<UInt32>.size) < 32) {
            let range = (Int(propsize) / MemoryLayout<UInt32>.size)...31
            channelNumbers.removeSubrange(range)
        }
        return channelNumbers
    }
    
    func getVolume() -> Float {
        var volAvg:Float = 0.0
        
        for i in 0..<subDeviceCount {
            let subDevice:AudioDeviceID = subDevicesID[i]
            let channels = getChannels(subDevice: subDevice)
            
            var volSum: Float = 0.0
            for channel in channels {
                var vol: Float = 0.0
                address = AudioObjectPropertyAddress(
                    mSelector:AudioObjectPropertySelector(kAudioDevicePropertyVolumeScalar),
                    mScope:AudioObjectPropertyScope(kAudioDevicePropertyScopeOutput),
                    mElement:channel)
                propsize = UInt32(MemoryLayout<Float>.size)
                
                result = AudioObjectGetPropertyData(subDevice, &address, 0, nil, &propsize, &vol)
                if (result != 0) {
                    print("kAudioDevicePropertyVolumeScalar channel:\(channel) result:\(result)")
                    exit(-1)
                }
                
                volSum += vol
            }
            
            volAvg += volSum / Float(channels.count)
        }

        volAvg = volAvg / Float(subDeviceCount)
        return volAvg
    }
    
    func setVolume(volume:Float) {
        var vol = volume
        if (vol == 0) {
            if (!getMute()) {
                switchMute()
            }
            return
        }
        if (getMute()) {
            switchMute()
        }
        for i in 0..<subDeviceCount {
            let subDevice:AudioDeviceID = subDevicesID[i]
            let channels = getChannels(subDevice: subDevice)
            
            for channel in channels {
                address = AudioObjectPropertyAddress(
                    mSelector:AudioObjectPropertySelector(kAudioDevicePropertyVolumeScalar),
                    mScope:AudioObjectPropertyScope(kAudioDevicePropertyScopeOutput),
                    mElement:channel)
                propsize = UInt32(MemoryLayout<Float>.size)
                
                result = AudioObjectSetPropertyData(subDevice, &address, 0, nil, propsize, &vol)
                if (result != 0) {
                    print("kAudioDevicePropertyVolumeScalar channel:\(channel) result:\(result)")
                    exit(-1)
                }
            }
        }
    }
    
    func getMute() -> Bool {
        for i in 0..<subDeviceCount {
            let subDevice:AudioDeviceID = subDevicesID[i]
            let channels = getChannels(subDevice: subDevice)
            
            var mute:UInt32 = 0
            
            for channel in channels {
                address = AudioObjectPropertyAddress(
                    mSelector:AudioObjectPropertySelector(kAudioDevicePropertyMute),
                    mScope:AudioObjectPropertyScope(kAudioDevicePropertyScopeOutput),
                    mElement:channel)
                propsize = UInt32(MemoryLayout<UInt32>.size)
                
                result = AudioObjectGetPropertyData(subDevice, &address, 0, nil, &propsize, &mute)
                if (result != 0) {
                    print("kAudioDevicePropertyVolumeScalar channel:\(channel) result:\(result)")
                    exit(-1)
                }
                if (mute == 1) {
                    return true
                }
            }
        }
        return false
    }
    
    func switchMute() {
        let mute = !getMute()
        
        var mut: UInt32 = (mute == true) ? 1 : 0
        for i in 0..<subDeviceCount {
            let subDevice:AudioDeviceID = subDevicesID[i]
            let channels = getChannels(subDevice: subDevice)
            
            for channel in channels {
                address = AudioObjectPropertyAddress(
                    mSelector:AudioObjectPropertySelector(kAudioDevicePropertyMute),
                    mScope:AudioObjectPropertyScope(kAudioDevicePropertyScopeOutput),
                    mElement:channel)
                propsize = UInt32(MemoryLayout<UInt32>.size)
                
                result = AudioObjectSetPropertyData(subDevice, &address, 0, nil, propsize, &mut)
                if (result != 0) {
                    print("kAudioDevicePropertyMute channel:\(channel) result:\(result)")
                    exit(-1)
                }
            }
        }
    }
}

