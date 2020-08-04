//
//  TerminalsView.swift
//  AndersenFE_2020
//
//  Created by Peter Huber on 2020-08-03.
//  Copyright © 2020 Peter Huber. All rights reserved.
//

import Cocoa

class TerminalsView: NSView {
    
    var termFields:[NSTextField] = []
    
    func InitializeFields()
    {
        for nextFld in self.termFields
        {
            nextFld.stringValue = "Terminal \(nextFld.tag)"
            
            if nextFld.tag > 2
            {
                nextFld.isHidden = true
            }
        }
    }
    
    func SetTermData(termNum:Int, name:String, displayVolts:Double, VA:Double, connection:Terminal.TerminalConnection)
    {
        if let textFld = self.termFields.first(where: {$0.tag == termNum})
        {
            let displayString = "Terminal \(termNum)\n\(name)\nkV: \(displayVolts / 1000.0)\nMVA:\(VA / 1.0E6)\n\(Terminal.StringForConnection(connection: connection))"
            
            textFld.stringValue = displayString
            textFld.isHidden = false
        }
        else
        {
            // this shouldn't ever happen
            ALog("Undefined terminal!")
        }
    }
    
    override func awakeFromNib() {
        
        for nextView in self.subviews
        {
            if let nextField = nextView as? NSTextField
            {
                self.termFields.append(nextField)
            }
        }
        
        // self.termFields.sort(by: {$0.tag < $1.tag})
        
        DLog("Textfield count: \(termFields.count)")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
    }
    
}
