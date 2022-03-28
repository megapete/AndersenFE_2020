//
//  ModifyReferenceVoltageDialog.swift
//  AndersenFE_2020
//
//  Created by Peter Huber on 2020-08-19.
//  Copyright © 2020 Peter Huber. All rights reserved.
//

import Cocoa

class ModifyReferenceVoltageDialog: PCH_DialogBox {

    @IBOutlet weak var voltageTextField: NSTextField!
    var voltage = 0.0
    
    init(currentVolts:Double)
    {
        self.voltage = currentVolts
        
        super.init(viewNibFileName: "ModifyReferenceVoltage", windowTitle: "Modify Reference Voltage", hideCancel: false)
    }
    
    override func awakeFromNib() {
        
        self.voltageTextField.stringValue = "\(fabs(self.voltage))"
        
        // Set up a formatter to clamp the allowable values in the text fields to -100...+100
        let textFieldFormatter = NumberFormatter()
        textFieldFormatter.minimumFractionDigits = 3
        textFieldFormatter.minimum = NSNumber(floatLiteral: 1.0)
        textFieldFormatter.maximum = NSNumber(floatLiteral: 500000.0)
        
        self.voltageTextField.formatter = textFieldFormatter
    }
    
    // override the handleOK function to get the value of MVA
    override func handleOk() {
        
        self.voltage = Double(self.voltageTextField.stringValue)!
        
        // make sure to call the super version of this function to actually handle the OK click
        super.handleOk()
    }
}
