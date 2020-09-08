//
//  AmpTurnsDistributionDialog.swift
//  AndersenFE_2020
//
//  Created by Peter Huber on 2020-08-08.
//  Copyright © 2020 Peter Huber. All rights reserved.
//

// This Dialog Box is used to find the ampere-turn distribution in transformers with 3 or more terminals. The user must enter the percentages, or use the provided "Balance" buttons so that the total NI equals zero. The Ok button is disabled whenever the NI does NOT equal zero. The calling routine should access the 'currentTerminalPercentages' array to get the final distribution upon exit, where the index 'i' into the array is for the (Andersen) terminal 'i+1'.

import Cocoa

class AmpTurnsDistributionDialog: PCH_DialogBox, NSTextFieldDelegate {
    
    // tag offset for UI elements
    let tagBase = 100
    
    // constants
    let minValue = -100.0
    let maxValue = 100.0

    // Outlets into the view
    
    // labels
    @IBOutlet weak var term1Label: NSTextField!
    @IBOutlet weak var term2Label: NSTextField!
    @IBOutlet weak var term3Label: NSTextField!
    @IBOutlet weak var term4Label: NSTextField!
    @IBOutlet weak var term5Label: NSTextField!
    @IBOutlet weak var term6Label: NSTextField!
    var labels:[NSTextField] = []
    var labelStrings:[String] = ["", "", "", "", "", ""]
    
    // percent labels
    @IBOutlet weak var term1percentLabel: NSTextField!
    @IBOutlet weak var term2percentLabel: NSTextField!
    @IBOutlet weak var term3percentLabel: NSTextField!
    @IBOutlet weak var term4percentLabel: NSTextField!
    @IBOutlet weak var term5percentLabel: NSTextField!
    @IBOutlet weak var term6percentLabel: NSTextField!
    var percentLabels:[NSTextField] = []
    
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
    
    let termsToShow:Set<Int>
    
    // warning label
    @IBOutlet weak var warningLabel: NSTextField!
    
    var currentTerminalPercentages:[Double] = Array(repeating: 0.0, count: 6)
    let fixedTerm:Int?
    let autoCalcTerm:Int?
    
    init(termsToShow:Set<Int>, fixedTerm:Int?, autoCalcTerm:Int?, term1:Double, term2:Double, term3:Double, term4:Double = 0.0, term5:Double = 0.0, term6:Double = 0.0, term1name:String? = nil, term2name:String? = nil, term3name:String? = nil, term4name:String? = nil, term5name:String? = nil, term6name:String? = nil, hideCancel:Bool = false)
    {
        self.currentTerminalPercentages[0] = min(maxValue, max(minValue, term1))
        self.currentTerminalPercentages[1] = min(maxValue, max(minValue, term2))
        self.currentTerminalPercentages[2] = min(maxValue, max(minValue, term3))
        self.currentTerminalPercentages[3] = min(maxValue, max(minValue, term4))
        self.currentTerminalPercentages[4] = min(maxValue, max(minValue, term5))
        self.currentTerminalPercentages[5] = min(maxValue, max(minValue, term6))
        self.fixedTerm = fixedTerm
        if fixedTerm != nil && autoCalcTerm != nil && fixedTerm! == autoCalcTerm!
        {
            DLog("It is illegal to set a terminal as both FIXED and AUTOCALCULATE. Defaulting to FIXED")
            self.autoCalcTerm = nil
        }
        else
        {
            self.autoCalcTerm = autoCalcTerm
        }
        
        for i in 0..<6
        {
            var labelString = "Terminal \(i+1) "
            
            switch i {
            case 0:
                if let name = term1name
                {
                    labelString += "(\(name))"
                }
            case 1:
                if let name = term2name
                {
                    labelString += "(\(name))"
                }
            case 2:
                if let name = term3name
                {
                    labelString += "(\(name))"
                }
            case 3:
                if let name = term4name
                {
                    labelString += "(\(name))"
                }
            case 4:
                if let name = term5name
                {
                    labelString += "(\(name))"
                }
            case 5:
                if let name = term6name
                {
                    labelString += "(\(name))"
                }
            default:
                break
            }
            
            self.labelStrings[i] = labelString
        }
        
        self.termsToShow = termsToShow
        
        super.init(viewNibFileName: "AmpTurnsDistribution", windowTitle: "AmpTurns Distribution", hideCancel: false)
    }
    
    convenience init(termsToShow:Set<Int>, termNames:[String?], fixedTerm:Int? = nil, autoCalcTerm:Int? = nil, termPercentages:[Double], hideCancel:Bool = false)
    {
        self.init(termsToShow: termsToShow, fixedTerm:fixedTerm, autoCalcTerm:autoCalcTerm, term1:termPercentages[0], term2:termPercentages[1], term3:termPercentages[2], term4:termPercentages[3], term5:termPercentages[4], term6:termPercentages[5], term1name:termNames[0], term2name:termNames[1], term3name:termNames[2], term4name:termNames[3], term5name:termNames[4], term6name:termNames[5], hideCancel:hideCancel)
    }
    
    func CheckAmpTurns() -> Double
    {
        if let autoTerm = self.autoCalcTerm
        {
            let autoIndex = autoTerm - 1
            
            var result = 0.0
            
            for i in 0..<6
            {
                if i == autoIndex
                {
                    continue
                }
                
                result += self.currentTerminalPercentages[i]
            }
            
            self.currentTerminalPercentages[autoIndex] = -result
            
            self.niTextFields[autoIndex].stringValue = "\(-result)"
        }
        
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
            self.enableOK = ampTurns == 0.0
        }
        else
        {
            self.enableOK = ampTurns == 0.0
        }
        
        return ampTurns
    }
    
    override func awakeFromNib() {
        
        self.term1TextField.doubleValue = currentTerminalPercentages[0]
        self.niTextFields.append(self.term1TextField)
        self.balanceButtons.append(self.term1BalanceButton)
        self.labels.append(self.term1Label)
        self.percentLabels.append(self.term1percentLabel)
        
        self.term2TextField.doubleValue = currentTerminalPercentages[1]
        self.niTextFields.append(self.term2TextField)
        self.balanceButtons.append(self.term2BalanceButton)
        self.labels.append(self.term2Label)
        self.percentLabels.append(self.term2percentLabel)
        
        self.term3TextField.doubleValue = currentTerminalPercentages[2]
        self.niTextFields.append(self.term3TextField)
        self.balanceButtons.append(self.term3BalanceButton)
        self.labels.append(self.term3Label)
        self.percentLabels.append(self.term3percentLabel)
        
        self.term4TextField.doubleValue = currentTerminalPercentages[3]
        self.niTextFields.append(self.term4TextField)
        self.balanceButtons.append(self.term4BalanceButton)
        self.labels.append(self.term4Label)
        self.percentLabels.append(self.term4percentLabel)
        
        self.term5TextField.doubleValue = currentTerminalPercentages[4]
        self.niTextFields.append(self.term5TextField)
        self.balanceButtons.append(self.term5BalanceButton)
        self.labels.append(self.term5Label)
        self.percentLabels.append(self.term5percentLabel)
        
        self.term6TextField.doubleValue = currentTerminalPercentages[5]
        self.niTextFields.append(self.term6TextField)
        self.balanceButtons.append(self.term6BalanceButton)
        self.labels.append(self.term6Label)
        self.percentLabels.append(self.term6percentLabel)
        
        // Set up a formatter to clamp the allowable values in the text fields to -100...+100
        let textFieldFormatter = NumberFormatter()
        textFieldFormatter.minimum = NSNumber(floatLiteral: -100.0)
        textFieldFormatter.maximum = NSNumber(floatLiteral: 100.0)
        
        for i in 0..<6
        {
            self.labels[i].stringValue = self.labelStrings[i]
            
            self.niTextFields[i].delegate = self
            self.niTextFields[i].formatter = textFieldFormatter
            
            if self.termsToShow.contains(i + 1)
            {
                self.niTextFields[i].isHidden = false
                self.balanceButtons[i].isHidden = false
                self.labels[i].isHidden = false
                self.percentLabels[i].isHidden = false
                
                var disableTerminal = -1
                if let fixedDisable = self.fixedTerm
                {
                    disableTerminal = fixedDisable
                }
                else if let calcDisable = self.autoCalcTerm
                {
                    disableTerminal = calcDisable
                }
                
                if i + 1 == disableTerminal
                {
                    self.niTextFields[i].isEnabled = false
                }
                
            }
            else
            {
                self.niTextFields[i].isHidden = true
                self.balanceButtons[i].isHidden = true
                self.labels[i].isHidden = true
                self.percentLabels[i].isHidden = true
            }
        }
        
        let _ = self.CheckAmpTurns()
    }
    
    @IBAction func balanceButtonPushed(_ sender: Any) {
        
        let button:NSButton = sender as! NSButton
        let index = button.tag - tagBase
        
        self.doBalanceTerminal(termIndex: index)
    }
    
    func doBalanceTerminal(termIndex:Int) {
        
        var niToFix = self.currentTerminalPercentages[termIndex]
        
        let ampTurns = self.CheckAmpTurns()
        
        if ampTurns == 0.0
        {
            return
        }
        
        niToFix -= ampTurns
        
        self.currentTerminalPercentages[termIndex] = niToFix
        self.niTextFields[termIndex].doubleValue = niToFix
        
        // check
        let _ = self.CheckAmpTurns()
    }
    
    @IBAction func sliderMoved(_ sender: Any) {
        
        let slider:NSSlider = sender as! NSSlider
        
        self.currentTerminalPercentages[slider.tag - tagBase] = slider.doubleValue
        self.niTextFields[slider.tag - tagBase].doubleValue = slider.doubleValue
        
        let _ = self.CheckAmpTurns()
        
        // DLog("New value: \(slider.doubleValue)")
    }
    
    func controlTextDidChange(_ obj: Notification) {
        
        if let txFld = obj.object as? NSTextField
        {
            let newValue = min(maxValue, max(minValue, txFld.doubleValue))
            
            if txFld.tag >= 100 && txFld.tag <= 105
            {
                if let autoTerm = self.autoCalcTerm
                {
                    if txFld.tag - tagBase == autoTerm - 1
                    {
                        return
                    }
                }
                
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
