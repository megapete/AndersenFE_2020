//
//  PeakFactorDialog.swift
//  AndersenFE_2020
//
//  Created by Peter Huber on 2020-10-04.
//  Copyright © 2020 Peter Huber. All rights reserved.
//

import Cocoa

class PeakFactorDialog: PCH_DialogBox {

    @IBOutlet weak var xOverRradioButton: NSButton!
    @IBOutlet weak var peakFactorRadioButton: NSButton!
    
    @IBOutlet weak var xOverRtextField: NSTextField!
    @IBOutlet weak var peakFactorTextField: NSTextField!
    
    // These are the "standard" minimum values
    var pkFactor = 1.8
    var xOverR = 14.0
    
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
    
    /// Given X/R, this function returns K (per C57.12.00) but WITHOUT the √2 multiplier
    static func K(xOverR:Double) -> Double
    {
        let rOverX = 1.0 / xOverR
        let phi = atan(xOverR)
        
        let eTerm = exp(-(phi + π / 2.0) * rOverX)
        let sinTerm = sin(phi)
        
        return 1.0 + eTerm * sinTerm
    }
    
    @IBAction func handleRadioButton(_ sender: Any) {
    }
    
}
