//
//  DataView.swift
//  AndersenFE_2020
//
//  Created by Peter Huber on 2020-08-05.
//  Copyright © 2020 Peter Huber. All rights reserved.
//

import Cocoa

class DataView: NSView {
    
    enum fieldIDs:Int {
        case vpn = 1
        case NI = 2
    }
    
    var dataFields:[NSTextField] = []
    
    func InitializeFields()
    {
        SetVpN(newVpN: 0.0, refTerm: nil)
    }
    
    func SetAmpereTurns(newNI:Double?)
    {
        var niString = "-ERROR-"
        if let NI = newNI
        {
            niString = String(format: "%.1f", NI)
        }
        
        let niField = "Ampere Turns\nNI: \(niString)"
        
        self.SetFieldString(fieldID: .NI, txt: niField)
    }
    
    func SetVpN(newVpN:Double, refTerm:Int?)
    {
        var refTermString = "Unassigned"
        if let terminal = refTerm
        {
            refTermString = "\(terminal)"
        }
        
        let vpnString = String(format: "%.3f", newVpN)
        let vpnField = "Volts per Turn\nRef. Terminal: \(refTermString)\nVPN: \(vpnString)"
        
        self.SetFieldString(fieldID: .vpn, txt: vpnField)
    }
    
    func SetFieldString(fieldID:fieldIDs, txt:String)
    {
        let tagToFind = fieldID.rawValue
        
        for nextField in self.dataFields
        {
            if nextField.tag == tagToFind
            {
                nextField.stringValue = txt
            }
        }
    }
    
    override func awakeFromNib() {
        
        for nextView in self.subviews
        {
            if let nextField = nextView as? NSTextField
            {
                self.dataFields.append(nextField)
            }
        }
        
        // self.termFields.sort(by: {$0.tag < $1.tag})
        
        DLog("Textfield count: \(dataFields.count)")
    }
    

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
    }
    
}
