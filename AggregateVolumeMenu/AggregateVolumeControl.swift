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
            print("kAudioHardwarePropertyDefaultOutputDevice")
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
            print("kAudioDevicePropertyDeviceUID")
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
            print("kAudioDevicePropertyTransportType")
            exit(-1)
        }

        // if transportType is not Aggregate then exit the tool
        if (transportType != kAudioDeviceTransportTypeAggregate) {
            print("audioDeviceID: \(audioDeviceID) uid: \(audioDeviceUID as String? ?? "") transportType: \(transportType == kAudioDeviceTransportTypeAggregate)")
            print("this tool only works with a kAudioDeviceTransportTypeAggregate")
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
            print("kAudioAggregateDevicePropertyActiveSubDeviceList")
            exit(-1)
        }

        subDeviceCount = Int((propsize / UInt32(MemoryLayout<AudioDeviceID>.size)))
    }
    
    func getVolume() -> Float {
        var volAvg:Float = 0.0
        for i in 0..<subDeviceCount {
            let subDevice:AudioDeviceID = subDevicesID[i]
            
            var volLeft:Float = 0.0
            var volRight:Float = 0.0
                        
            address = AudioObjectPropertyAddress(
                mSelector:AudioObjectPropertySelector(kAudioDevicePropertyVolumeScalar),
                mScope:AudioObjectPropertyScope(kAudioDevicePropertyScopeOutput),
                mElement:1)
            propsize = UInt32(MemoryLayout<Float>.size)
            
            result = AudioObjectGetPropertyData(subDevice, &address, 0, nil, &propsize, &volLeft)
            if (result != 0) {
                print("kAudioDevicePropertyVolumeScalar volLeft")
                exit(-1)
            }
            
            address = AudioObjectPropertyAddress(
                mSelector:AudioObjectPropertySelector(kAudioDevicePropertyVolumeScalar),
                mScope:AudioObjectPropertyScope(kAudioDevicePropertyScopeOutput),
                mElement:2)
            propsize = UInt32(MemoryLayout<Float>.size)
            result = AudioObjectGetPropertyData(subDevice, &address, 0, nil, &propsize, &volRight)
            if (result != 0) {
                print("kAudioDevicePropertyVolumeScalar volRight")
                exit(-1)
            }
            
            volAvg += (volLeft + volRight) / 2
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
            
            address = AudioObjectPropertyAddress(
                mSelector:AudioObjectPropertySelector(kAudioDevicePropertyVolumeScalar),
                mScope:AudioObjectPropertyScope(kAudioDevicePropertyScopeOutput),
                mElement:1)
            propsize = UInt32(MemoryLayout<Float>.size)
            
            result = AudioObjectSetPropertyData(subDevice, &address, 0, nil, propsize, &vol)
            if (result != 0) {
                print("kAudioDevicePropertyVolumeScalar volLeft")
                exit(-1)
            }
            
            address = AudioObjectPropertyAddress(
                mSelector:AudioObjectPropertySelector(kAudioDevicePropertyVolumeScalar),
                mScope:AudioObjectPropertyScope(kAudioDevicePropertyScopeOutput),
                mElement:2)
            propsize = UInt32(MemoryLayout<Float>.size)
            result = AudioObjectSetPropertyData(subDevice, &address, 0, nil, propsize, &vol)
            if (result != 0) {
                print("kAudioDevicePropertyVolumeScalar volRight")
                exit(-1)
            }
        }
    }
    
    func getMute() -> Bool {
        for i in 0..<subDeviceCount {
            let subDevice:AudioDeviceID = subDevicesID[i]
            
            var mute:UInt32 = 0
                        
            address = AudioObjectPropertyAddress(
                mSelector:AudioObjectPropertySelector(kAudioDevicePropertyMute),
                mScope:AudioObjectPropertyScope(kAudioDevicePropertyScopeOutput),
                mElement:1)
            propsize = UInt32(MemoryLayout<UInt32>.size)
            
            result = AudioObjectGetPropertyData(subDevice, &address, 0, nil, &propsize, &mute)
            if (result != 0) {
                print("kAudioDevicePropertyVolumeScalar volLeft")
                exit(-1)
            }
            if (mute == 1) {
                return true
            }
            
            address = AudioObjectPropertyAddress(
                mSelector:AudioObjectPropertySelector(kAudioDevicePropertyMute),
                mScope:AudioObjectPropertyScope(kAudioDevicePropertyScopeOutput),
                mElement:2)
            propsize = UInt32(MemoryLayout<UInt32>.size)
            result = AudioObjectGetPropertyData(subDevice, &address, 0, nil, &propsize, &mute)
            if (result != 0) {
                print("kAudioDevicePropertyVolumeScalar volRight")
                exit(-1)
            }
            if (mute == 1) {
                return true
            }
        }
        return false
    }
    
    func switchMute() {
        let mute = !getMute()
        
        var mut: UInt32 = (mute == true) ? 1 : 0
        for i in 0..<subDeviceCount {
            let subDevice:AudioDeviceID = subDevicesID[i]
            
            address = AudioObjectPropertyAddress(
                mSelector:AudioObjectPropertySelector(kAudioDevicePropertyMute),
                mScope:AudioObjectPropertyScope(kAudioDevicePropertyScopeOutput),
                mElement:1)
            propsize = UInt32(MemoryLayout<UInt32>.size)
            
            result = AudioObjectSetPropertyData(subDevice, &address, 0, nil, propsize, &mut)
            if (result != 0) {
                print("kAudioDevicePropertyMute volLeft")
                exit(-1)
            }
            
            address = AudioObjectPropertyAddress(
                mSelector:AudioObjectPropertySelector(kAudioDevicePropertyMute),
                mScope:AudioObjectPropertyScope(kAudioDevicePropertyScopeOutput),
                mElement:2)
            propsize = UInt32(MemoryLayout<UInt32>.size)
            result = AudioObjectSetPropertyData(subDevice, &address, 0, nil, propsize, &mut)
            if (result != 0) {
                print("kAudioDevicePropertyMute volRight")
                exit(-1)
            }
        }
    }
}

