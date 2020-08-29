//
//  TransformerDescriptionDialog.swift
//  AndersenFE_2020
//
//  Created by Peter Huber on 2020-08-29.
//  Copyright © 2020 Peter Huber. All rights reserved.
//

import Cocoa

class TransformerDescriptionDialog: PCH_DialogBox {
    
    @IBOutlet weak var descriptionTextField: NSTextField!
    var desc:String
    
    init(description:String) {
        
        self.desc = description
        super.init(viewNibFileName: "TransformerDescription", windowTitle: "Transformer Description", hideCancel: false)
    }
    
    override func awakeFromNib() {
        
        self.descriptionTextField.stringValue = self.desc
    }
    
    // override the handleOK function to get the description
    override func handleOk() {
        
        self.desc = self.descriptionTextField.stringValue
        
        // make sure to call the super version of this function to actually handle the OK click
        super.handleOk()
    }
}
