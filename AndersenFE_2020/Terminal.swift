//
//  Terminal.swift
//  AndersenFE_2020
//
//  Created by Peter Huber on 2020-07-18.
//  Copyright © 2020 Peter Huber. All rights reserved.
//

import Cocoa

/// The Terminal class basically wraps the data in an Andersen Terminal
class Terminal: NSObject
{
    /// A descriptive String for easily identifying the Terminal (ie: "LV", "HV", etc)
    let name:String
    
    /// The line-line (line-neutral for single-phase) voltage of the terminal in volts
    let voltage:Double
    
    /// The total (1-ph or 3-ph) VA for the Terminal
    let VA:Double
    
    /// Possible Terminal connections
    enum TerminalConnection {
        case single_phase
        case wye
        case auto
        case delta
        case zig
        case zag
    }
    
    /// The connection to use for this Terminal
    let connection:TerminalConnection
    
    /// The Andersen-file Terminal number
    var andersenNumber:Int
    
    /// Designated initializer for the Terminal class
    /// - Parameter name: A descriptive String for easily identifying the Terminal (ie: "LV", "HV", etc)
    /// - Parameter voltage: The line-line (line-neutral for single-phase) voltage of the terminal in volts
    /// - Parameter VA: The total (1-ph or 3-ph) VA for the Terminal
    /// - Parameter connection: The connection to use for this Terminal
    /// - Parameter termNum: The Andersen-file Terminal number
    /// - Returns: An initialized Terminal object
    init(name:String, voltage:Double, VA:Double, connection:TerminalConnection, termNum:Int)
    {
        self.name = name
        self.voltage = voltage
        self.VA = VA
        self.connection = connection
        self.andersenNumber = termNum
    }

}
