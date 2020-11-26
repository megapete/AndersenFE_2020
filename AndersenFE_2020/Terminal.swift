//
//  Terminal.swift
//  AndersenFE_2020
//
//  Created by Peter Huber on 2020-07-18.
//  Copyright © 2020 Peter Huber. All rights reserved.
//

import Foundation

/// The Terminal class basically wraps the data from the first page of the Excel document
class Terminal: Codable
{
    /// A descriptive String for easily identifying the Terminal (ie: "LV", "HV", etc)
    var name:String
    
    private var nominalLegVoltsStore:Double
    
    /// The line-line (line-neutral for single-phase) voltage of the terminal in volts.
    /// Note 1) This should be the "corrected" value for parallel-stacked windings).
    /// Note 2) This should be maintained as the current voltage based on the current V/N by calling the "SetNominalVoltsAndVA() routine
    var nominalLineVolts:Double {
        
        get {
            
            if self.connection == .auto_series
            {
                return self.nominalLegVoltsStore * self.connectionFactor * self.autoFactor
            }
            
            return self.nominalLegVoltsStore * self.connectionFactor
        }
    }
    
    /// The original no-load voltage for the terminal (usually whatever was in the XL design file, NOT corrected for double axial stacks)
    let noloadLegVoltage:Double
    
    /// The total (1-ph or 3-ph) VA for the Terminal. This is the ACTUAL VA for auto-connected windings
    var VA:Double
    
    /// The leg VA for the Terminal. This is the ACTUAL VA flowing in the winding.
    var legVA:Double {
        get {
            
            return self.VA / self.phaseFactor
        }
    }
    
    /// Phase factor for the terminal (1, 2 or 3)
    var phaseFactor:Double {
        get {
            
            return (self.connection == .single_phase_one_leg ? 1.0 : (self.connection == .single_phase_two_legs ? 2.0 : 3.0))
        }
    }
    
    var connectionFactor:Double {
        get {
            
            return (self.connection == .wye || self.connection == .auto_common || self.connection == .auto_series ? SQRT3 : 1.0)
        }
    }
    
    /// It is the calling routine's (the one that creates the Terminal) responsibility to set this factor for either auto_series or auto_common connected windings. The ratio is (seriesTurns + commonTurns) / seriesTurns
    var autoFactor:Double = 1.0
    
    /// The nominal leg amps of the Terminal (winding). These are the ACTUAL amps flowing in the winding. If nominalLineVolts is 0, this function returns 0
    var nominalAmps:Double {
        get {
            
            if self.nominalLineVolts < 0.1
            {
                return 0.0
            }
            
            let result = self.legVA / (self.nominalLineVolts / self.connectionFactor)
            
            return result
        }
    }
    
    /// Possible Terminal connections
    enum TerminalConnection:Int, Codable {
        case single_phase_one_leg
        case single_phase_two_legs
        case wye
        case delta
        case auto_common
        case auto_series
        case zig
        case zag
    }
    
    static func StringForConnection(connection:TerminalConnection) -> String
    {
        if connection == .wye
        {
            return "Wye"
        }
        else if connection == .delta
        {
            return "Delta"
        }
        else if connection == .auto_common
        {
            return "Auto-Common"
        }
        else if connection == .auto_series
        {
            return "Auto-Series"
        }
        else if connection == .zig
        {
            return "Zig"
        }
        else if connection == .zag
        {
            return "Zag"
        }
        
        return "-ERROR-"
    }
    
    /// The connection to use for this Terminal
    var connection:TerminalConnection
    
    /// The current direction for this Terminal. Note that a value of 0 for this property is ILLEGAL.
    var currentDirection:Int
    
    /// The Andersen-file Terminal number
    var andersenNumber:Int
    
    /// The winding associated with this terminal
    weak var winding:Winding? = nil
    
    /// Designated initializer for the Terminal class
    /// - Parameter name: A descriptive String for easily identifying the Terminal (ie: "LV", "HV", etc)
    /// - Parameter lineVoltage: The current line-line (line-neutral for single-phase) voltage of the terminal in volts. This may be zero if there are no active turns.
    /// - Parameter noloadLegVoltage: The initial (unmutable) no-load voltage per leg for the terminal
    /// - Parameter VA: The total (1-ph or 3-ph) VA for the Terminal
    /// - Parameter connection: The connection to use for this Terminal
    /// - Parameter termNum: The Andersen-file Terminal number
    /// - Returns: An initialized Terminal object
    init(name:String, lineVoltage:Double, noloadLegVoltage:Double, VA:Double, connection:TerminalConnection, currDir:Int, termNum:Int)
    {
        self.name = name
        self.nominalLegVoltsStore = lineVoltage / (connection == .wye || connection == .auto_common || connection == .auto_series ? SQRT3 : 1.0)
        self.VA = VA
        self.connection = connection
        self.currentDirection = currDir
        self.andersenNumber = termNum
        self.noloadLegVoltage = noloadLegVoltage
    }
    
    func AndersenConnection() -> Int
    {
        switch self.connection {
        case .delta:
            return 2
        case .auto_common:
            return 3
        case .auto_series:
            return 3
        case .zag:
            return 5
        case .zig:
            return 6
        default:
            return 1
        }
    }
    
    /// This function sets the VA of the terminal based on the voltage and current passed in. The legVolts parameter must be a non-zero, positive number. The 'amps' parameter can be either positive or negative. If 'amps' is equal to nil, it is assumed that the VA does not change (although the voltage might). If legVolts is nil, the voltage does not change (but the VA might). For auto-connected windings, the amps are the ACTUAL amps flowing in the winding.
    func SetVoltsAndAmps(legVolts:Double? = nil, amps:Double? = nil)
    {
        let newVolts = legVolts == nil ? self.nominalLegVoltsStore : legVolts!
        
        if newVolts <= 0.0
        {
            DLog("Attempt to set voltage to \(newVolts) for terminal \(self.name)")
        }
        
        ZAssert(newVolts > 0.0, message: "Terminal voltage must be a non-zero, positive number")
        
        
        
        if let newAmps = amps
        {
            if (newAmps < 0) == (self.currentDirection < 0)
            {
                self.currentDirection = 1
            }
            
            self.VA = newAmps * newVolts * self.phaseFactor
        }
        else
        {
            self.VA = self.legVA * self.phaseFactor
        }
        
        self.nominalLegVoltsStore = newVolts
        
    }
    
}
