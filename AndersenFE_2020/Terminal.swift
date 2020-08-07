//
//  Terminal.swift
//  AndersenFE_2020
//
//  Created by Peter Huber on 2020-07-18.
//  Copyright © 2020 Peter Huber. All rights reserved.
//

import Foundation

/// The Terminal class basically wraps the data from the first page of the Excel document
struct Terminal: Codable
{
    /// A descriptive String for easily identifying the Terminal (ie: "LV", "HV", etc)
    let name:String
    
    /// The line-line (line-neutral for single-phase) voltage of the terminal in volts (note that this should be the "corrected" value for parallel-stacked windings)
    var voltage:Double
    
    /// The total (1-ph or 3-ph) VA for the Terminal
    var VA:Double
    
    var legVA:Double {
        get {
            let phaseFactor = self.connection == .single_phase_one_leg ? 1.0 : self.connection == .single_phase_two_legs ? 2.0 : 3.0
            return self.VA / phaseFactor
        }
    }
    
    /// The nominal ONAN leg amps of the Terminal (winding)
    var NominalOnanAmps:Double {
        get {
    
            let connFactor = (self.connection == .wye || self.connection == .auto_common || self.connection == .auto_series ? SQRT3 : 1.0)
            
            let result = self.legVA / (self.voltage / connFactor)
            
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
    
    /// The current direction for this Terminal
    let currentDirection:Int
    
    /// The Andersen-file Terminal number
    var andersenNumber:Int
    
    /// Designated initializer for the Terminal class
    /// - Parameter name: A descriptive String for easily identifying the Terminal (ie: "LV", "HV", etc)
    /// - Parameter voltage: The line-line (line-neutral for single-phase) voltage of the terminal in volts
    /// - Parameter VA: The total (1-ph or 3-ph) VA for the Terminal
    /// - Parameter connection: The connection to use for this Terminal
    /// - Parameter termNum: The Andersen-file Terminal number
    /// - Returns: An initialized Terminal object
    init(name:String, voltage:Double, VA:Double, connection:TerminalConnection, currDir:Int, termNum:Int)
    {
        self.name = name
        self.voltage = voltage
        self.VA = VA
        self.connection = connection
        self.currentDirection = currDir
        self.andersenNumber = termNum
    }

}
