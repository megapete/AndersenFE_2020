//
//  TransformerDescriptionDialog.swift
//  AndersenFE_2020
//
//  Created by Peter Huber on 2020-08-29.
//  Copyright © 2020 Peter Huber. All rights reserved.
//

import Cocoa

class TransformerDescriptionDialog: PCH_DialogBox, NSControlTextEditingDelegate {
    
    @IBOutlet weak var descriptionTextField: NSTextField!
    
    var desc:String
    
    init(description:String) {
        
        self.desc = description
        DLog("\(self.desc.count)")
        super.init(viewNibFileName: "TransformerDescription", windowTitle: "Transformer Description", hideCancel: false, okIsEnabled: self.desc.count > 0)
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
    
    
    func controlTextDidChange(_ obj: Notification) {
                
        if let txFld = obj.object as? NSTextField
        {
            if txFld == self.descriptionTextField
            {
                if let ok = self.okButton
                {
                    ok.isEnabled = txFld.stringValue.count > 0
                    self.okButtonIsEnabled = ok.isEnabled
                    self.enableOK = ok.isEnabled
                }
            }
        }
        
    }
}
