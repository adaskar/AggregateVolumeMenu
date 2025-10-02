//
//  ContentView.swift
//  AggregateVolumeMenu
//
//  Created by emre argana on 30.09.2025.
//

import SwiftUI
import RiveRuntime

struct ContentView: View {
    @ObservedObject private var audioManager = AudioDeviceManager.shared
    @State private var isHoveringSlider = false
    @State private var hoveredDevice: AudioDevice?
    @StateObject private var riveViewModel = RiveViewModel(fileName: "cat", stateMachineName: "State Machine 1")
    
    var volumePercentage: Int {
        Int(audioManager.currentVolume * 100)
    }
    
    func adjustVolumeByStep(_ delta: Float) {
        audioManager.adjustVolume(by: delta)
    }
    
    var volumeIcon: String {
        AudioDeviceManager.getVolumeIcon(for: audioManager.currentVolume,
                                         isMuted: audioManager.isMuted)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with Volume Control
            VStack(spacing: 16) {
                // Current Device Display
                if let currentDevice = audioManager.currentDevice {
                    HStack {
                        Image(systemName: "hifispeaker.2.fill")
                            .foregroundColor(.accentColor)
                            .font(.system(size: 14))
                        
                        Text(currentDevice.name)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text("\(volumePercentage)%")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.secondary.opacity(0.15))
                            .cornerRadius(6)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
                
                // Volume Slider Section
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        // Mute Button
                        Button(action: { audioManager.toggleMute() }) {
                            Image(systemName: volumeIcon)
                                .font(.system(size: 16))
                                .foregroundColor(audioManager.isMuted ? .red : .primary)
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.plain)
                        .help(audioManager.isMuted ? "Unmute" : "Mute")
                        
                        // Volume Slider
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background Track
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.primary.opacity(0.1))
                                    .frame(height: 6)
                                
                                // Filled Track
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(audioManager.isMuted ? Color.red.opacity(0.5) : Color.accentColor)
                                    .frame(width: geometry.size.width * CGFloat(audioManager.currentVolume), height: 6)
                                
                                // Slider Thumb
                                Circle()
                                    .fill(audioManager.isMuted ? Color.red : Color.accentColor)
                                    .frame(width: isHoveringSlider ? 14 : 12, height: isHoveringSlider ? 14 : 12)
                                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                                    .offset(x: geometry.size.width * CGFloat(audioManager.currentVolume) - 6)
                            }
                            .frame(height: 20)
                            .contentShape(Rectangle())
                            .onHover { hovering in
                                isHoveringSlider = hovering
                            }
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        let newVolume = Float(value.location.x / geometry.size.width)
                                        audioManager.setCurrentVolume(max(0, min(1, newVolume)))
                                    }
                            )
                        }
                        .frame(height: 20)
                        
                        // Max Volume Icon
                        Image(systemName: "speaker.wave.3.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.primary.opacity(0.5))
                            .frame(width: 24, height: 24)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            
            Divider()
            
            // Devices List Section
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Label("Output Devices", systemImage: "speaker.wave.2")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(audioManager.outputDevices.count)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15))
                        .cornerRadius(4)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                
                // Devices List
                ScrollView {
                    VStack(spacing: 1) {
                        ForEach(audioManager.outputDevices, id: \.id) { device in
                            DeviceRow(
                                device: device,
                                isSelected: device == audioManager.currentDevice,
                                isHovered: hoveredDevice == device,
                                action: {
                                    audioManager.selectDevice(device)
                                }
                            )
                            .onHover { hovering in
                                hoveredDevice = hovering ? device : nil
                            }
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
        }
        .frame(width: 320, height: 420)
        .background(VisualEffectView())
        .overlay(
            // Rive animation as overlay covering entire window for mouse tracking
            ZStack {
                riveViewModel.view()
                    .frame(width: 320, height: 420)
                    .scaleEffect(0.4, anchor: .bottomLeading)
                    .allowsHitTesting(true)
                
                // Transparent overlay to ensure other UI elements remain interactive
                Color.clear
                    .frame(width: 320, height: 420)
                    .allowsHitTesting(false)
            }
                .frame(width: 320, height: 420)
        )
        .onAppear {
            audioManager.refreshDevices()
            audioManager.refreshCurrentDevice()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            audioManager.refreshDevices()
            audioManager.refreshCurrentDevice()
        }
        .focusable()
        .onKeyPress { press in
            switch press.key {
            case .upArrow:
                DispatchQueue.main.async {
                    adjustVolumeByStep(0.05)
                }
                return .handled
            case .downArrow:
                DispatchQueue.main.async {
                    adjustVolumeByStep(-0.05)
                }
                return .handled
            case .space:
                DispatchQueue.main.async {
                    audioManager.toggleMute()
                }
                return .handled
            default:
                return .ignored
            }
        }
    }
}

struct DeviceRow: View {
    let device: AudioDevice
    let isSelected: Bool
    let isHovered: Bool
    let action: () -> Void
    
    private var deviceIcon: String {
        let lowercasedName = device.name.lowercased()
        
        if lowercasedName.contains("airpods") {
            return "airpodspro"
        } else if lowercasedName.contains("headphone") {
            return "headphones"
        } else if lowercasedName.contains("bluetooth") {
            return "wave.3.right"
        } else if lowercasedName.contains("hdmi") || lowercasedName.contains("display") {
            return "tv"
        } else if lowercasedName.contains("usb") {
            return "cable.connector"
        } else if lowercasedName.contains("aggregate") {
            return "square.stack.3d.up"
        } else if lowercasedName.contains("mac") || lowercasedName.contains("speaker") {
            return "macbook.and.visionpro"
        } else {
            return "hifispeaker"
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Selection Indicator
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.accentColor : Color.clear)
                        .frame(width: 20, height: 20)
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.blue)
                    } else {
                        Circle()
                            .stroke(Color.primary.opacity(0.3), lineWidth: 1.5)
                            .frame(width: 20, height: 20)
                    }
                }
                
                // Device Icon
                Image(systemName: deviceIcon)
                    .font(.system(size: 16))
                    .frame(width: 24)
                
                // Device Name
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name)
                        .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                        .foregroundColor(isSelected ? .primary : .primary.opacity(0.9))
                        .lineLimit(1)
                    
                    if isSelected {
                        Text("Active")
                            .font(.system(size: 10))
                            .foregroundColor(.blue)
                    }
                }
                
                Spacer()
                
                // Connected indicator
                if isSelected {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? Color.primary.opacity(0.06) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
