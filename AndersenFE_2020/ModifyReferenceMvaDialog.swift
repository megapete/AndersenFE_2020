//
//  ModifyReferenceMvaDialog.swift
//  AndersenFE_2020
//
//  Created by Peter Huber on 2020-08-12.
//  Copyright © 2020 Peter Huber. All rights reserved.
//

import Cocoa

class ModifyReferenceMvaDialog: PCH_DialogBox {

    @IBOutlet weak var mvaTextField: NSTextField!
    var MVA = 0.0
    
    init(currentMVA:Double)
    {
        self.MVA = currentMVA
        
        super.init(viewNibFileName: "ModifyReferenceMva", windowTitle: "Modify Reference MVA", hideCancel: false)
    }
    
    override func awakeFromNib() {
        
        self.mvaTextField.stringValue = "\(fabs(self.MVA))"
        
        // Set up a formatter to clamp the allowable values in the text fields to -100...+100
        let textFieldFormatter = NumberFormatter()
        textFieldFormatter.minimumFractionDigits = 3
        textFieldFormatter.minimum = NSNumber(floatLiteral: 0.0)
        textFieldFormatter.maximum = NSNumber(floatLiteral: 1000.0)
        
        self.mvaTextField.formatter = textFieldFormatter
    }
    
    // override the handleOK function to get the value of MVA
    override func handleOk() {
        
        self.MVA = Double(self.mvaTextField.stringValue)!
        
        // make sure to call the super version of this function to actually handle the OK click
        super.handleOk()
    }
    
}
