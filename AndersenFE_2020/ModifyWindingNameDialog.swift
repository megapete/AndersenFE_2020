//
//  ModifyWindingNameDialog.swift
//  AndersenFE_2020
//
//  Created by Peter Huber on 2020-08-30.
//  Copyright © 2020 Peter Huber. All rights reserved.
//

import Cocoa

class ModifyWindingNameDialog: PCH_DialogBox {

    @IBOutlet weak var wdgNameTextField: NSTextField!
    var windingName:String = ""
    
    init(oldName:String)
    {
        self.windingName = oldName
        
        super.init(viewNibFileName: "ModifyWindingName", windowTitle: "Winding Name", hideCancel: false)
    }
    
    override func awakeFromNib() {
        
        self.wdgNameTextField.stringValue = windingName
    }
    
    // override the handleOK function to get the name
    override func handleOk() {
        
        self.windingName = self.wdgNameTextField.stringValue
        
        // make sure to call the super version of this function to actually handle the OK click
        super.handleOk()
    }
}
