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
    
    /// The line-line (line-neutral for single-phase) voltage of the terminal in volts
    let voltage:Double
    
    /// The total (1-ph or 3-ph) VA for the Terminal
    let VA:Double
    
    /// Possible Terminal connections
    enum TerminalConnection:Int, Codable {
        case single_phase = 1
        case wye = 2
        case delta = 3
        case auto_common = 4
        case auto_series = 5
        case zig = 6
        case zag = 7
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
