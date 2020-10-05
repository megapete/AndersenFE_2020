//
//  GetNumberDialog.swift
//  AndersenFE_2020
//
//  Created by Peter Huber on 2020-10-04.
//  Copyright © 2020 Peter Huber. All rights reserved.
//

// Generic dialog box to get a single number

import Cocoa

class GetNumberDialog: PCH_DialogBox {

    @IBOutlet weak var descLabel: NSTextField!
    @IBOutlet weak var unitsLabel: NSTextField!
    @IBOutlet weak var noteLabel: NSTextField!
    
    
    @IBOutlet weak var numberField: NSTextField!
    
    let descriptiveText:String
    let unitsText:String
    let noteText:String
    
    let fieldFormatter:Formatter?
    
    var numberValue:Double = 0.0
    
    /// Return a dialog box to retreive a single number (note that if 'fieldFormatter' is non-nil, it MUST be a NumberFormatter with appropriate field set in it).
    init(descriptiveText:String, unitsText:String, noteText:String, windowTitle:String, initialValue:Double = 0.0, fieldFormatter:Formatter? = nil)
    {
        self.descriptiveText = descriptiveText
        self.unitsText = unitsText
        self.noteText = noteText
        self.fieldFormatter = fieldFormatter
        
        super.init(viewNibFileName: "GetNumber", windowTitle: windowTitle, hideCancel: false)
    }
    
    override func awakeFromNib() {
        
        self.descLabel.stringValue = self.descriptiveText
        self.unitsLabel.stringValue = self.unitsText
        self.noteLabel.stringValue = self.noteText
        
        if let formatter = self.fieldFormatter
        {
            self.numberField.formatter = formatter
        }
        else
        {
            self.numberField.formatter = NumberFormatter()
        }
        
        self.numberField.doubleValue = self.numberValue
    }
    
    override func handleOk() {
        
        self.numberValue = self.numberField.doubleValue
        
        super.handleOk()
    }
    
}
