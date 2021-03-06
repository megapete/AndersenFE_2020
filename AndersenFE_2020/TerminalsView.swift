//
//  TerminalsView.swift
//  AndersenFE_2020
//
//  Created by Peter Huber on 2020-08-03.
//  Copyright © 2020 Peter Huber. All rights reserved.
//

import Cocoa

class TerminalsView: NSView, NSMenuItemValidation {
    
    static let termColors:[NSColor] = [.red, .green, .orange, .blue, .purple, .brown]
    
    var termFields:[NSTextField] = []
    
    let peakFactorTag = -1
    var peakFactorField:NSTextField? = nil
    
    let impForceCalcsTag = -2
    var impForceCalcsField:NSTextField? = nil
    
    let systemGVAtag = -3
    var systemGVAfield:NSTextField? = nil
    
    var referenceTerminal = 2
    
    weak var appController:AppController? = nil
    
    // contextual menu
    // NOTE TO FUTURE ME: You need to create this variable FIRST (as an @IBOutlet) then connect it back to the NSMenu created with IB back in the MainMenu.xib file.
    @IBOutlet weak var contextualMenu:NSMenu!
    @IBOutlet weak var SetVpnRefTermMenuItem:NSMenuItem!
    @IBOutlet weak var SetAmpTurnRefTermMenuItem:NSMenuItem!
    @IBOutlet weak var SetRefMVAMenuItem:NSMenuItem!
    @IBOutlet weak var SetNIDistributionMenuItem:NSMenuItem!
    @IBOutlet weak var addTxfoToOutputListMenuItem:NSMenuItem!
    
    func InitializeFields(appController:AppController)
    {
        for nextFld in self.termFields
        {
            nextFld.stringValue = "Terminal \(nextFld.tag)"
            
            if nextFld.tag > 2
            {
                nextFld.isHidden = true
            }
        }
        
        self.appController = appController
        
        self.UpdateScData()
    }
    
    func SetTermData(termNum:Int, name:String, displayVolts:Double, VA:Double, connection:Terminal.TerminalConnection, isReference:Bool = false)
    {
        if let textFld = self.termFields.first(where: {$0.tag == termNum})
        {
            let volts = String(format: "%0.3f", displayVolts / 1000.0)
            let va = String(format: "%0.3f", fabs(VA / 1.0E6))
            
            let displayString = "Terminal \(termNum)\n\(name)\nkV: \(volts)\nMVA: \(va)\n\(Terminal.StringForConnection(connection: connection))"
            
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
    
    func UpdateScData()
    {
        self.SetPeakFactor()
        self.SetImpedanceForForceCalcs()
        self.SetSystemGVA()
    }
    
    func SetPeakFactor()
    {
        guard let field = self.peakFactorField, let appCtrl = self.appController, let txfo = appCtrl.currentTxfo else
        {
            return
        }
        
        let factor = String(format: "Peak Factor\n%0.3f x √2", txfo.scFactor)
        field.stringValue = factor
    }
    
    func SetImpedanceForForceCalcs()
    {
        guard let field = self.impForceCalcsField, let appCtrl = self.appController, let txfo = appCtrl.currentTxfo else
        {
            return
        }
        
        var factor = "Impedance Used for\nForce Calculations\n"
        
        if let results = txfo.scResults
        {
            factor += String(format: "%0.2f %%", results.puForceImpedance * 100.0)
        }
        else
        {
            factor += "N/A"
        }
        
        field.stringValue = factor
    }
    
    func SetSystemGVA()
    {
        guard let field = self.systemGVAfield, let appCtrl = self.appController, let txfo = appCtrl.currentTxfo else
        {
            return
        }
        
        var factor = "System Strength\n"
        
        if txfo.systemGVA != 0.0
        {
            factor += String(format: "%0.1f GVA", txfo.systemGVA)
        }
        else
        {
            factor += "Infinite"
        }
        
        field.stringValue = factor
    }
    
    override func awakeFromNib() {
        
        for nextView in self.subviews
        {
            if let nextField = nextView as? NSTextField
            {
                if nextField.tag > 0
                {
                    self.termFields.append(nextField)
                }
                else
                {
                    // Peak factor
                    if nextField.tag == self.peakFactorTag
                    {
                        self.peakFactorField = nextField
                        let formatter = NumberFormatter()
                        formatter.minimum = 1.8
                        formatter.maximum = 2.0
                        self.peakFactorField!.formatter = formatter
                    }
                    else if nextField.tag == self.impForceCalcsTag
                    {
                        self.impForceCalcsField = nextField
                        let formatter = NumberFormatter()
                        formatter.minimum = 0.1
                        formatter.maximum = 100.0
                        self.impForceCalcsField!.formatter = formatter
                    }
                    else if nextField.tag == self.systemGVAtag
                    {
                        self.systemGVAfield = nextField
                        let formatter = NumberFormatter()
                        formatter.minimum = 0.0
                        formatter.maximum = 100.0
                        self.systemGVAfield!.formatter = formatter
                    }
                }
            }
        }
        
        // self.termFields.sort(by: {$0.tag < $1.tag})
        
        // DLog("Textfield count: \(termFields.count)")
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
    
    // MARK: Contextual Menu handling
    var rightClickPoint = NSPoint()
    
    override func rightMouseDown(with event: NSEvent) {
        // DLog("Got right-mouse")
        
        let eventLocation = event.locationInWindow
        self.rightClickPoint = self.convert(eventLocation, from: nil)
        // DLog("\(rightClickPoint)")
        
        NSMenu.popUpContextMenu(self.contextualMenu, with: event, for: self)
    }
    
    @IBAction func handleSetTxfoDescription(_ sender: Any) {
        
        guard let appCtrl = self.appController else
        {
            return
        }
        
        appCtrl.handleSetTxfoDesc(sender)
    }
    
    @IBAction func handleSetAmpTurnsRefTerm(_ sender: Any) {
        
        guard let appCtrl = self.appController else
        {
            return
        }
        
        for nextFld in self.termFields
        {
            if nextFld.frame.contains(self.rightClickPoint)
            {
                appCtrl.doSetAmpTurnReferenceTerminal(refTerm: nextFld.tag)
            }
        }
    }
    
    
    @IBAction func handleVpnSetRefTerm(_ sender: Any) {
        
        guard let appCtrl = self.appController else
        {
            return
        }
        
        for nextFld in self.termFields
        {
            if nextFld.frame.contains(self.rightClickPoint)
            {
                appCtrl.doSetVpnReferenceTerminal(refTerm: nextFld.tag)
            }
        }
    }
    
    @IBAction func handleSetRefMVA(_ sender: Any) {
        
        guard let appCtrl = self.appController else
        {
            return
        }
        
        appCtrl.handleSetReferenceMVA(sender)
    }
    
    @IBAction func handleSetRefVoltage(_ sender: Any) {
        
        guard let appCtrl = self.appController else
        {
            return
        }
        
        appCtrl.handleSetRefTermVoltage(sender)
    }
    
    @IBAction func handleSetNIDist(_ sender: Any) {
        
        guard let appCtrl = self.appController else
        {
            return
        }
        
        appCtrl.handleSetAmpTurnDistribution(sender)
    }
    
    @IBAction func handleAddTxfoToOutputList(_ sender: Any) {
        
        guard let appCtrl = self.appController else
        {
            return
        }
        
        appCtrl.handleAddTxfoOutput(self)
    }
    
    
    
    // MARK: Context Menu validation
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        
        guard let appCtrl = self.appController else
        {
            return false
        }
        
        guard let txfo = appCtrl.currentTxfo else
        {
            return false
        }
        
        guard txfo.vpnRefTerm != nil else
        {
            return false
        }
        
        if menuItem == self.SetVpnRefTermMenuItem || menuItem == self.SetAmpTurnRefTermMenuItem
        {
            for nextFld in self.termFields
            {
                if !nextFld.isHidden && nextFld.frame.contains(self.rightClickPoint)
                {
                    return true
                }
            }
            
            return false
        }
        else if menuItem == self.SetNIDistributionMenuItem
        {
            return txfo.AvailableTerminals().count > 2
        }
        
        return true
    }
    
}
