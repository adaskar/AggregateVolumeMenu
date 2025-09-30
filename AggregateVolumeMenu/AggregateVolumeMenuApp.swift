//
//  AggregateVolumeMenuApp.swift
//  AggregateVolumeMenu
//
//  Created by emre argana on 30.09.2025.
//

import SwiftUI

@main
struct AggregateVolumeMenuApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var audioManager = AudioDeviceManager.shared
    private var volumeObserverTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()
        setupMediaKeyHandling()
        observeVolumeChanges()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        volumeObserverTimer?.invalidate()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: 30)

        if let button = statusItem?.button {
            updateMenuBarIcon()
            button.action = #selector(togglePopover)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    private func observeVolumeChanges() {
        volumeObserverTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            self.updateMenuBarIcon()
        }
    }

    private func updateMenuBarIcon() {
        guard let button = statusItem?.button else { return }

        let volume = audioManager.currentVolume
        let isMuted = audioManager.isMuted
        let volumePercentage = Int(volume * 100)

        let iconName = AudioDeviceManager.getVolumeIcon(for: volume, isMuted: isMuted)

        let image = NSImage(systemSymbolName: iconName, accessibilityDescription: "Volume: \(volumePercentage)%")
        image?.isTemplate = true
        
        button.image = image
        button.imagePosition = .imageOnly
        
        updateTooltip(button: button, volume: volumePercentage, isMuted: isMuted)
        
        if isMuted {
            button.contentTintColor = NSColor.systemRed
            button.alphaValue = 0.9
        } else if volume == 0 {
            button.contentTintColor = NSColor.systemGray
            button.alphaValue = 0.7
        } else {
            button.contentTintColor = nil
            button.alphaValue = 1.0
        }
    }

    private func updateTooltip(button: NSButton, volume: Int, isMuted: Bool) {
        var tooltipComponents: [String] = []

        if isMuted {
            tooltipComponents.append("Muted")
        } else {
            tooltipComponents.append("Volume: \(volume)%")
        }

        if let device = audioManager.currentDevice {
            tooltipComponents.append("Device: \(device.name)")
        }

        tooltipComponents.append("Click to open • Space to mute")
        button.toolTip = tooltipComponents.joined(separator: "\n")
    }

    private func setupPopover() {
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 320, height: 420)
        popover?.behavior = .transient
        popover?.animates = true
        popover?.contentViewController = NSHostingController(rootView: ContentView())
    }

    private func setupMediaKeyHandling() {
        NSEvent.addGlobalMonitorForEvents(matching: .systemDefined) { event in
            self.handleMediaKey(event: event)
        }

        NSEvent.addLocalMonitorForEvents(matching: .systemDefined) { event in
            self.handleMediaKey(event: event)
            return event
        }
    }

    private func handleMediaKey(event: NSEvent) {
        guard event.subtype == .screenChanged else { return }

        let keyCode = ((event.data1 & 0xFFFF0000) >> 16)
        let keyFlags = (event.data1 & 0x0000FFFF)
        let keyState = ((keyFlags & 0xFF00) >> 8) == 0xA

        if keyState {
            switch Int32(keyCode) {
            case NX_KEYTYPE_SOUND_UP:
                audioManager.adjustVolume(by: 0.0625)
                updateMenuBarIcon()
                
            case NX_KEYTYPE_SOUND_DOWN:
                audioManager.adjustVolume(by: -0.0625)
                updateMenuBarIcon()
                
            case NX_KEYTYPE_MUTE:
                audioManager.toggleMute()
                updateMenuBarIcon()
                
            default:
                break
            }
        }
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }

        if let popover = popover {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                audioManager.refreshCurrentDevice()
                updateMenuBarIcon()
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}
