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
           let rowIndex = devices.firstIndex(of: defaultDevice) {
            deviceTableView.selectRowIndexes(IndexSet(integer: rowIndex), byExtendingSelection: false)
            
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
    }
    
    @IBAction func volumeSliderChanged(_ sender: NSSlider) {
        let selectedRow = deviceTableView.selectedRow
        guard selectedRow >= 0 else { return }
        
        let selectedDevice = devices[selectedRow]
        audioManager.setVolume(sender.floatValue, for: selectedDevice)
    }
    
    // MARK: - TableView DataSource & Delegate
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return devices.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "DeviceNameColumn"), owner: self) as? NSTableCellView else {
            return nil
        }
        
        if row < devices.count {
            cell.textField?.stringValue = devices[row].name
        }
        
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
