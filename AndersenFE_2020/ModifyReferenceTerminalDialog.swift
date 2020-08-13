//
//  ModifyReferenceTerminalDialog.swift
//  AndersenFE_2020
//
//  Created by Peter Huber on 2020-08-12.
//  Copyright © 2020 Peter Huber. All rights reserved.
//

import Cocoa

class ModifyReferenceTerminalDialog: PCH_DialogBox {

    @IBOutlet weak var term1: NSButton!
    @IBOutlet weak var term2: NSButton!
    @IBOutlet weak var term3: NSButton!
    @IBOutlet weak var term4: NSButton!
    @IBOutlet weak var term5: NSButton!
    @IBOutlet weak var term6: NSButton!
    var termButtons:[NSButton] = []
    var currentRefIndex:Int = -1
    
    /// oldTerminal must be either 'nil' or an Int from 1...6
    init(oldTerminal:Int?) {
        
        if let oldRefTerm = oldTerminal
        {
            self.currentRefIndex = oldRefTerm - 1
        }
        
        super.init(viewNibFileName: "ModifyReferenceTerminal", windowTitle: "Modify Reference Terminal", hideCancel: false)
    }
    
    override func awakeFromNib() {
        
        self.termButtons = [self.term1, self.term2, self.term3, self.term4, self.term5, self.term6]
        
        if self.currentRefIndex >= 0
        {
            self.termButtons[self.currentRefIndex].state = .on
        }
    }
    
    @IBAction func handleButtonChange(_ sender: Any) {
        
        for i in 0..<6
        {
            if self.termButtons[i].state == .on
            {
                self.currentRefIndex = i
                
                break
            }
        }
    }
}
