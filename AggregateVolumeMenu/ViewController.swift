//
//  ViewController.swift
//  AggregateVolumeMenu
//
//  Created by Gurhan Polat on 21.12.2020.
//

import Cocoa

class ViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    var audioManager: AudioDeviceManager!
    private var devices: [AudioDevice] = []
    
    @IBOutlet weak var deviceTableView: NSTableView!
    @IBOutlet weak var volumeSlider: NSSlider!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        deviceTableView.dataSource = self
        deviceTableView.delegate = self
        deviceTableView.action = #selector(onDeviceSelected)
        deviceTableView.style = .sourceList
        
        volumeSlider.minValue = 0
        volumeSlider.maxValue = 1
        volumeSlider.isContinuous = true // Ensure slider updates while dragging
        
        // Listen for notifications when media keys change the volume
        NotificationCenter.default.addObserver(self, selector: #selector(updateUI), name: .volumeChanged, object: nil)
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        updateUI()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func updateUI() {
        // Refresh device list
        devices = audioManager.getOutputDevices()
        deviceTableView.reloadData()
        
        // Select current default device
        if let defaultDevice = audioManager.getDefaultOutputDevice(),
           let _ = devices.firstIndex(of: defaultDevice) {
            // Update slider
            if let volume = audioManager.getVolume(for: defaultDevice) {
                volumeSlider.isEnabled = true
                volumeSlider.floatValue = volume
            } else {
                volumeSlider.isEnabled = false
            }
        } else {
            volumeSlider.isEnabled = false
        }
    }
    
    @objc private func onDeviceSelected() {
        let selectedRow = deviceTableView.selectedRow
        guard selectedRow >= 0 else { return }
        
        let selectedDevice = devices[selectedRow]
        audioManager.setDefaultOutputDevice(selectedDevice)
        
        // Update the volume slider for the newly selected device
        if let volume = audioManager.getVolume(for: selectedDevice) {
            volumeSlider.isEnabled = true
            volumeSlider.floatValue = volume
        } else {
            volumeSlider.isEnabled = false
        }
        
        // Reload the table to update the checkmark
        deviceTableView.reloadData()
        
        // Deselect the row to remove the highlight
        deviceTableView.deselectRow(selectedRow)
    }
    
    @IBAction func volumeSliderChanged(_ sender: NSSlider) {
        // The slider should always control the default output device,
        // which is indicated by the checkmark.
        guard let defaultDevice = audioManager.getDefaultOutputDevice() else { return }
        audioManager.setVolume(sender.floatValue, for: defaultDevice)
    }
    
    // MARK: - TableView DataSource & Delegate
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return devices.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "DeviceNameColumn"), owner: self) as? NSTableCellView,
              row < devices.count else {
            return nil
        }
        
        let device = devices[row]
        cell.textField?.stringValue = device.name
        
        let isSelectedDevice = (device == audioManager.getDefaultOutputDevice())
        let checkmarkImage = isSelectedDevice ? NSImage(systemSymbolName: "checkmark", accessibilityDescription: "Selected") : nil
        cell.imageView?.image = checkmarkImage
        
        return cell
    }
    
    static func newInstance() -> ViewController {
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        let identifier = NSStoryboard.SceneIdentifier("ViewController")
          
        guard let viewcontroller = storyboard.instantiateController(withIdentifier: identifier) as? ViewController else {
            fatalError("Unable to instantiate ViewController in Main.storyboard")
        }
        return viewcontroller
    }

}
