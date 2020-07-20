//
//  Transformer.swift
//  AndersenFE_2020
//
//  Created by Peter Huber on 2020-07-19.
//  Copyright © 2020 Peter Huber. All rights reserved.
//

import Foundation

let PCH_SupportedFileVersion = 4

/// The Transformer struct is the encompassing Andersen-oriented data for the model. All of its fields are self-explanatory.
struct Transformer {
    
    let numPhases:Int
    
    let frequency:Double
    
    let tempRise:Double
    
    let core:(diameter:Double, windHt:Double)
    
    var scFactor:Double
    
    var systemGVA:Double
    
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
                    return "This program requires a file version of \(PCH_SupportedFileVersion) or greater."
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
        
        if version < PCH_SupportedFileVersion
        {
            throw DesignFileError(info: "", type: .InvalidFileVersion)
        }
        
        // Get the number of phases
        self.numPhases = Int(lineElements[0])!
        self.frequency = Double(lineElements[1])!
        self.tempRise = Double(lineElements[2])!
        self.core = (Double(lineElements[5])!, Double(lineElements[6])!)
        
        var assymetryFactor = 1.8
        var systemStrength = 0.0
        
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
                
                // check for spiral section
                lineElements = lineArray[currIndex].components(separatedBy: .whitespaces)
                var strBool = lineElements[i]
                let isSpiral = strBool == "Y"
                currIndex += 1
                
                // check for double stack
                lineElements = lineArray[currIndex].components(separatedBy: .whitespaces)
                strBool = lineElements[i]
                let isDoubleStack = strBool == "Y"
                currIndex += 1
                
                // check for multistart winding
                lineElements = lineArray[currIndex].components(separatedBy: .whitespaces)
                strBool = lineElements[i]
                let isMultistart = strBool == "Y"
                currIndex += 1
                
                // num Axial Sections
                lineElements = lineArray[currIndex].components(separatedBy: .whitespaces)
                let numAxialSections = Int(lineElements[i])!
                currIndex += 1
                
                // axial gaps
                lineElements = lineArray[currIndex].components(separatedBy: .whitespaces)
                let radialSpacerThickness = Double(lineElements[i])!
                currIndex += 1
                
                // radial spacer widths
                lineElements = lineArray[currIndex].components(separatedBy: .whitespaces)
                let radialSpacerWidth = Double(lineElements[i])!
                currIndex += 1
                
                // num Axial Columns
                lineElements = lineArray[currIndex].components(separatedBy: .whitespaces)
                let numAxialColumns = Int(lineElements[i])!
                currIndex += 1
                
                // num Radial Sections
                lineElements = lineArray[currIndex].components(separatedBy: .whitespaces)
                let numRadialSections = Int(lineElements[i])!
                currIndex += 1
                
                // radial insulation (solid between layers)
                lineElements = lineArray[currIndex].components(separatedBy: .whitespaces)
                let insulationBetweenLayers = Double(lineElements[i])!
                currIndex += 1
                
                // num Radial Ducts
                lineElements = lineArray[currIndex].components(separatedBy: .whitespaces)
                let numRadialDucts = Int(lineElements[i])!
                currIndex += 1
                
                // radial duct thickness
                lineElements = lineArray[currIndex].components(separatedBy: .whitespaces)
                let radialDuctDimn = Double(lineElements[i])!
                currIndex += 1
                
                // num Radial Columns
                lineElements = lineArray[currIndex].components(separatedBy: .whitespaces)
                let numRadialColumns = Int(lineElements[i])!
                currIndex += 1
                
                // conductor type
                lineElements = lineArray[currIndex].components(separatedBy: .whitespaces)
                strBool = lineElements[i]
                let cableType:Winding.CableType = (strBool == "CTC" ? .CTC : (strBool == "D" ? .twin : .single))
                currIndex += 1
                
                // num axial cables
                lineElements = lineArray[currIndex].components(separatedBy: .whitespaces)
                let numAxialCables = Int(lineElements[i])!
                currIndex += 1
                
                // num radial cables
                lineElements = lineArray[currIndex].components(separatedBy: .whitespaces)
                let numRadialCables = Int(lineElements[i])!
                currIndex += 1
                
                // skip the conductor shape AND the "radial paper per turn" value
                currIndex += 2
                
                // strand axial dimension
                lineElements = lineArray[currIndex].components(separatedBy: .whitespaces)
                let strandAxialDimn = Double(lineElements[i])!
                currIndex += 1
                
                // strand radial dimension
                lineElements = lineArray[currIndex].components(separatedBy: .whitespaces)
                let strandRadialDimn = Double(lineElements[i])!
                currIndex += 1
                
                // num strands per CTC
                lineElements = lineArray[currIndex].components(separatedBy: .whitespaces)
                let numStrandsCTC = Int(lineElements[i])!
                currIndex += 1
                
                // axial center gap
                lineElements = lineArray[currIndex].components(separatedBy: .whitespaces)
                let axialGapCenter = Double(lineElements[i])!
                currIndex += 1
                
                // axial lower gap
                lineElements = lineArray[currIndex].components(separatedBy: .whitespaces)
                let axialGapLower = Double(lineElements[i])!
                currIndex += 1
                
                // axial upper gap
                lineElements = lineArray[currIndex].components(separatedBy: .whitespaces)
                let axialGapUpper = Double(lineElements[i])!
                currIndex += 1
                
                // bottom edge pack
                lineElements = lineArray[currIndex].components(separatedBy: .whitespaces)
                let bottomEdgePack = Double(lineElements[i])!
                currIndex += 1
                
                // ID
                lineElements = lineArray[currIndex].components(separatedBy: .whitespaces)
                let windingID = Double(lineElements[i])!
                currIndex += 1
                
                // overbuild allowance
                lineElements = lineArray[currIndex].components(separatedBy: .whitespaces)
                let overbuildAllowance = Double(lineElements[i])!
                currIndex += 1
                
                // max ground clearance
                lineElements = lineArray[currIndex].components(separatedBy: .whitespaces)
                let groundClearance = Double(lineElements[i])!
                currIndex += 1
                
                if i == 0
                {
                    lineElements = lineArray[currIndex].components(separatedBy: .whitespaces)
                    assymetryFactor = Double(lineElements[i])!
                    currIndex += 1
                    
                    lineElements = lineArray[currIndex].components(separatedBy: .whitespaces)
                    systemStrength = Double(lineElements[i])!
                    currIndex += 1
                }
                else
                {
                    currIndex += 2
                }
                
                // insulation between cables
                lineElements = lineArray[currIndex].components(separatedBy: .whitespaces)
                let internalTurnInsulation = Double(lineElements[i])!
                currIndex += 1
                
                // skip the next 3
                currIndex += 3
                
                // strand insulatiom
                lineElements = lineArray[currIndex].components(separatedBy: .whitespaces)
                let strandInsulation = Double(lineElements[i])!
                currIndex += 1
                
                // cable insulatiom
                lineElements = lineArray[currIndex].components(separatedBy: .whitespaces)
                let cableInsulation = Double(lineElements[i])!
                
                
                
                // let newWinding = Winding(wdgType: <#T##Winding.WindingType#>, isSprial: <#T##Bool#>, isDoubleStack: <#T##Bool#>, numTurns: <#T##(minTurns: Double, nomTurns: Double, maxTurns: Double)#>, elecHt: <#T##Double#>, numAxialSections: <#T##Int#>, radialSpacer: <#T##(thickness: Double, width: Double)#>, numAxialColumns: <#T##Int#>, numRadialSections: <#T##Int#>, radialInsulation: <#T##Double#>, ducts: <#T##(count: Int, dim: Double)#>, numRadialSupports: <#T##Int#>, turnDef: <#T##Winding.TurnDefinition#>, axialGaps: <#T##(center: Double, bottom: Double, top: Double)#>, bottomEdgePack: <#T##Double#>, coilID: <#T##Double#>, radialOverbuild: <#T##Double#>, groundClearance: <#T##Double#>, terminal: <#T##Terminal#>)
            }
            
            currIndex = wdgDataStartIndex
        }
        
        self.scFactor = assymetryFactor
        self.systemGVA = systemStrength
        
    }
}
