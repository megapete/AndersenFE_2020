//
//  RegulatingWindingDialog.swift
//  AndersenFE_2020
//
//  Created by Peter Huber on 2020-08-17.
//  Copyright © 2020 Peter Huber. All rights reserved.
//

import Cocoa

class RegulatingWindingDialog: PCH_DialogBox, NSTextFieldDelegate {

    enum wdgType {
        case doubleAxialStack
        case multistart
    }
    
    var type:wdgType
    
    var numLoops:Int
    
    @IBOutlet weak var doubleAxialStackRadioButton: NSButton!
    @IBOutlet weak var multistartRadioButton: NSButton!
    @IBOutlet weak var numLoopsTextField: NSTextField!
    
    
    init(type:RegulatingWindingDialog.wdgType, numLoops:Int)
    {
        self.type = type
        self.numLoops = numLoops
        
        super.init(viewNibFileName: "RegulatingWinding", windowTitle: "Define Regulating Winding", hideCancel: false)
    }
    
    override func awakeFromNib() {
        
        if self.type == .doubleAxialStack
        {
            self.doubleAxialStackRadioButton.state = .on
            self.multistartRadioButton.state = .off
        }
        else
        {
            self.doubleAxialStackRadioButton.state = .off
            self.multistartRadioButton.state = .on
        }
        
        let formatter = NumberFormatter()
        formatter.minimum = 4
        formatter.maximum = 17
        
        self.numLoopsTextField.formatter = formatter
        self.numLoopsTextField.delegate = self
        self.numLoopsTextField.stringValue = "\(numLoops)"
    }
    
    @IBAction func handleRadioButtonPush(_ sender: Any) {
        
        if doubleAxialStackRadioButton.state == .on
        {
            self.type = .doubleAxialStack
        }
        else
        {
            self.type = .multistart
        }
    }
    
    func controlTextDidChange(_ obj: Notification) {
        
        if let txFld = obj.object as? NSTextField
        {
            if txFld == self.numLoopsTextField
            {
                self.numLoops = Int(txFld.stringValue)!
            }
        }
        
    }
    
}
