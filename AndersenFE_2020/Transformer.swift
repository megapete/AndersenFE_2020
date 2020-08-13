//
//  Transformer.swift
//  AndersenFE_2020
//
//  Created by Peter Huber on 2020-07-19.
//  Copyright © 2020 Peter Huber. All rights reserved.
//

import Cocoa

let PCH_AFE2020_SupportedFileVersion = 4

/// The Transformer struct is the encompassing Andersen-oriented data for the model. All of its fields are self-explanatory.
class Transformer:Codable {
    
    let numPhases:Int
    
    let frequency:Double
    
    let tempRise:Double
    
    struct Core:Codable {
        let diameter:Double
        let windHt:Double
    }
    let core:Core
    
    var scFactor:Double
    
    var systemGVA:Double
    
    var windings:[Winding] = []
    
    var terminals:[Terminal?] = []
    
    var refTermNum:Int? = nil
    
    var niDistribution:[Double]? = nil
    
    /// Straightforward init function (designed for the copy() function below)
    init(numPhases:Int, frequency:Double, tempRise:Double, core:Core, scFactor:Double, systemGVA:Double, windings:[Winding], terminals:[Terminal?], refTermNum:Int? = nil, niDistribution:[Double]? = nil)
    {
        self.numPhases = numPhases
        self.frequency = frequency
        self.tempRise = tempRise
        self.core = core
        self.scFactor = scFactor
        self.systemGVA = systemGVA
        self.refTermNum = refTermNum
        self.niDistribution = niDistribution
        
        for nextTerm in terminals
        {
            if let oldTerm = nextTerm
            {
                let newTerm = Terminal(name: oldTerm.name, voltage: oldTerm.nominalLineVolts, VA: oldTerm.VA, connection: oldTerm.connection, currDir: oldTerm.currentDirection, termNum: oldTerm.andersenNumber)
                
                self.terminals.append(newTerm)
            }
            else
            {
                self.terminals.append(nil)
            }
        }
        
        var index = 0
        for nextWdg in windings
        {
            self.windings.append(Winding(srcWdg: nextWdg, terminal: self.terminals[index]!))
            
            index += 1
        }
    }
    
    /// Return a copy of this transformer (designed to be used with Undo functionality)
    func Copy() -> Transformer
    {
        return Transformer(numPhases: self.numPhases, frequency: self.frequency, tempRise: self.tempRise, core: self.core, scFactor: self.scFactor, systemGVA: self.systemGVA, windings: self.windings, terminals: self.terminals, refTermNum: self.refTermNum, niDistribution: self.niDistribution)
    }
    
    /// Some errors that can be thrown by various routines
    struct TransformerErrors:Error
    {
        enum errorType
        {
            case NoReferenceTerminalDefined
            case NoSuchTerminalNumber
            case UnimplementedFeature
        }
        
        let info:String
        let type:errorType
        
        var localizedDescription: String
        {
            get
            {
                if self.type == .NoReferenceTerminalDefined
                {
                    return "The reference terminal has not been defined!"
                }
                else if self.type == .NoSuchTerminalNumber
                {
                    return "The terminal number \(info) does not exist in the model"
                }
                else if self.type == .UnimplementedFeature
                {
                    return "This feature has not been implemented: \(info)"
                }
                
                
                return "An unknown error occurred."
            }
        }
    }
    
    /// Calculate the distance from the center of the core to the tank wall (used for graphics)
    func DistanceFromCoreCenterToTankWall() -> Double
    {
        var result = 0.0
        
        for nextWdg in self.windings
        {
            result = max(nextWdg.layers.last!.OD() / 2.0 + nextWdg.groundClearance, result)
        }
        
        return result
    }
    
    /// Find the Terminals that have the Andersen number termNum assigned to it. Return an empty array if there aren't any.
    func TerminalsFromAndersenNumber(termNum:Int) throws -> [Terminal]
    {
        var result:[Terminal] = []
        
        for nextTerm in self.terminals
        {
            if let term = nextTerm
            {
                if term.andersenNumber == termNum
                {
                    result.append(term)
                }
            }
        }
        
        if result.count == 0
        {
            throw TransformerErrors.init(info: "\(termNum)", type: .NoSuchTerminalNumber)
        }
        
        return result
    }
    
    func WindingsFromAndersenNumber(termNum:Int) throws -> [Winding]
    {
        var result:[Winding] = []
        
        for nextWdg in self.windings
        {
            if nextWdg.terminal.andersenNumber == termNum
            {
                result.append(nextWdg)
            }
        }
        
        if result.count == 0
        {
            throw TransformerErrors.init(info: "\(termNum)", type: .NoSuchTerminalNumber)
        }
        
        return result
    }
    
    /// Return a set of Ints that represent the Andersen-terminals that are available
    func AvailableTerminals() -> Set<Int>
    {
        var result:Set<Int> = []
        
        for nextEntry in self.terminals
        {
            if let nextTerm = nextEntry
            {
                result.insert(nextTerm.andersenNumber)
            }
        }
        
        return result
    }
    
    /// The terminal line voltage is one of two possible voltages. If there are active (current-carrying) turns making up the terminal, then the line voltage is calculated using the current V/N and the active turns. If no turns are active, the no-load voltage of the sum of all the turns (active or not) of teh terminal is calculated.
    func TerminalLineVoltage(terminal:Int) throws -> Double
    {
        var terms:[Terminal] = []
        
        do
        {
            terms = try self.TerminalsFromAndersenNumber(termNum: terminal)
        }
        catch
        {
            throw error
        }
        
        var VpN = 0.0
        
        do
        {
            VpN = try self.VoltsPerTurn()
        }
        catch
        {
            throw error
        }
        
        var phaseFactor = 1.0
        var autoFactor = 1.0
        
        if terms[0].connection == .wye || terms[0].connection == .zig || terms[0].connection == .zag || terms[0].connection == .auto_common || terms[0].connection == .auto_series
        {
            phaseFactor = SQRT3
        }
        
        if terms[0].connection == .auto_series
        {
            for nextTerm in self.terminals
            {
                if let cTerm = nextTerm
                {
                    if cTerm.connection == .auto_common
                    {
                        var commonTurns = CurrentCarryingTurns(terminal: cTerm.andersenNumber)
                        if commonTurns == 0
                        {
                            commonTurns = NoLoadTurns(terminal: cTerm.andersenNumber)
                        }
                        
                        var seriesTurns = CurrentCarryingTurns(terminal: terminal)
                        if seriesTurns == 0
                        {
                            seriesTurns = NoLoadTurns(terminal: terminal)
                        }
                        
                        autoFactor = (seriesTurns + commonTurns) / commonTurns
                    }
                }
            }
        }
        
        var useTurns = CurrentCarryingTurns(terminal: terminal)
        if useTurns == 0
        {
            useTurns = NoLoadTurns(terminal: terminal)
        }
        
        return  fabs(VpN * useTurns * phaseFactor * autoFactor)
    }
    
    /// This is a SIGNED quantity.
    func ReferenceOnanAmpTurns() throws -> Double
    {
        guard let refTerm = self.refTermNum else
        {
            throw TransformerErrors.init(info: "", type: .NoReferenceTerminalDefined)
        }
        
        var vpn = 0.0
        do
        {
            vpn = try self.VoltsPerTurn()
        }
        catch
        {
            throw error
        }
        
        
        var va = 0.0
        
        var terms:[Terminal] = []
        
        do
        {
            terms = try self.TerminalsFromAndersenNumber(termNum: refTerm)
        }
        catch
        {
            throw error
        }
        
        for nextTerm in terms
        {
            va += nextTerm.legVA * Double(nextTerm.currentDirection)
        }
        
        //let sign = self.CurrentCarryingTurns(terminal: refTerm) < 0.0 ? -1.0 : 1.0
        
        return va / vpn
    }
    
    // The total VA (three-phase or single-phase, depending on the connection) of the Andersen-type terminal
    func TerminalVA(termNum:Int) throws -> Double
    {
        do
        {
            let wdgs = try self.WindingsFromAndersenNumber(termNum: termNum)
            
            var result = 0.0
            
            for nextWdg in wdgs
            {
                let wdgVA = nextWdg.terminal.VA * nextWdg.CurrentCarryingTurns() / nextWdg.NoLoadTurns()
                
                result += wdgVA
            }
            
            return result
        }
        catch
        {
            throw error
        }
    }
    
    /// Total AmpereTurns for the Transformer in its current state (this value must equal 0 to be able to calculate impedance). If the reference terminal has not been defined, this function throws an error. Note that if forceBalance is true, then this function will modify all non-reference Terminals' 'nominalLineVoltage' and 'VA' fields to force amp-turns to be equal to 0.
    func AmpTurns(forceBalance:Bool, showDistributionDialog:Bool) throws -> Double
    {
        guard let refTerm = self.refTermNum else {
            
            throw TransformerErrors.init(info: "", type: .NoReferenceTerminalDefined)
        }
        
        if forceBalance
        {
            var refTermNI = 0.0
            do
            {
                refTermNI = try self.ReferenceOnanAmpTurns()
            }
            catch
            {
                throw error
            }
            
            let nonRefTerms = self.AvailableTerminals().subtracting([refTerm])
            
            if nonRefTerms.count == 1
            {
                do
                {
                    let nonRefWdgs = try self.WindingsFromAndersenNumber(termNum: nonRefTerms.first!)
                    
                    let totalTurns = self.CurrentCarryingTurns(terminal: nonRefTerms.first!)
                    
                    let amps = (totalTurns == 0.0 ? 0.0 : -refTermNI / totalTurns)
                    let vpn = try self.VoltsPerTurn()
                    
                    for nextWdg in nonRefWdgs
                    {
                        let voltage = nextWdg.NoLoadVoltage(voltsPerTurn: vpn)
                        let wdgAmps = nextWdg.CurrentCarryingTurns() / nextWdg.NoLoadTurns() * amps
                        nextWdg.terminal.SetVoltsAndVA(legVolts: voltage, amps: wdgAmps)
                    }
                }
                catch
                {
                    throw error
                }
            }
            else // there's more than just two terminals
            {
                // Start out by assuming that the ref terminal has 100% (or -100 if the current direction is negative) of the amp-turns and that Terminal 1 or Terminal 2 has the full offsetting NI. This way, if the user Cancels out of the DialogBox, everything is balanced.
                
                let sign = self.CurrentCarryingTurns(terminal: refTerm) < 0.0 ? -1.0 : 1.0
                
                let refTermNIpercentage = sign * 100.0
                
                let otherMainTerm = (refTerm == 2 ? 1 : 2)
                
                var niArray:[Double] = Array(repeating: 0.0, count: 6)
                
                niArray[refTerm - 1] = refTermNIpercentage
                niArray[otherMainTerm - 1] = -refTermNIpercentage
                
                let termsToAdjust:Set<Int> = self.AvailableTerminals()
                
                if showDistributionDialog || self.niDistribution == nil
                {
                    let niDlog = AmpTurnsDistributionDialog(termsToShow: termsToAdjust, termPercentages: niArray)
                    
                    if niDlog.runModal() == .OK
                    {
                        niArray = niDlog.currentTerminalPercentages
                    }
                    
                    self.niDistribution = niArray
                }
                
                var voltAmps:[(terminal:Terminal, volts:Double, amps:Double)] = []
                do
                {
                    for nextTerm in termsToAdjust
                    {
                        let windings = try self.WindingsFromAndersenNumber(termNum: nextTerm)
                        let turns = self.CurrentCarryingTurns(terminal: nextTerm)
                        
                        let amps = turns == 0.0 ? 0.0 : niArray[nextTerm - 1] / 100.0 * refTermNI / turns
                        let vpn = try self.VoltsPerTurn()
                        
                        for nextWdg in windings
                        {
                            let voltage = nextWdg.NoLoadVoltage(voltsPerTurn: vpn)
                            let wdgAmps = nextWdg.CurrentCarryingTurns() / nextWdg.NoLoadTurns() * amps
                            voltAmps.append((nextWdg.terminal, voltage, wdgAmps))
                        }
                    }
                }
                catch
                {
                    throw error
                }
                
                // if we get here, then there were no errors so change the terminal VAs
                for va in voltAmps
                {
                    let term = va.terminal
                    term.SetVoltsAndVA(legVolts: va.volts, amps: va.amps)
                }
            }
            
            return 0.0
        }
        else
        {
            // This branch simply uses the current VA and voltage (calculated using the current V/N, if any) to calculate total amp-turns and allows non-zero results (ie: the user has to figure it out)
            throw TransformerErrors.init(info: "Manual (user) calculation of terminal VAs to balance AmpTurns", type: .UnimplementedFeature)
        }
        
        
    }
    
    /// Calculate the V/N for the transformer given the reference terminal number. The voltage is the SUM of all the voltages for the terminal. Note that in the event that the reference terminal has 0 active turns, its no-load voltage sum (and turns) are used.
    func VoltsPerTurn() throws -> Double
    {
        guard let refTerm = self.refTermNum else
        {
            throw TransformerErrors.init(info: "", type: .NoReferenceTerminalDefined)
        }
        
        var terminals:[Terminal] = []
        do
        {
            terminals = try self.TerminalsFromAndersenNumber(termNum: self.refTermNum!)
        }
        catch
        {
            throw error
        }
        
        var result = 0.0
        
        let legFactor = (terminals[0].connection == .wye || terminals[0].connection == .auto_common || terminals[0].connection == .auto_series ? SQRT3 : 1.0)
        
        var voltageSum = 0.0
        var noloadVoltageSum = 0.0
        for nextWdg in self.windings
        {
            if nextWdg.terminal.andersenNumber == refTerm
            {
                noloadVoltageSum += nextWdg.terminal.nominalLineVolts
                
                voltageSum += nextWdg.CurrentCarryingTurns() / nextWdg.NoLoadTurns() * nextWdg.terminal.nominalLineVolts
            }
        }
        
        var turnsToUse = self.CurrentCarryingTurns(terminal: refTerm)
        
        if turnsToUse == 0
        {
            // use the no-load turns & voltage
            turnsToUse = self.NoLoadTurns(terminal: refTerm)
            voltageSum = noloadVoltageSum
        }
        
        result = voltageSum / legFactor / turnsToUse
        
        return result
    }
    
    /// Signed value representing the number of turns associated with the give terminal
    func CurrentCarryingTurns(terminal:Int) -> Double
    {
        var result = 0.0
        
        for nextWdg in self.windings
        {
            if nextWdg.terminal.andersenNumber == terminal
            {
                result += nextWdg.CurrentCarryingTurns()
            }
        }
        
        return result
    }
    
    func NoLoadTurns(terminal:Int) -> Double
    {
        var result = 0.0
        
        for nextWdg in self.windings
        {
            if nextWdg.terminal.andersenNumber == terminal
            {
                result += nextWdg.NoLoadTurns()
            }
        }
        
        return result
    }
    
    /// Some different errors that can be thrown by the init routine
    struct DesignFileError:Error
    {
        enum errorType
        {
            case InvalidDesignFile
            case InvalidFileVersion
            case InvalidValue
            case InvalidConnection
            case MissingComplementConnection
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
                    return "This program requires a file version of \(PCH_AFE2020_SupportedFileVersion) or greater."
                }
                else if self.type == .InvalidValue
                {
                    return "There is an invalid value in line \(self.info) of the file."
                }
                else if self.type == .InvalidConnection
                {
                    return "An invalid connection was specified for terminal: \(self.info)"
                }
                else if self.type == .MissingComplementConnection
                {
                    return "A\(self.info) connection is missing one of its parts"
                }
                
                return "An unknown error occurred."
            }
        }
    }
    
    func GetWindingsCenter() -> Double
    {
        // we'll generalize and set the center of all the windings to the one with the greatest Z (sort of assumes that the designer knows what he's doing).
        
        var result = 0.0
        for nextWdg in self.windings
        {
            let nextCenter = nextWdg.bottomEdgePack + nextWdg.elecHt / 2.0
            
            result = max(result, nextCenter)
        }
        
        return result
    }
    
    func InitializeWindings(prefs:PCH_AFE2020_Prefs)
    {
        for nextWdg in self.windings
        {
            nextWdg.layers.removeAll()
            
            nextWdg.preferences = prefs.wdgPrefs
            
            do {
                
                try nextWdg.InitializeLayers(windingCenter: GetWindingsCenter())
                DLog("Layer count: \(nextWdg.layers.count)")
            }
            catch
            {
                let alert = NSAlert(error: error)
                let _ = alert.runModal()
                return
            }
        }
    }
    
   
    
    /// Initializer to create a transformer from an Excel-generated design file.
    /// - Parameter designFile: The URL of the design file
    /// - Parameter prefs: The preferences to apply when creating the transformer
    /// - Throws: Errors if the URL is not a valid design file; the file is an invalid version (less than 4); the file contains an invalid value
    init(designFile:URL, prefs:PCH_AFE2020_Prefs) throws
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
        
        // Get the file as an array of lines and get rid of any null strings that are in there
        let lineArray:[String] = fileString.components(separatedBy: .newlines).filter{$0 != ""}
        
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
        
        if version < PCH_AFE2020_SupportedFileVersion
        {
            throw DesignFileError(info: "", type: .InvalidFileVersion)
        }
        
        // Get the number of phases
        if let num = Int(lineElements[0])
        {
            self.numPhases = num
        }
        else
        {
            throw DesignFileError(info: "\(currIndex)", type: .InvalidValue)
        }
        
        // frequency
        if let num = Double(lineElements[1])
        {
            self.frequency = num
        }
        else
        {
            throw DesignFileError(info: "\(currIndex)", type: .InvalidValue)
        }
        
        // temperature rise
        if let num = Double(lineElements[2])
        {
            self.tempRise = num
        }
        else
        {
            throw DesignFileError(info: "\(currIndex)", type: .InvalidValue)
        }
        
        // core
        if let num1 = Double(lineElements[5])
        {
            if let num2 = Double(lineElements[6])
            {
                self.core = Core(diameter: num1 * mmPerInch, windHt: num2 * mmPerInch)
            }
            else
            {
                throw DesignFileError(info: "\(currIndex)", type: .InvalidValue)
            }
        }
        else
        {
            throw DesignFileError(info: "\(currIndex)", type: .InvalidValue)
        }
        
        // sc stuff initialization
        var assymetryFactor = 1.8
        var systemStrength = 0.0
        
        currIndex += 1
        
        var gotZig = false
        var gotZag = false
        var gotAutoSeries = false
        var gotAutoCommon = false
        
        while currIndex < 9
        {
            lineElements = lineArray[currIndex].components(separatedBy: .whitespaces)
            
            if let voltage = Double(lineElements[0])
            {
                if voltage == 0.0
                {
                    currIndex += 1
                    terminals.append(nil)
                    continue
                }
                
                var VA = 0.0
                if let num = Double(lineElements[1])
                {
                    VA = num * 1000.0
                }
                else
                {
                    throw DesignFileError(info: "\(currIndex)", type: .InvalidValue)
                }
                
                var termName = ""
                
                var newTermNum:Int = 0
                if let num = Int(lineElements[3])
                {
                    newTermNum = num
                }
                else
                {
                    throw DesignFileError(info: "\(currIndex)", type: .InvalidValue)
                }
                
                var currDir = 0
                if let num = Int(lineElements[4])
                {
                    currDir = num
                }
                else
                {
                    throw DesignFileError(info: "\(currIndex)", type: .InvalidValue)
                }
                
                
                let connString = lineElements[2]
                var connection:Terminal.TerminalConnection = .wye
                
                if currIndex == 1
                {
                    termName = "HV"
                }
                else if currIndex == 2
                {
                    termName = "LV"
                }
                else if newTermNum > 2
                {
                    termName = "TV"
                }
                else if newTermNum != 0
                {
                    termName = "RV"
                }
                
                if connString == "D"
                {
                    connection = .delta
                }
                else if connString == "ZIG"
                {
                    connection = .zig
                    gotZig = true
                    termName = "ZIG"
                }
                else if connString == "ZAG"
                {
                    connection = .zag
                    gotZag = true
                    termName = "ZAG"
                }
                else if connString == "AS" // auto series
                {
                    connection = .auto_series
                    gotAutoSeries = true
                    newTermNum = 1
                    termName = "Auto-S"
                }
                else if connString == "AC" // auto common
                {
                    connection = .auto_common
                    gotAutoCommon = true
                    newTermNum = 2
                    termName = "Auto-C"
                }
                else if connString != "Y"
                {
                    throw DesignFileError(info: "\(newTermNum)", type: .InvalidConnection)
                }
                
                let newTerm = Terminal(name: termName, voltage: voltage, VA: VA, connection: connection, currDir:currDir, termNum: newTermNum)
                
                terminals.append(newTerm)
            }
            else
            {
                throw DesignFileError(info: "\(currIndex)", type: .InvalidValue)
            }
            
            currIndex += 1
        }
        
        // do a check to make sure that auto and zigzag connections are correctly done
        if gotZig != gotZag
        {
            throw DesignFileError(info: " Zigzag", type: .MissingComplementConnection)
        }
        if gotAutoCommon != gotAutoSeries
        {
            throw DesignFileError(info: "n Autotransformer", type: .MissingComplementConnection)
        }
        
        var rowMap:[Int?] = []
        lineElements = lineArray[currIndex].components(separatedBy: .whitespaces)
        
        for i in 0..<8
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
        
        for i in 0..<8
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
                let elecHt = Double(lineElements[i])! * mmPerInch
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
                let radialSpacerThickness = Double(lineElements[i])! * mmPerInch
                currIndex += 1
                
                // radial spacer widths
                lineElements = lineArray[currIndex].components(separatedBy: .whitespaces)
                let radialSpacerWidth = Double(lineElements[i])! * mmPerInch
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
                let insulationBetweenLayers = Double(lineElements[i])! * mmPerInch
                currIndex += 1
                
                // num Radial Ducts
                lineElements = lineArray[currIndex].components(separatedBy: .whitespaces)
                let numRadialDucts = Int(lineElements[i])!
                currIndex += 1
                
                // radial duct thickness
                lineElements = lineArray[currIndex].components(separatedBy: .whitespaces)
                let radialDuctDimn = Double(lineElements[i])! * mmPerInch
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
                let strandAxialDimn = Double(lineElements[i])! * mmPerInch
                currIndex += 1
                
                // strand radial dimension
                lineElements = lineArray[currIndex].components(separatedBy: .whitespaces)
                let strandRadialDimn = Double(lineElements[i])! * mmPerInch
                currIndex += 1
                
                // num strands per CTC
                lineElements = lineArray[currIndex].components(separatedBy: .whitespaces)
                let numStrandsCTC = Int(lineElements[i])!
                currIndex += 1
                
                // axial center gap
                lineElements = lineArray[currIndex].components(separatedBy: .whitespaces)
                let axialGapCenter = Double(lineElements[i])! * mmPerInch
                currIndex += 1
                
                // axial lower gap
                lineElements = lineArray[currIndex].components(separatedBy: .whitespaces)
                let axialGapLower = Double(lineElements[i])! * mmPerInch
                currIndex += 1
                
                // axial upper gap
                lineElements = lineArray[currIndex].components(separatedBy: .whitespaces)
                let axialGapUpper = Double(lineElements[i])! * mmPerInch
                currIndex += 1
                
                // bottom edge pack
                lineElements = lineArray[currIndex].components(separatedBy: .whitespaces)
                let bottomEdgePack = Double(lineElements[i])! * mmPerInch
                currIndex += 1
                
                // ID
                lineElements = lineArray[currIndex].components(separatedBy: .whitespaces)
                let windingID = Double(lineElements[i])! * mmPerInch
                currIndex += 1
                
                // overbuild allowance
                lineElements = lineArray[currIndex].components(separatedBy: .whitespaces)
                let overbuildAllowance = Double(lineElements[i])!
                currIndex += 1
                
                // max ground clearance
                lineElements = lineArray[currIndex].components(separatedBy: .whitespaces)
                let groundClearance = Double(lineElements[i])! * mmPerInch
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
                let internalTurnInsulation = Double(lineElements[i])! * mmPerInch
                currIndex += 1
                
                // skip the next 3
                currIndex += 3
                
                // strand insulatiom
                lineElements = lineArray[currIndex].components(separatedBy: .whitespaces)
                let strandInsulation = Double(lineElements[i])! * mmPerInch
                currIndex += 1
                
                // cable insulatiom
                lineElements = lineArray[currIndex].components(separatedBy: .whitespaces)
                let cableInsulation = Double(lineElements[i])! * mmPerInch
                
                // Algorithm to ascertain the winding type
                var wdgType:Winding.WindingType = .disc
                
                if !isSpiral && numAxialSections <= 4 && numRadialSections == 1
                {
                    wdgType = .sheet
                }
                else if isSpiral && numAxialSections == 1 && numRadialSections == 1
                {
                    wdgType = .helix
                }
                else if isSpiral && numAxialSections > 1 && numRadialSections > 1
                {
                    wdgType = .section
                }
                else if isSpiral && numRadialSections > 1
                {
                    wdgType = .layer
                }
                else if isMultistart
                {
                    wdgType = .multistart
                }
                
                let internalRadialTurnIns = (wdgType == .helix && numRadialDucts > 0 ? radialDuctDimn * Double(numRadialDucts) : 0.0)
                
                let turnDef = Winding.TurnDefinition(strandA: strandAxialDimn, strandR: strandRadialDimn, type: cableType, numStrands: numStrandsCTC, numCablesAxial: numAxialCables, numCablesRadial: numRadialCables, strandInsulation: strandInsulation, cableInsulation: cableInsulation, internalRadialInsulation: internalRadialTurnIns, internalAxialInsulation: internalTurnInsulation)
                
                // fix the terminal voltage for double-stacked windings
                if (isDoubleStack)
                {
                    terminals[termIndex - 1]!.nominalLineVolts /= 2.0
                }
                
                let newWinding = Winding(preferences: prefs.wdgPrefs, wdgType: wdgType, isSpiral: isSpiral, isDoubleStack: isDoubleStack, numTurns: Winding.NumberOfTurns(minTurns: minTurns, nomTurns: nomTurns, maxTurns: maxTurns), elecHt: elecHt, numAxialSections: numAxialSections, radialSpacer: Winding.RadialSpacer(thickness: radialSpacerThickness, width: radialSpacerWidth), numAxialColumns: numAxialColumns, numRadialSections: numRadialSections, radialInsulation: insulationBetweenLayers, ducts: Winding.RadialDucts(count: numRadialDucts, dim: radialDuctDimn), numRadialSupports: numRadialColumns, turnDef: turnDef, axialGaps: Winding.AxialGaps(center: axialGapCenter, bottom: axialGapLower, top: axialGapUpper), bottomEdgePack: bottomEdgePack, coilID: windingID, radialOverbuild: overbuildAllowance, groundClearance: groundClearance, terminal: terminals[termIndex - 1]!)
                
                self.windings.append(newWinding)
            }
            
            currIndex = wdgDataStartIndex
        }
        
        self.scFactor = assymetryFactor
        self.systemGVA = systemStrength
        
        self.InitializeWindings(prefs: prefs)
        
    }
}
