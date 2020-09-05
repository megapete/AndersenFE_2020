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
    
    /// The original no-load voltage for the terminal (usually whatever was in the XL design file, corrected for double axial stacks)
    let noloadLegVoltage:Double
    
    /// The total (1-ph or 3-ph) VA for the Terminal. This is the THROUGHPUT VA for auto-connected windings
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
    
    /// The nominal leg amps of the Terminal (winding). These are the ACTUAL amps flowing in the winding.
    var nominalAmps:Double {
        get {
            
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
    let connection:TerminalConnection
    
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
    
    /// This function sets the VA of the terminal based on the voltage and current passed in. Note that if 'amps' is negative, the currentDirection property is INVERTED. If 'amps' is equal to nil, it is assumed that the VA does not change. For auto-connected windings, the amps are the ACTUAL amps flowing in the winding.
    func SetVoltsAndVA(legVolts:Double, amps:Double? = nil)
    {
        if legVolts == 0.0
        {
            self.currentDirection = 0
            self.VA = 0.0
            return
        }
        
        self.nominalLegVoltsStore = legVolts
        
        guard let newAmps = amps else
        {
            return
        }
        
        self.VA = legVolts * fabs(newAmps) * self.phaseFactor
        
        if newAmps < 0 && self.currentDirection != 0
        {
            self.currentDirection = -self.currentDirection
        }
        else if newAmps == 0
        {
            self.currentDirection = 0
            self.VA = 0.0
        }
        else if self.currentDirection == 0
        {
            self.currentDirection = newAmps < 0.0 ? -1 : 1
        }
        
        
    }
    
}
