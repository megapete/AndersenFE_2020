//
//  SplitSegmentDialog.swift
//  AndersenFE_2020
//
//  Created by Peter Huber on 2020-09-20.
//  Copyright © 2020 Peter Huber. All rights reserved.
//

import Cocoa

class SplitSegmentDialog: PCH_DialogBox {
    
    @IBOutlet weak var multipleRadioButton: NSButton!
    @IBOutlet weak var doubleRadioButton: NSButton!
    @IBOutlet weak var labelTextField: NSTextField!
    @IBOutlet weak var numsegsTextField: NSTextField!
    
    enum SplitType {
        case multiple
        case double
    }
    
    var type:SplitType = .multiple
    var number:Double = 1.0
    
    init()
    {
        super.init(viewNibFileName: "SplitSegment", windowTitle: "Split Segment", hideCancel: false)
    }
    
    override func awakeFromNib() {
        
        self.multipleRadioButton.state = .on
        self.doubleRadioButton.state = .off
        self.labelTextField.stringValue = "Number of segments"
        
        let textFieldFormatter = NumberFormatter()
        textFieldFormatter.minimum = NSNumber(floatLiteral: 1.0)
        textFieldFormatter.maximum = NSNumber(floatLiteral: 99.0)
        self.numsegsTextField.formatter = textFieldFormatter
        self.numsegsTextField.stringValue = "1"
    }
    
    @IBAction func handleRadioButton(_ sender: Any) {
        
        if self.multipleRadioButton.state == .on
        {
            self.type = .multiple
            self.labelTextField.stringValue = "Number of segments"
        }
        else
        {
            self.type = .double
            self.labelTextField.stringValue = "Percentage of bottom-most segment"
        }
    }
    
    override func handleOk() {
        
        self.number = Double(self.numsegsTextField.stringValue)!
        
        super.handleOk()
    }
}
