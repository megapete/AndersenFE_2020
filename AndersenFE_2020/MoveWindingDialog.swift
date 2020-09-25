//
//  MoveWindingDialog.swift
//  AndersenFE_2020
//
//  Created by Peter Huber on 2020-09-25.
//  Copyright © 2020 Peter Huber. All rights reserved.
//

import Cocoa

class MoveWindingDialog: PCH_DialogBox {
    
    @IBOutlet weak var deltaRtextField: NSTextField!
    var deltaR:Double = 0.0
    
    init()
    {
        super.init(viewNibFileName: "MoveWinding", windowTitle: "Offset Winding Radially", hideCancel: false)
    }
    
    override func awakeFromNib() {
        
        let formatter = NumberFormatter()
        formatter.minimum = -100.0
        formatter.maximum = 100.0
        
        self.deltaRtextField.formatter = formatter
    }
    
    override func handleOk() {
        
        self.deltaR = Double(self.deltaRtextField.stringValue)!
        
        super.handleOk()
    }
}
