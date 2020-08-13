//
//  ModifyReferenceMvaDialog.swift
//  AndersenFE_2020
//
//  Created by Peter Huber on 2020-08-12.
//  Copyright © 2020 Peter Huber. All rights reserved.
//

import Cocoa

class ModifyReferenceMvaDialog: PCH_DialogBox, NSTextFieldDelegate {

    @IBOutlet weak var mvaTextField: NSTextField!
    var MVA = 0.0
    
    init(currentMVA:Double)
    {
        self.MVA = currentMVA
        
        super.init(viewNibFileName: "ModifyReferenceMva", windowTitle: "Modify Reference MVA", hideCancel: false)
    }
    
    override func awakeFromNib() {
        
        self.mvaTextField.stringValue = "\(self.MVA)"
    }
    
    func controlTextDidEndEditing(_ obj: Notification) {
        
        if let txFld = obj.object as? NSTextField
        {
            if txFld == self.mvaTextField
            {
                if let mvaNum = Double(txFld.stringValue)
                {
                    self.MVA = max(0.01, mvaNum)
                }
            }
        }
    }
}
