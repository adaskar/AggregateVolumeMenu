//
//  AppDelegate.swift
//  AggregateVolumeMenu
//
//  Created by Gurhan Polat on 21.12.2020.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    let statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)
    let popover = NSPopover()
    let audioManager = AudioDeviceManager()
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        if let button = self.statusItem.button {
            button.image = NSImage(named: NSImage.Name("StatusIcon"))
            button.action = #selector(AppDelegate.togglePopover(_:))
        }
        
        let vc = ViewController.newInstance()
        vc.audioManager = audioManager // Pass the shared instance
        self.popover.contentViewController = vc
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
    }
    
    @objc func togglePopover(_ sender: NSStatusItem) {
        if self.popover.isShown {
            closePopover(sender: sender)
        }
        else {
            showPopover(sender: sender)
        }
    }
    
    func showPopover(sender: Any?) {
        if let button = self.statusItem.button {
            self.popover.behavior = NSPopover.Behavior.transient
            NSApp.activate(ignoringOtherApps: true)
            self.popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
        }
    }

    func closePopover(sender: Any?)  {
        self.popover.performClose(sender)
    }
}
