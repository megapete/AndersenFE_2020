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
    
    var scResults:ImpedanceAndScData? = nil
    
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
        
        self.terminals = []
        
        var index = 0
        for nextWdg in windings
        {
            let oldTerm = nextWdg.terminal
            let newTerm = Terminal(name: oldTerm.name, voltage: oldTerm.nominalLineVolts, VA: oldTerm.VA, connection: oldTerm.connection, currDir: oldTerm.currentDirection, termNum: oldTerm.andersenNumber)
            
            self.windings.append(Winding(srcWdg: nextWdg, terminal: newTerm))
            self.terminals.append(newTerm)
            
            index += 1
        }
    }
    
    /// Function to create a PCH_FLD12_TxfoDetails struct (intended for use for the "continuous" impedance calculation)
    func QuickFLD12transformer() throws -> PCH_FLD12_TxfoDetails
    {
        do
        {
            var terminals = Array(AvailableTerminals())
            terminals.sort()
            
            var fld12terminals:[PCH_FLD12_Terminal] = []
            
            for nextTerm in terminals
            {
                let terms = try self.TerminalsFromAndersenNumber(termNum: nextTerm)
                
                let termMVA = try self.TotalVA(terminal: nextTerm) * 1.0E-6
                let termKV = try self.TerminalLineVoltage(terminal: nextTerm) * 1.0E-3
                
                let newFld12Term = PCH_FLD12_Terminal(number: Int32(nextTerm), connection: Int32(terms[0].AndersenConnection()), mva: termMVA, kv: termKV)
                
                fld12terminals.append(newFld12Term)
            }
            
            var nextLayerNum = 1
            var nextSegmentNum = 1
            
            var fld12Layers:[PCH_FLD12_Layer] = []
            
            for nextWdg in self.windings
            {
                for nextLayer in nextWdg.layers
                {
                    let newFld12Layer = nextLayer.FLD12layer(layernum: nextLayerNum, firstSegNum: nextSegmentNum)
                    
                    fld12Layers.append(newFld12Layer)
                    
                    nextLayerNum += 1
                    
                    nextSegmentNum = Int(newFld12Layer.lastSegment) + 1
                }
            }
            
            let tankDist = self.DistanceFromCoreCenterToTankWall() - self.MaxWindingOD() / 2.0
            
            var numWoundLimbs = 3
            if self.numPhases != 3
            {
                numWoundLimbs = 1
                
                for nextTerm in self.terminals
                {
                    if let term = nextTerm
                    {
                        if term.connection == .single_phase_two_legs
                        {
                            numWoundLimbs = 2
                            break
                        }
                    }
                }
            }
            
            let newFld12Txfo = PCH_FLD12_TxfoDetails(id: "", inputUnits: 1, numPhases: Int32(self.numPhases), frequency: self.frequency, numberOfWoundLimbs: Int32(numWoundLimbs), lowerZ: 0.0, upperZ: self.core.windHt, coreDiameter: self.core.diameter, distanceToTank: tankDist, alcuShield: 0, sysSCgva: self.systemGVA, puImpedance: 0.0, peakFactor: self.scFactor, numTerminals: Int32(fld12terminals.count), numLayers: Int32(fld12Layers.count), dispElon: 0, deAmount: 0, tankFactor: 0, legFactor: 0, yokeFactor: 0, scale: 1.0, numFluxLines: 25, terminals: fld12terminals, layers: fld12Layers)
            
            return newFld12Txfo
        }
        catch
        {
            throw error
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
            case UnexpectedZeroTurns
            case UnexpectedAmpTurnsOutOfBalance
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
                else if self.type == .UnexpectedZeroTurns
                {
                    return "The winding \(info) has zero effective turns (illegal situation)."
                }
                else if self.type == .UnexpectedAmpTurnsOutOfBalance
                {
                    return "The transformer's ampere-turns are unexpectedly out of balance!"
                }
                else if self.type == .UnimplementedFeature
                {
                    return "This feature has not been implemented: \(info)"
                }
                
                
                return "An unknown error occurred."
            }
        }
    }
    
    /// return the OD of the outermost winding
    func MaxWindingOD() -> Double
    {
        var result = 0.0
        
        for nextWdg in self.windings
        {
            if nextWdg.OD() > result
            {
                result = nextWdg.OD()
            }
        }
        
        return result
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
    
    /// A quick way of finding the number of Terminals associated with a given Andersen terminal number (quick because it doesn't throw)
    func NumTerminalsFromAndersenNumber(termNum:Int) -> Int
    {
        var result = 0
        
        for nextTerm in self.terminals
        {
            if let term = nextTerm
            {
                if term.andersenNumber == termNum
                {
                    result += 1
                }
            }
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
    
    func TotalVA(terminal:Int) throws -> Double
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
        
        var result = 0.0
        
        for nextTerm in terms
        {
            result += nextTerm.VA * Double(nextTerm.currentDirection)
        }
        
        return fabs(result)
    }
    
    /// The terminal line voltage is one of two possible voltages. If there are active (current-carrying) turns making up the terminal, then the line voltage is calculated using the current V/N and the active turns. If no turns are active, an error is thrown.
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
        
        let useTurns = CurrentCarryingTurns(terminal: terminal)
        if useTurns == 0
        {
            throw TransformerErrors(info: "Terminal#\(terminal)", type: .UnexpectedZeroTurns)
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
                
        return va / vpn
    }
    
    
    /// Total AmpereTurns for the Transformer in its current state (this value must equal 0 to be able to calculate impedance). If the reference terminal has not been defined, this function throws an error. Note that if forceBalance is true, then this function will modify all non-reference Terminals' 'nominalLineVoltage','VA', and 'currentDirection' fields to force amp-turns to be equal to 0.
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
                // refTermNI is a SIGNED quantity
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
                    let nonRefTerm = nonRefTerms.first!
                    let nonRefWdgs = try self.WindingsFromAndersenNumber(termNum: nonRefTerm)
                    
                    let totalEffectiveTurns = self.CurrentCarryingTurns(terminal: nonRefTerm)
                    
                    if totalEffectiveTurns == 0.0
                    {
                        let terminals = try self.TerminalsFromAndersenNumber(termNum: nonRefTerm)
                        throw TransformerErrors(info: "\(terminals[0].name)", type: .UnexpectedZeroTurns)
                    }
                    
                    // note that at this point, 'amps' is a SIGNED quantity, and can never be equal to zero
                    var amps = -refTermNI / totalEffectiveTurns
                    let ampsSign = amps < 0 ? -1 : 1
                    let termSign = self.CurrentDirection(terminal: nonRefTerm)
                    
                    // the Terminal function SetVoltsAndVA() will invert the currentDirection of a winding if the amps parameter is negative
                    if termSign == ampsSign
                    {
                        amps = fabs(amps)
                    }
                    else
                    {
                        amps = -fabs(amps)
                    }
                    
                    let vpn = try self.VoltsPerTurn()
                    
                    for nextWdg in nonRefWdgs
                    {
                        let voltage = nextWdg.CurrentCarryingTurns() * vpn
                        
                        nextWdg.terminal.SetVoltsAndVA(legVolts: voltage, amps: amps)
                    }
                }
                catch
                {
                    throw error
                }
            }
            else // there's more than just two terminals, which complicates things considerably
            {
                do
                {
                    // first we'll check what the current VA's for the various terminals come up with as amp-turns, and if they don't balance we'll bring up the AmpTurnsDistributionDialog
                    var termVoltAmps:[(termNum:Int, va:Double)] = []
                    
                    let availableTerms = self.AvailableTerminals()
                    
                    var maxNegativeVoltAmps = 0.0
                    
                    for nextAvailableTerm in availableTerms
                    {
                        var va = 0.0
                        
                        for nextWdg in self.windings
                        {
                            if nextWdg.terminal.andersenNumber == nextAvailableTerm
                            {
                                va += nextWdg.terminal.legVA * Double(nextWdg.terminal.currentDirection)
                            }
                        }
                        
                        if va < 0.0
                        {
                            // yes, there's a reason why I'm converting it to a positve
                            maxNegativeVoltAmps -= va
                        }
                        
                        termVoltAmps.append((nextAvailableTerm, va))
                    }
                    
                    var checkVA = 0.0
                    var niArray:[Double] = Array(repeating: 0.0, count: 6)
                    for nextTva in termVoltAmps
                    {
                        checkVA += nextTva.va
                        
                        niArray[nextTva.termNum - 1] = nextTva.va / maxNegativeVoltAmps * 100.0
                    }
                    
                    let oldDistribution = niArray
                    
                    if showDistributionDialog || checkVA != 0
                    {
                        let niDlog = AmpTurnsDistributionDialog(termsToShow: availableTerms, termPercentages: niArray, hideCancel:checkVA != 0)
                        
                        if niDlog.runModal() == .OK
                        {
                            niArray = niDlog.currentTerminalPercentages
                        }
                        
                        // not sure this is needed any more
                        self.niDistribution = niArray
                    }
                    
                    // At this point, niArray (array of "terminal" NI percentages) is guaranteed to be in balance. Set the Terminal VA's accordingly. The problem here is that the "terminal" VA is actually the _sum_ of the "Terminals" VAs. We assume that the "relative" current directions of the Terminals is maintained. That is, if the overall "terminal" current directions was positive, but after the dialog it is now negative, all of the associated Terminals' currentDirection properties must be reversed.
                    
                    if niArray != oldDistribution
                    {
                        let vpn = try self.VoltsPerTurn()
                        
                        for nextTerm in availableTerms
                        {
                            let termLegVA = maxNegativeVoltAmps * niArray[nextTerm - 1] / 100.0
                            let termLegV = vpn * self.NoLoadTurns(terminal: nextTerm)
                            var termAmps = termLegV == 0.0 ? 0.0 : termLegVA / termLegV
                            let ampsSign = termAmps < 0 ? -1 : 1
                            let termSign = self.CurrentDirection(terminal: nextTerm)
                            
                            // the Terminal function SetVoltsAndVA() will invert the currentDirection of a winding if the amps parameter is negative. If currentDirection of the Terminal is 0, it will be set to ampSign
                            if termSign == ampsSign || (termSign == 0 && ampsSign > 0)
                            {
                                termAmps = fabs(termAmps)
                            }
                            else
                            {
                                termAmps = -fabs(termAmps)
                            }
                            
                            for nextWdg in self.windings
                            {
                                if nextWdg.terminal.andersenNumber == nextTerm
                                {
                                    let wdgLegV = vpn * nextWdg.CurrentCarryingTurns()
                                    
                                    nextWdg.terminal.SetVoltsAndVA(legVolts: wdgLegV, amps: termAmps)
                                }
                            }
                        }
                    }
                    
                }
                catch
                {
                    throw error
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
        
        let legFactor = terminals[0].connectionFactor
        
        var noloadVoltageSum = 0.0
        for nextWdg in self.windings
        {
            if nextWdg.terminal.andersenNumber == refTerm
            {
                var currDir = Double(nextWdg.terminal.currentDirection)
                if currDir == 0.0
                {
                    currDir = 1.0
                }
                
                noloadVoltageSum += nextWdg.terminal.nominalLineVolts * currDir
            }
        }
        
        noloadVoltageSum = fabs(noloadVoltageSum)
        
        let turnsToUse = self.CurrentCarryingTurns(terminal: refTerm)
        
        if turnsToUse == 0
        {
            throw TransformerErrors(info: terminals[0].name, type: .UnexpectedZeroTurns)
        }
        
        result = noloadVoltageSum / legFactor / turnsToUse
        
        return result
    }
    
    /// A SIGNED value indicating the direction of current for the "terminal" (in the andersen sense). This function returns 0 if there are no turns
    func CurrentDirection(terminal:Int) -> Int
    {
        var turns = 0.0
        
        for nextWdg in self.windings
        {
            if nextWdg.terminal.andersenNumber == terminal
            {
                turns += nextWdg.CurrentCarryingTurns() * Double(nextWdg.terminal.currentDirection)
            }
        }
        
        if turns > 0
        {
            return 1
        }
        else if turns < 0
        {
            return -1
        }
        
        return 0
    }
    
    /// Unsigned value representing the number of turns associated with the give terminal. These are the effective "active" turns.
    func CurrentCarryingTurns(terminal:Int) -> Double
    {
        var result = 0.0
        
        for nextWdg in self.windings
        {
            if nextWdg.terminal.andersenNumber == terminal
            {
                var currDir = Double(nextWdg.terminal.currentDirection)
                if currDir == 0.0
                {
                    currDir = 1.0
                }
                
                result += nextWdg.CurrentCarryingTurns() * currDir
            }
        }
        
        return fabs(result)
    }
    
    /// Unsigned value representing the total number of turns associated with the given terminal. These are the effective "total" turns.
    func NoLoadTurns(terminal:Int) -> Double
    {
        var result = 0.0
        
        for nextWdg in self.windings
        {
            if nextWdg.terminal.andersenNumber == terminal
            {
                var currDir = Double(nextWdg.terminal.currentDirection)
                if currDir == 0.0
                {
                    currDir = 1.0
                }
                
                result += nextWdg.NoLoadTurns() * currDir
            }
        }
        
        return fabs(result)
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
                // DLog("Layer count: \(nextWdg.layers.count)")
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
                    
                    // ignore 0-level current directions
                    if currDir == 0
                    {
                        currDir = 1
                    }
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
                
                // cable insulation
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
