//
//  AmpTurnsDistributionDialog.swift
//  AndersenFE_2020
//
//  Created by Peter Huber on 2020-08-08.
//  Copyright © 2020 Peter Huber. All rights reserved.
//

import Cocoa

class AmpTurnsDistributionDialog: PCH_DialogBox, NSTextFieldDelegate {
    
    // tag offset for UI elements
    let tagBase = 100
    
    // constants
    let minValue = -100.0
    let maxValue = 100.0

    // Outlets into the view
    
    // sliders
    @IBOutlet weak var term1Slider: NSSlider!
    @IBOutlet weak var term2Slider: NSSlider!
    @IBOutlet weak var term3Slider: NSSlider!
    @IBOutlet weak var term4Slider: NSSlider!
    @IBOutlet weak var term5Slider: NSSlider!
    @IBOutlet weak var term6Slider: NSSlider!
    var sliders:[NSSlider] = []
    
    // text fields
    @IBOutlet weak var term1TextField: NSTextField!
    @IBOutlet weak var term2TextField: NSTextField!
    @IBOutlet weak var term3TextField: NSTextField!
    @IBOutlet weak var term4TextField: NSTextField!
    @IBOutlet weak var term5TextField: NSTextField!
    @IBOutlet weak var term6TextField: NSTextField!
    var niTextFields:[NSTextField] = []
    
    // 'balance' buttons
    @IBOutlet weak var term1BalanceButton: NSButton!
    @IBOutlet weak var term2BalanceButton: NSButton!
    @IBOutlet weak var term3BalanceButton: NSButton!
    @IBOutlet weak var term4BalanceButton: NSButton!
    @IBOutlet weak var term5BalanceButton: NSButton!
    @IBOutlet weak var term6BalanceButton: NSButton!
    var balanceButtons:[NSButton] = []
    
    // warning label
    @IBOutlet weak var warningLabel: NSTextField!
    
    
    
    var currentTerminalPercentages:[Double] = Array(repeating: 0.0, count: 6)
    
    init(term1:Double, term2:Double, term3:Double, term4:Double = 0.0, term5:Double = 0.0, term6:Double = 0.0)
    {
        self.currentTerminalPercentages[0] = min(maxValue, max(minValue, term1))
        self.currentTerminalPercentages[1] = min(maxValue, max(minValue, term2))
        self.currentTerminalPercentages[2] = min(maxValue, max(minValue, term3))
        self.currentTerminalPercentages[3] = min(maxValue, max(minValue, term4))
        self.currentTerminalPercentages[4] = min(maxValue, max(minValue, term5))
        self.currentTerminalPercentages[5] = min(maxValue, max(minValue, term6))
        
        super.init(viewNibFileName: "AmpTurnsDistribution", windowTitle: "AmpTurns Distribution", hideCancel: false)
    }
    
    func CheckAmpTurns() -> Double
    {
        let ampTurns = self.currentTerminalPercentages.reduce(0.0, +)
        
        if ampTurns == 0.0
        {
            self.warningLabel.isHidden = true
        }
        else
        {
            self.warningLabel.isHidden = false
        }
        
        if let ok = self.okButton
        {
            ok.isEnabled = ampTurns == 0.0
        }
        
        return ampTurns
    }
    
    override func awakeFromNib() {
        
        self.term1Slider.doubleValue = currentTerminalPercentages[0]
        self.sliders.append(self.term1Slider)
        self.term1TextField.doubleValue = currentTerminalPercentages[0]
        self.niTextFields.append(self.term1TextField)
        self.balanceButtons.append(self.term1BalanceButton)
        
        self.term2Slider.doubleValue = currentTerminalPercentages[1]
        self.sliders.append(self.term2Slider)
        self.term2TextField.doubleValue = currentTerminalPercentages[1]
        self.niTextFields.append(self.term2TextField)
        self.balanceButtons.append(self.term2BalanceButton)
        
        self.term3Slider.doubleValue = currentTerminalPercentages[2]
        self.sliders.append(self.term3Slider)
        self.term3TextField.doubleValue = currentTerminalPercentages[2]
        self.niTextFields.append(self.term3TextField)
        self.balanceButtons.append(self.term3BalanceButton)
        
        self.term4Slider.doubleValue = currentTerminalPercentages[3]
        self.sliders.append(self.term4Slider)
        self.term4TextField.doubleValue = currentTerminalPercentages[3]
        self.niTextFields.append(self.term4TextField)
        self.balanceButtons.append(self.term4BalanceButton)
        
        self.term5Slider.doubleValue = currentTerminalPercentages[4]
        self.sliders.append(self.term5Slider)
        self.term5TextField.doubleValue = currentTerminalPercentages[4]
        self.niTextFields.append(self.term5TextField)
        self.balanceButtons.append(self.term5BalanceButton)
        
        self.term6Slider.doubleValue = currentTerminalPercentages[5]
        self.sliders.append(self.term6Slider)
        self.term6TextField.doubleValue = currentTerminalPercentages[5]
        self.niTextFields.append(self.term6TextField)
        self.balanceButtons.append(self.term6BalanceButton)
        
        for nextFld in self.niTextFields
        {
            nextFld.delegate = self
        }
        
        let _ = self.CheckAmpTurns()
    }
    
    @IBAction func balanceButtonPushed(_ sender: Any) {
        
        let button:NSButton = sender as! NSButton
        let index = button.tag - tagBase
        
        var niToFix = self.currentTerminalPercentages[index]
        
        let ampTurns = self.CheckAmpTurns()
        
        if ampTurns == 0.0
        {
            return
        }
        
        niToFix -= ampTurns
        
        self.currentTerminalPercentages[index] = niToFix
        self.sliders[index].doubleValue = niToFix
        self.niTextFields[index].doubleValue = niToFix
        
        // check
        let _ = self.CheckAmpTurns()
    }
    
    
    @IBAction func sliderMoved(_ sender: Any) {
        
        let slider:NSSlider = sender as! NSSlider
        
        self.currentTerminalPercentages[slider.tag - tagBase] = slider.doubleValue
        self.niTextFields[slider.tag - tagBase].doubleValue = slider.doubleValue
        
        let _ = self.CheckAmpTurns()
        
        DLog("New value: \(slider.doubleValue)")
    }
    
    func controlTextDidEndEditing(_ obj: Notification) {
        
        if let txFld = obj.object as? NSTextField
        {
            let newValue = min(maxValue, max(minValue, txFld.doubleValue))
            
            if txFld.tag >= 100 && txFld.tag <= 105
            {
                self.sliders[txFld.tag - tagBase].doubleValue = newValue
                self.currentTerminalPercentages[txFld.tag - tagBase] = newValue
            }
            else
            {
                return
            }
            
            let _ = self.CheckAmpTurns()
        }
    }
    
}
