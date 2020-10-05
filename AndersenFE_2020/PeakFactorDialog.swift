//
//  PeakFactorDialog.swift
//  AndersenFE_2020
//
//  Created by Peter Huber on 2020-10-04.
//  Copyright © 2020 Peter Huber. All rights reserved.
//

import Cocoa

class PeakFactorDialog: PCH_DialogBox, NSControlTextEditingDelegate {

    @IBOutlet weak var xOverRradioButton: NSButton!
    @IBOutlet weak var peakFactorRadioButton: NSButton!
    
    @IBOutlet weak var xOverRtextField: NSTextField!
    @IBOutlet weak var peakFactorTextField: NSTextField!
    
    // These are the "standard" minimum values
    var pkFactor = 1.8
    private var xOverR = 14.0
    
    init(pkFactor:Double?)
    {
        if let initFactor = pkFactor
        {
            if initFactor > 2.0
            {
                self.pkFactor = 2.0
            }
            else if initFactor > 1.8
            {
                self.pkFactor = initFactor
            }
        }
        
        super.init(viewNibFileName: "PeakFactor", windowTitle: "Set Peak Factor", hideCancel: false)
    }
    
    override func awakeFromNib() {
        
        self.peakFactorRadioButton.state = .on
        self.xOverRtextField.isEnabled = false
        
        let pkFormatter = NumberFormatter()
        pkFormatter.minimum = 1.8
        pkFormatter.maximum = 2.0
        pkFormatter.minimumFractionDigits = 3
        pkFormatter.maximumFractionDigits = 3
        self.peakFactorTextField.formatter = pkFormatter
        
        let xorFormatter = NumberFormatter()
        xorFormatter.minimum = 14.0
        xorFormatter.maximum = 1000.0
        xorFormatter.maximumFractionDigits = 2
        self.xOverRtextField.formatter = xorFormatter
    }
    
    /// Given X/R, this function returns K (per C57.12.00) but WITHOUT the √2 multiplier
    static func K(xOverR:Double) -> Double
    {
        let rOverX = 1.0 / xOverR
        let phi = atan(xOverR)
        
        let eTerm = exp(-(phi + π / 2.0) * rOverX)
        let sinTerm = sin(phi)
        
        return max(1.8, 1.0 + eTerm * sinTerm)
    }
    
    @IBAction func handleRadioButton(_ sender: Any) {
        
        if peakFactorRadioButton.state == .on
        {
            peakFactorTextField.isEnabled = true
            xOverRtextField.isEnabled = false
        }
        else
        {
            peakFactorTextField.isEnabled = false
            // peakFactorTextField.doubleValue = PeakFactorDialog.K(xOverR: xOverRtextField.doubleValue)
            xOverRtextField.isEnabled = true
        }
    }
    
    func controlTextDidEndEditing(_ obj: Notification) {
                
        if let txFld = obj.object as? NSTextField
        {
            if txFld == self.xOverRtextField
            {
                self.peakFactorTextField.doubleValue = PeakFactorDialog.K(xOverR: xOverRtextField.doubleValue)
            }
        }
        
    }
    
    override func handleOk() {
        
        // we need this to make sure that the pkFactor ivar is set if the user hits OK immediately afte entering
        if self.peakFactorRadioButton.state == .off
        {
            self.peakFactorTextField.doubleValue = PeakFactorDialog.K(xOverR: xOverRtextField.doubleValue)
        }
        
        self.pkFactor = self.peakFactorTextField.doubleValue
        
        super.handleOk()
    }
    
}
