//
//  MoveWindingDialog.swift
//  AndersenFE_2020
//
//  Created by Peter Huber on 2020-09-25.
//  Copyright © 2020 Peter Huber. All rights reserved.
//

import Cocoa

class MoveWindingDialog: PCH_DialogBox {
    
    @IBOutlet weak var deltaTextField: NSTextField!
    var delta:Double = 0.0
    
    enum direction {
        case axially
        case radially
    }
    
    init(direction:direction)
    {
        let title = direction == .radially ? "Offset Winding Radially" : "Offset Winding Axially"
        super.init(viewNibFileName: "MoveWinding", windowTitle: title, hideCancel: false)
    }
    
    override func awakeFromNib() {
        
        let formatter = NumberFormatter()
        formatter.minimum = -1000.0
        formatter.maximum = 1000.0
        
        self.deltaTextField.formatter = formatter
    }
    
    override func handleOk() {
        
        self.delta = Double(self.deltaTextField.stringValue)!
        
        super.handleOk()
    }
}
