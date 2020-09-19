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
        case impedance = 3
        case warnings = 4
    }
    
    enum WarningLevel {
        
        case information    // green
        case caution        // yellow
        case critical       // red
    }
    
    struct WarningData {
        
        let string:String
        let level:WarningLevel
        let wordsToHighlight:[Int]
    }
    
    var dataFields:[NSTextField] = []
    
    var warningMessage:NSMutableAttributedString = NSMutableAttributedString()
    
    func InitializeFields()
    {
        SetVpN(newVpN: 0.0, refTerm: nil)
        
        self.ResetWarnings()
    }
    
    func ResetWarnings()
    {
        self.warningMessage = NSMutableAttributedString(string: "Warnings:")
    }
    
    func AddWarning(warning:WarningData)
    {
        let stringComponents = warning.string.components(separatedBy: " ")
        
        let newWarning = NSMutableAttributedString(string: warning.string)
        
        for nextWordIndex in warning.wordsToHighlight
        {
            if nextWordIndex < stringComponents.count
            {
                let wordToFind = stringComponents[nextWordIndex]
                
                // check for multiple copies of the word
                var rangeIndex = 0
                for i in 0..<stringComponents.count
                {
                    if stringComponents[i] == wordToFind
                    {
                        if i == nextWordIndex
                        {
                            break
                        }
                        else
                        {
                            rangeIndex += 1
                        }
                    }
                }
                
                // Use the extension from GlobalDefs to get the ranges of the word
                let swiftWordRange = warning.string.ranges(of: wordToFind)[rangeIndex]
                // We need to convert the Swift String range to an NSRange manually. I can't actually find the documentation for this functiom It comes from https://stackoverflow.com/questions/27040924/nsrange-from-swift-range (Accepted Answer, Update for Swift 4)
                let wordRange = NSRange(swiftWordRange, in: warning.string)
                
                let wordColor = (warning.level == .information ? NSColor.green : (warning.level == .caution ? NSColor.yellow : NSColor.red))
                
                newWarning.addAttribute(.foregroundColor, value: wordColor, range: wordRange)
            }
        }
        
        self.warningMessage.append(NSAttributedString(string: "\n\n"))
        self.warningMessage.append(newWarning)
    }
    
    func SetImpedance(newImpPU:Double?, baseMVA:Double?)
    {
        var impString = "-ERROR-"
        var mvaString = ""
        
        if let imp = newImpPU
        {
            impString = String(format: "%.2f", imp * 100.0)
            
            if let mva = baseMVA
            {
                mvaString = String(format: "\n@ %.3f MVA", mva)
            }
        }
        
        let impField = "Impedance:\n\(impString)%\(mvaString)"
        
        self.SetFieldString(fieldID: .impedance, txt: impField)
    }
    
    func SetAmpereTurns(newNI:Double?, refTerm:Int?)
    {
        var refTermString = "Unassigned"
        if let terminal = refTerm
        {
            refTermString = "\(terminal)"
        }
        
        var niString = "-ERROR-"
        if let NI = newNI
        {
            niString = String(format: "%.1f", NI)
        }
        
        let niField = "Ampere Turns\nRef. Terminal: \(refTermString)\nNI: \(niString)"
        
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
    
    func UpdateWarningField()
    {
        for nextField in self.dataFields
        {
            if nextField.tag == fieldIDs.warnings.rawValue
            {
                nextField.attributedStringValue = self.warningMessage
                return
            }
        }
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
                
                if nextField.tag == fieldIDs.warnings.rawValue
                {
                    nextField.attributedStringValue = self.warningMessage
                }
            }
        }
        
        // self.termFields.sort(by: {$0.tag < $1.tag})
        
        // DLog("Textfield count: \(dataFields.count)")
    }
    

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
    }
    
}
