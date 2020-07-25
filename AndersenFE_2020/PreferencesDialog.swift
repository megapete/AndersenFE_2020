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
    
    init() {
        
        super.init(viewNibFileName: "Preferences", windowTitle: "Preferences", hideCancel: true)
    }
    
}
