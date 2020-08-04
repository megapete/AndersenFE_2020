//
//  TerminalsView.swift
//  AndersenFE_2020
//
//  Created by Peter Huber on 2020-08-03.
//  Copyright © 2020 Peter Huber. All rights reserved.
//

import Cocoa

class TerminalsView: NSView {
    
    static let termColors:[NSColor] = [.red, .green, .orange, .blue, .purple, .brown]
    
    var termFields:[NSTextField] = []
    
    var referenceTerminal = 2
    
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
    
    func SetTermData(termNum:Int, name:String, displayVolts:Double, VA:Double, connection:Terminal.TerminalConnection, isReference:Bool = false)
    {
        if let textFld = self.termFields.first(where: {$0.tag == termNum})
        {
            let volts = String(format: "%0.3f", displayVolts / 1000.0)
            
            let displayString = "Terminal \(termNum)\n\(name)\nkV: \(volts)\nMVA: \(VA / 1.0E6)\n\(Terminal.StringForConnection(connection: connection))"
            
            textFld.stringValue = displayString
            textFld.isHidden = false
            if isReference
            {
                self.referenceTerminal = termNum
            }
            
            self.needsDisplay = true
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

        let baselineWidth:CGFloat = 1.5
        // Drawing code here.
        for i in 0..<self.termFields.count
        {
            let nextFld = self.termFields[i]
            
            if nextFld.isHidden
            {
                continue
            }
            
            let fldColor = TerminalsView.termColors[i]
            
            let useLineWidth = (self.referenceTerminal == nextFld.tag ? 5.0 * baselineWidth : baselineWidth)
            
            fldColor.set()
            
            let boxPath = NSBezierPath(rect: nextFld.frame)
            boxPath.lineWidth = useLineWidth
            
            boxPath.stroke()
        }
    }
    
}
