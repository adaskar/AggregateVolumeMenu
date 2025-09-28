//
//  MyApplication.swift
//  AggregateVolumeMenu
//
//  Created by Gurhan Polat on 21.12.2020.
//
import Cocoa

class MyApplication: NSApplication {
    // Access the shared instance from the AppDelegate
    private var audioManager: AudioDeviceManager? {
        (delegate as? AppDelegate)?.audioManager
    }

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
        guard let audioManager = audioManager, let device = audioManager.getDefaultOutputDevice() else { return }

        if (state) {
            switch(key) {
            case NX_KEYTYPE_MUTE:
                if let isMuted = audioManager.getMute(for: device) {
                    audioManager.setMute(!isMuted, for: device)
                }
                break
            case NX_KEYTYPE_SOUND_DOWN:
                if let vol = audioManager.getVolume(for: device) {
                    let newVolume = max(0, vol - 0.0625) // Standard 16-step volume
                    audioManager.setVolume(newVolume, for: device)
                }
                break
            case NX_KEYTYPE_SOUND_UP:
                if let vol = audioManager.getVolume(for: device) {
                    let newVolume = min(1, vol + 0.0625) // Standard 16-step volume
                    audioManager.setVolume(newVolume, for: device)
                }
                break
            default:
                break
            }
            // Notify the ViewController to update its UI
            NotificationCenter.default.post(name: .volumeChanged, object: nil)
        }
    }
}

extension Notification.Name {
    static let volumeChanged = Notification.Name("volumeChanged")
}
