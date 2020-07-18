//
//  Terminal.swift
//  AndersenFE_2020
//
//  Created by Peter Huber on 2020-07-18.
//  Copyright © 2020 Peter Huber. All rights reserved.
//

import Cocoa

class Terminal: NSObject {
    
    let name:String
    
    let voltage:Double
    
    let VA:Double
    
    enum TerminalConnection {
        case single_phase
        case wye
        case auto
        case delta
        case zig
        case zag
    }
    
    let connection:TerminalConnection
    
    var andersenNumber:Int
    
    init(name:String, voltage:Double, VA:Double, connection:TerminalConnection, termNum:Int)
    {
        self.name = name
        self.voltage = voltage
        self.VA = VA
        self.connection = connection
        self.andersenNumber = termNum
    }

}
