//
//  PreferencesDialog.swift
//  AndersenFE_2020
//
//  Created by Peter Huber on 2020-07-25.
//  Copyright © 2020 Peter Huber. All rights reserved.
//

import Cocoa

class PreferencesDialog: PCH_DialogBox {
    
    @IBOutlet weak var noRadialDuctsCheckbox: NSButton!
    @IBOutlet weak var noZeroTerminalsCheckbox: NSButton!
    @IBOutlet weak var noLayerWindingTapsCheckBox: NSButton!
    
    var modelRadialDucts:Bool
    var modelZeroTerms:Bool
    var modelLayerTaps:Bool
    
    init(modelRadialDucts:Bool, modelZeroTerms:Bool, modelLayerTaps:Bool) {
        
        self.modelRadialDucts = modelRadialDucts
        self.modelZeroTerms = modelZeroTerms
        self.modelLayerTaps = modelLayerTaps
        
        super.init(viewNibFileName: "Preferences", windowTitle: "Preferences", hideCancel: true)
    }
    
    override func awakeFromNib() {
        self.noRadialDuctsCheckbox.state = (modelRadialDucts ? .off : .on)
        self.noZeroTerminalsCheckbox.state = (modelZeroTerms ? .off : .on)
        self.noLayerWindingTapsCheckBox.state = (modelLayerTaps ? .off : .on)
    }
    
    @IBAction func handleRadialDucts(_ sender: Any) {
        
        self.modelRadialDucts = self.noRadialDuctsCheckbox.state != .on
    }
    
    @IBAction func handleZeroTerms(_ sender: Any) {
        
        self.modelZeroTerms = self.noZeroTerminalsCheckbox.state != .on
    }
    
    @IBAction func handleInWindingTaps(_ sender: Any) {
        
        self.modelLayerTaps = self.noLayerWindingTapsCheckBox.state != .on
    }
    
}
