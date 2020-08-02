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
    @IBOutlet weak var upperLowerGapSymmetric: NSButton!
    @IBOutlet weak var prefScopeLabel: NSTextField!
    @IBOutlet weak var multiStartElHtCenters: NSButton!
    @IBOutlet weak var defaultRefTerm2CheckBox: NSButton!
    
    
    var modelRadialDucts:Bool
    var modelZeroTerms:Bool
    var modelLayerTaps:Bool
    var upperLowerGapsAreSymmetric:Bool
    var scopeLabel:String
    var multiStartElecHtIsToCenters:Bool
    var defaultRefTerm2:Bool
    
    init(scopeLabel:String, modelRadialDucts:Bool, modelZeroTerms:Bool, modelLayerTaps:Bool, upperLowerGapsAreSymmetric:Bool, multiStartElecHtIsToCenters:Bool, defaultRefTerm2:Bool) {
        
        self.scopeLabel = scopeLabel
        self.modelRadialDucts = modelRadialDucts
        self.modelZeroTerms = modelZeroTerms
        self.modelLayerTaps = modelLayerTaps
        self.upperLowerGapsAreSymmetric = upperLowerGapsAreSymmetric
        self.multiStartElecHtIsToCenters = multiStartElecHtIsToCenters
        self.defaultRefTerm2 = defaultRefTerm2
        
        super.init(viewNibFileName: "Preferences", windowTitle: "Preferences", hideCancel: true)
    }
    
    override func awakeFromNib() {
        
        self.prefScopeLabel.stringValue = self.scopeLabel
        self.noRadialDuctsCheckbox.state = (self.modelRadialDucts ? .off : .on)
        self.noZeroTerminalsCheckbox.state = (self.modelZeroTerms ? .off : .on)
        self.noLayerWindingTapsCheckBox.state = (self.modelLayerTaps ? .off : .on)
        self.upperLowerGapSymmetric.state = (self.upperLowerGapsAreSymmetric ? .on : .off)
        self.multiStartElHtCenters.state = (self.multiStartElecHtIsToCenters ? .on : .off)
        self.defaultRefTerm2CheckBox.state = (self.defaultRefTerm2 ? .on : .off)
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
    
    @IBAction func handleUpperLowerSymGaps(_ sender: Any) {
    
        self.upperLowerGapsAreSymmetric = self.upperLowerGapSymmetric.state == .on
    }
    
    @IBAction func handleMultiStartElHtCenters(_ sender: Any) {
    
        self.multiStartElecHtIsToCenters = self.multiStartElHtCenters.state == .on
    }
    
    @IBAction func handleDefaultRefTerm2(_ sender: Any) {
        
        self.defaultRefTerm2 = self.defaultRefTerm2CheckBox.state == .on
    }
    
    
}
