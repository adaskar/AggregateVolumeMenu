//
//  MyApplication.swift
//  AggregateVolumeMenu
//
//  Created by Gurhan Polat on 21.12.2020.
//
import Cocoa

class MyApplication: NSApplication {
    let avcControl = AggregateVolumeControl()
    override func sendEvent(_ event: NSEvent) {
        if (event.type == .systemDefined && event.subtype.rawValue == 8) {
            let keyCode = ((event.data1 & 0xFFFF0000) >> 16)
            let keyState = ((((event.data1 & 0x0000FFFF) & 0xFF00) >> 8)) == 0xA
            let keyRepeat = ((event.data1 & 0x0000FFFF) & 0x1) == 1
            mediaKeyEvent(key: Int32(keyCode), state: keyState, keyRepeat: Bool(keyRepeat))
        }
        
        super.sendEvent(event)
    }
    
    func mediaKeyEvent(key: Int32, state: Bool, keyRepeat: Bool) {
        if (state) {
            switch(key) {
            case NX_KEYTYPE_MUTE:
                avcControl.switchMute()
                break
            case NX_KEYTYPE_SOUND_DOWN:
                var vol = avcControl.getVolume()
                vol = (vol - 0.1) <= 0 ? 0 : vol - 0.1
                avcControl.setVolume(volume: vol)
                break
            case NX_KEYTYPE_SOUND_UP:
                var vol = avcControl.getVolume()
                vol = (vol + 0.1) >= 1 ? 1 : vol + 0.1
                avcControl.setVolume(volume: vol)
                break
            default:
                break
            }
        }
    }
}
