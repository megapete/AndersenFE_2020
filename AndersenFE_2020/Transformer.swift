//
//  Transformer.swift
//  AndersenFE_2020
//
//  Created by Peter Huber on 2020-07-19.
//  Copyright © 2020 Peter Huber. All rights reserved.
//

import Foundation

/// The Transformer struct is the encompassing Andersen-oriented data for the model. All of its fields are self-explanatory.
struct Transformer {
    
    let numPhases:Int
    
    let frequency:Double
    
    let tempRise:Double
    
    let core:(diameter:Double, windHt:Double)
    
    let scFactor:Double
    
    let systemGVA:Double
    
    let tankDepth:Double
    
    var windings:[Winding] = []
    
    var terminals:[Terminal?] = []
    
    /// Some different errors that can be thrown by the init routine
    struct DesignFileError:Error
    {
        enum errorType
        {
            case InvalidDesignFile
            case InvalidFileVersion
            case InvalidValue
        }
        
        let info:String
        let type:errorType
        
        var localizedDescription: String
        {
            get
            {
                if self.type == .InvalidDesignFile
                {
                    return "This is not an Excel-derived design file"
                }
                else if self.type == .InvalidFileVersion
                {
                    return "This program requires a file version of 3 or greater."
                }
                else if self.type == .InvalidValue
                {
                    return "There is an invalid value in line \(self.info) of the file."
                }
                
                return "An unknown error occurred."
            }
        }
    }
    
    init(designFile:URL) throws
    {
        var fileString = ""
        
        do
        {
            fileString = try String(contentsOf: designFile)
        }
        catch
        {
            throw error
        }
        
        let lineArray:[String] = fileString.components(separatedBy: .newlines)
        
        var currIndex = 0
        
        var lineElements:[String] = lineArray[currIndex].components(separatedBy: .whitespaces)
        
        if lineElements.count != 8
        {
            throw DesignFileError(info: "", type: .InvalidDesignFile)
        }
        
        guard let version = Int(lineElements[7]) else
        {
            throw DesignFileError(info: "", type: .InvalidDesignFile)
        }
        
        if version < 3
        {
            throw DesignFileError(info: "", type: .InvalidFileVersion)
        }
        
        // Get the number of phases
        self.numPhases = Int(lineElements[0])!
        self.frequency = Double(lineElements[1])!
        self.tempRise = Double(lineElements[2])!
        self.core = (Double(lineElements[5])!, Double(lineElements[6])!)
        
        currIndex += 1
        
        while currIndex < 9
        {
            lineElements = lineArray[currIndex].components(separatedBy: .whitespaces)
            
            if let voltage = Double(lineElements[0])
            {
                if voltage == 0.0
                {
                    terminals.append(nil)
                    continue
                }
                
                let VA = Double(lineElements[1])! * 1000.0
                
                let connString = lineElements[2]
                var connection:Terminal.TerminalConnection = .wye
            
                if connString == "D"
                {
                    connection = .delta
                }
                else if connString == "ZIG"
                {
                    connection = .zig
                }
                else if connString == "ZAG"
                {
                    connection = .zag
                }
                
                let newTermNum = Int(lineElements[3])!
                let currDir = Int(lineElements[4])!
                
                let newTerm = Terminal(name: "", voltage: voltage, VA: VA, connection: connection, currDir:currDir, termNum: newTermNum)
                
                terminals.append(newTerm)
            }
            else
            {
                throw DesignFileError(info: "\(currIndex)", type: .InvalidValue)
            }
            
            currIndex += 1
        }
        
        var rowMap:[Int?] = []
        lineElements = lineArray[currIndex].components(separatedBy: .whitespaces)
        
        for i in 0..<9
        {
            if lineElements[i] == "FALSE"
            {
                rowMap.append(nil)
            }
            else if let rowNum = Int(lineElements[i])
            {
                rowMap.append(rowNum)
            }
            else
            {
                rowMap.append(nil)
            }
        }
        
        currIndex += 1
        
        let wdgDataStartIndex = currIndex
        var scFactorIndex = 0
        
        for i in 0..<9
        {
            if let termIndex = rowMap[i]
            {
                // min turns
                lineElements = lineArray[currIndex].components(separatedBy: .whitespaces)
                let minTurns = Double(lineElements[i])!
                currIndex += 1
                
                // nom turns
                lineElements = lineArray[currIndex].components(separatedBy: .whitespaces)
                let nomTurns = Double(lineElements[i])!
                currIndex += 1
                
                // max turns
                lineElements = lineArray[currIndex].components(separatedBy: .whitespaces)
                let maxTurns = Double(lineElements[i])!
                currIndex += 1
                
                // electrical height
                lineElements = lineArray[currIndex].components(separatedBy: .whitespaces)
                let elecHtb = Double(lineElements[i])!
                currIndex += 1
                
            }
            
            currIndex = wdgDataStartIndex
        }
        
    }
}
