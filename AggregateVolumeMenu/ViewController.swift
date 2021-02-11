//
//  ViewController.swift
//  AggregateVolumeMenu
//
//  Created by Gurhan Polat on 21.12.2020.
//

import Cocoa

class ViewController: NSViewController {
    let avcControl = AggregateVolumeControl()
    
    @IBOutlet weak var hsVolume: NSSlider!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        hsVolume.minValue = 0
        hsVolume.maxValue = 1
        hsVolume.isContinuous = false
        hsVolume.floatValue = avcControl.getVolume()
    }
    
    override func viewWillAppear() {
        hsVolume.floatValue = avcControl.getVolume()
    }

    override var representedObject: Any? {
        didSet {
        }
    }
    @IBAction func hsVolumeChanged(_ sender: Any) {
        avcControl.setVolume(volume: hsVolume.floatValue)
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

