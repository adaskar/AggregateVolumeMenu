//
//  AudioDevice.swift
//  AggregateVolumeMenu
//
//  Created by Gurhan Polat on 22.12.2020.
//

import Foundation
import CoreAudio

struct AudioDevice: Equatable, Hashable {
    let id: AudioDeviceID
    let name: String
}