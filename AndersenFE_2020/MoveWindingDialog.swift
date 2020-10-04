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
    @IBOutlet weak var deltaLabel: NSTextField!
    
    var delta:Double = 0.0
    var lableString:String = "Delta-R"
    
    enum direction {
        case axially
        case radially
    }
    
    let dir:direction
    
    init(direction:direction)
    {
        let title = direction == .radially ? "Offset Winding Radially" : "Offset Winding Axially"
        self.dir = direction
        super.init(viewNibFileName: "MoveWinding", windowTitle: title, hideCancel: false)
    }
    
    override func awakeFromNib() {
        
        let formatter = NumberFormatter()
        formatter.minimum = -1000.0
        formatter.maximum = 1000.0
        
        self.deltaTextField.formatter = formatter
        
        self.deltaLabel.stringValue = self.dir == .radially ? "Delta-R" : "Delta-Z"
    }
    
    override func handleOk() {
        
        self.delta = Double(self.deltaTextField.stringValue)!
        
        super.handleOk()
    }
}
