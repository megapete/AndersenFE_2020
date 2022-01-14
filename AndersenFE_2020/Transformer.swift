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
    
    var txfoDesc:String = ""
    
    let numPhases:Int
    
    private var mvaStore:Double = 0.0
    
    var MVA:Double {
        get {
            
            return self.mvaStore
        }
    }
    
    let frequency:Double
    
    let tempRise:Double
    
    struct Core:Codable {
        let diameter:Double
        let windHt:Double
    }
    
    let core:Core
    
    var scFactor:Double
    
    var systemGVA:Double
    
    var puForceImpedance:Double = 0.0
    
    var windings:[Winding] = []
    
    var wdgTerminals:[Terminal?] = []
    
    /// Special array that only has proper entries if there is a zigzag connection on the transformer. Zig is at index 0, zag is at index 1.
    var zigzagTerms:[Int] = [0, 0]
    
    /// Special value that is only non-nil if there is a zigzag connection and the routine CheckForWarnings() has been called
    var zeroSequenceImpedance:Double? = nil
    
    /// V/N reference terminal
    var vpnRefTerm:Int? = nil
    
    /// NI reference terminal
    var niRefTerm:Int? = nil
    
    var niDistribution:[Double]? = nil
    
    var scResults:ImpedanceAndScData? = nil
    
    /// Straightforward init function (designed for the copy() function below)
    init(numPhases:Int, frequency:Double, tempRise:Double, core:Core, scFactor:Double, systemGVA:Double, forceImpedance:Double, windings:[Winding], terminals:[Terminal?], vpnRefTermNum:Int? = nil, niRefTermNum:Int? = nil, niDistribution:[Double]? = nil, scResults:ImpedanceAndScData? = nil, zigzagTerms:[Int])
    {
        self.numPhases = numPhases
        self.frequency = frequency
        self.tempRise = tempRise
        self.core = core
        self.scFactor = scFactor
        self.systemGVA = systemGVA
        self.puForceImpedance = forceImpedance
        self.vpnRefTerm = vpnRefTermNum
        self.niRefTerm = niRefTermNum
        self.niDistribution = niDistribution
        self.scResults = scResults
        self.wdgTerminals = []
        self.zigzagTerms = zigzagTerms
        self.zeroSequenceImpedance = nil // this will get calculated later
        
        var index = 0
        for nextWdg in windings
        {
            let oldTerm = nextWdg.terminal
            let newTerm = Terminal(name: oldTerm.name, lineVoltage: oldTerm.nominalLineVolts, noloadLegVoltage: oldTerm.noloadLegVoltage, VA: oldTerm.VA, connection: oldTerm.connection, currDir: oldTerm.currentDirection, termNum: oldTerm.andersenNumber)
            
            self.windings.append(Winding(srcWdg: nextWdg, terminal: newTerm))
            self.wdgTerminals.append(newTerm)
            
            index += 1
        }
    }
    
    /// Function to check for warnings in the current scResults and return an array of objects that are  used by the DataView class
    func CheckForWarnings() -> [DataView.WarningData]
    {
        // some constants used in this function (should really be part of a preferences file or something that the user can change - maybe one day)
        let endThrustWarningLimit = 100000.0 * newtonsPerlb
        let unworkedCopperLimit = 9000.0 * nmm2PerPsi
        let workedCopperLimit = 20000 * nmm2PerPsi
        let spacerBlockWarningLimit = 3500.0 * nmm2PerPsi // based on my experience, anything over 3500 is a bitch to compress
        let spacerBlockMaxLimit = 80.0 // MPa, or N/mm2
        var result:[DataView.WarningData] = []
        
        // check if there are zigzag terminals and if so, calculate their zero-sequence impedance. The strategy here is to create a copy of the current transformer, then (in the copy) get rid of all non-zigzag terminals and windings. The zig and zag are then converted to delta-delta and we do a simple run of Andersen on it (like the old days in the Excel design file). The copied transformer is then simply discarded. This all works very well, by the way.
        if self.zigzagTerms[0] > 0
        {
            let zigzagConn = self.Copy()
            zigzagConn.scResults = nil
            
            let zigTermNum = self.zigzagTerms[0]
            let zagTermNum = self.zigzagTerms[1]
            
            let oldWindings = zigzagConn.windings
            zigzagConn.windings = []
            zigzagConn.wdgTerminals = []
            
            var currDir = -1
            var nextTermNum = 1
            for nextWdg in oldWindings
            {
                let oldTerm = nextWdg.terminal
                
                if oldTerm.andersenNumber == zigTermNum || oldTerm.andersenNumber == zagTermNum
                {
                    let newTerm = Terminal(name: oldTerm.name, lineVoltage: oldTerm.nominalLineVolts, noloadLegVoltage: oldTerm.noloadLegVoltage, VA: oldTerm.VA, connection: .delta, currDir: currDir, termNum: nextTermNum)
                    
                    zigzagConn.windings.append(Winding(srcWdg: nextWdg, terminal: newTerm))
                    zigzagConn.wdgTerminals.append(newTerm)
                    
                    currDir *= -1
                    nextTermNum += 1
                }
            }
            
            zigzagConn.vpnRefTerm = 1
            zigzagConn.niRefTerm = 1
            
            let refTerm = try! zigzagConn.TerminalsFromAndersenNumber(termNum: 1)
            
            do
            {
                let _ = try zigzagConn.AmpTurns(forceBalance: true, showDistributionDialog: false)
                
                let fld12txfo = try zigzagConn.QuickFLD12transformer()
                
                if let fld12output = PCH_FLD12_Library.runFLD12withTxfo(fld12txfo, outputType: .metric)
                {
                    zigzagConn.scResults = ImpedanceAndScData(andersenOutput: fld12output)
                }
                else
                {
                    let alert = NSAlert()
                    alert.messageText = "Calculation of impedance & forces for zigzag connection failed!"
                    alert.informativeText = "Do you wish to save the Andersen input file before reverting to the last transformer?"
                    alert.addButton(withTitle: "Save file")
                    alert.addButton(withTitle: "Continue")
                    alert.alertStyle = .critical
                    
                    if alert.runModal() == .alertFirstButtonReturn
                    {
                        let fileString = PCH_FLD12_Library.createFLD12InputFile(withTxfo: fld12txfo)
                        
                        let savePanel = NSSavePanel()
                        savePanel.message = "Save the Andersen Input File"
                        if (savePanel.runModal() == .OK)
                        {
                            try fileString.write(to: savePanel.url!, atomically: false, encoding: .utf8)
                        }
                    }
                }
            }
            catch
            {
                let alert = NSAlert(error: error)
                alert.alertStyle = .critical
                let _ = alert.runModal()
            }
            
            if let scResult = zigzagConn.scResults
            {
                let refTermLegVolts = try! zigzagConn.TerminalLineVoltage(terminal: zigzagConn.niRefTerm!)
                
                let zeroSequenceOhms = refTermLegVolts * scResult.puImpedance / refTerm[0].nominalAmps
                self.zeroSequenceImpedance = zeroSequenceOhms
                let z0 = String(format: "%0.2f", zeroSequenceOhms)
                // DLog("Zero-Sequence Ohms: \(zeroSequenceOhms)")
                
                result.append(DataView.WarningData(string: "ZigZag Z0: \(z0) \u{3A9}/ph", level: .information, wordsToHighlight: []))
            }
        }
        
        // check whether any of the windings' centers is off from the transformer center by more than 0.1mm
        let idealCenter = self.GetWindingsCenter()
        for nextWdg in self.windings
        {
            if nextWdg.terminal.andersenNumber == 0
            {
                continue
            }
            
            if fabs(nextWdg.axialCenter - idealCenter) > 0.1
            {
                let offset = String(format: "%0.1f", fabs(nextWdg.axialCenter - idealCenter))
                result.append(DataView.WarningData(string: "The axial center of winding '\(nextWdg.terminal.name)' is offset from the ideal center by \(offset) mm", level: .caution, wordsToHighlight: [13]))
            }
        }
        
        // check for actual problems here
        // TODO: Add tilting calculation
        
        if let currResults = self.scResults
        {
            for nextWdg in self.windings
            {
                if nextWdg.terminal.andersenNumber == 0
                {
                    continue
                }
                
                for nextLayer in nextWdg.layers
                {
                    for nextSegment in nextLayer.segments
                    {
                        if let segSCdata = currResults.SegmentData(andersenSegNum: nextSegment.andersenSegNum)
                        {
                            // make sure that inner windings have enough radial supports
                            let actualRadialSupports = Double(nextWdg.numRadialSupports)
                            let requiredRadialSupports = segSCdata.scMinSpacerBars
                            
                            if actualRadialSupports < requiredRadialSupports
                            {
                                result.append(DataView.WarningData(string: "Winding '\(nextWdg.terminal.name)' has only \(actualRadialSupports) radial supports (Andersen segment #\(nextSegment.andersenSegNum) requires \(requiredRadialSupports))", level: .critical, wordsToHighlight: [4, 11]))
                            }
                            else if actualRadialSupports / requiredRadialSupports <= 1.1
                            {
                                result.append(DataView.WarningData(string: "Winding '\(nextWdg.terminal.name)' has \(actualRadialSupports) radial supports (Andersen segment #\(nextSegment.andersenSegNum) requires \(requiredRadialSupports) )", level: .caution, wordsToHighlight: [3, 10]))
                            }
                            
                            let scHoopStress = segSCdata.scMaxTensionCompression
                            // These factors come from IEC 60076--5
                            let hoopFactor = scHoopStress > 0.0 ? 0.9 : nextWdg.turnDef.type == .CTC ? 0.6 : 0.35
                            let maxHoopStressWarning = unworkedCopperLimit * hoopFactor
                            let maxHoopStressCritical = workedCopperLimit * hoopFactor
                            
                            if abs(scHoopStress) > maxHoopStressCritical {
                                
                                let maxStress = String(format: "%0.2f", maxHoopStressCritical)
                                let hoopStress = String(format: "%0.2f", scHoopStress)
                                
                                let stressType = scHoopStress < 0 ? "compressive" : "hoop"
                                
                                result.append(DataView.WarningData(string: "Winding '\(nextWdg.terminal.name)' Segment #\(nextSegment.andersenSegNum) radial \(stressType) stress is \(hoopStress) N/sq.mm. Allowed: \(maxStress)", level: .critical, wordsToHighlight: [8, 11]))
                            }
                            else if abs(scHoopStress) > maxHoopStressWarning
                            {
                                let maxStress = String(format: "%0.2f", maxHoopStressWarning)
                                let hoopStress = String(format: "%0.2f", scHoopStress)
                                
                                let stressType = scHoopStress < 0 ? "compressive" : "hoop"
                                
                                result.append(DataView.WarningData(string: "Winding '\(nextWdg.terminal.name)' Segment #\(nextSegment.andersenSegNum) radial \(stressType) stress is \(hoopStress) N/sq.mm. Allowed: \(maxStress)", level: .caution, wordsToHighlight: [8, 11]))
                            }
                            
                            let scCombinedStress = segSCdata.scCombinedForce
                            let maxCombinedStressWarning = unworkedCopperLimit * 0.9
                            let maxCombinedStressCritical = workedCopperLimit * 0.9
                            
                            if scCombinedStress > maxCombinedStressCritical {
                                
                                let maxStress = String(format: "%0.2f", maxCombinedStressCritical)
                                let combinedStress = String(format: "%0.2f", scCombinedStress)
                                
                                result.append(DataView.WarningData(string: "Winding '\(nextWdg.terminal.name)' Segment #\(nextSegment.andersenSegNum) combined stress is \(combinedStress) N/sq.mm. Allowed: \(maxStress)", level: .critical, wordsToHighlight: [7, 10]))
                            }
                            else if scCombinedStress > maxCombinedStressWarning
                            {
                                let maxStress = String(format: "%0.2f", maxCombinedStressWarning)
                                let combinedStress = String(format: "%0.2f", scCombinedStress)
                                
                                result.append(DataView.WarningData(string: "Winding '\(nextWdg.terminal.name)' Segment #\(nextSegment.andersenSegNum) combined stress is \(combinedStress) N/sq.mm. Allowed: \(maxStress)", level: .caution, wordsToHighlight: [7, 10]))
                            }
                            
                            let scSpacerBlockForce = segSCdata.scForceInSpacerBlocks
                            let spacerBlockForce = String(format: "%0.2f", scSpacerBlockForce)
                            
                            var limitForce = String(format: "%0.2f", spacerBlockWarningLimit)
                            var warningString = "Difficult to compress over:"
                            var warningLevel = DataView.WarningLevel.caution
                            
                            if scSpacerBlockForce > spacerBlockWarningLimit {
                                
                                if scSpacerBlockForce > spacerBlockMaxLimit {
                                    
                                    limitForce = String(format: "%0.2f", spacerBlockMaxLimit)
                                    warningLevel = .critical
                                    warningString = "MUST be less than:"
                                }
                                
                                result.append(DataView.WarningData(string: "Winding '\(nextWdg.terminal.name)' Segment #\(nextSegment.andersenSegNum) spacer block force is \(spacerBlockForce) N/sq.mm. (\(warningString) \(limitForce) )", level: warningLevel, wordsToHighlight: [8, 14]))
                            }
                        }
                    }
                }
            }
            
            if currResults.totalThrustUpper >= endThrustWarningLimit || currResults.totalThrustLower >= endThrustWarningLimit
            {
                let tonnes = max(currResults.totalThrustLower, currResults.totalThrustUpper) * kgPerlb * lbsPerNewton / 1000.0
                let tonnage = String(format: "%0.2f", tonnes)
                
                result.append(DataView.WarningData(string: "End thrust at \(tonnage) tonnes. Confirm leg-plate strength.", level: .caution, wordsToHighlight: [3, 4]))
            }
        }
        
        if result.isEmpty
        {
            let noProblems = DataView.WarningData(string: "None", level: .information, wordsToHighlight: [0])
            result.append(noProblems)
        }
        
        return result
    }
    
    /// Function to create a PCH_FLD12_TxfoDetails struct (intended for use for the "continuous" impedance calculation)
    func QuickFLD12transformer() throws -> PCH_FLD12_TxfoDetails
    {
        do
        {
            var terminals = Array(AvailableTerminals())
            terminals.sort()
            
            // Due to some REALLY WEIRD programming by Andersen, we have to make sure that IF there's a zigzag connection, that the zig (connection code 6) MUST come before tha zag (connection code 5) in the ".inp" file. This should probably be taken care of in PCH_FLD12_Library, but that's written in Objective-C which I am less comfortable with these days.
            if self.zigzagTerms[0] != 0
            {
                let zigIndex = self.zigzagTerms[0]
                let zagIndex = self.zigzagTerms[1]
                
                let zigTermIndex = terminals.firstIndex(of: zigIndex)!
                let zagTermIndex = terminals.firstIndex(of: zagIndex)!
                
                if zagTermIndex < zigTermIndex
                {
                    terminals[zagTermIndex] = zigIndex
                    terminals[zigTermIndex] = zagIndex
                    DLog("Did a terminal switch for zigzag")
                }
            }
            
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
            
            var lowerAddition = 10000.0
            var upperAddition = 10000.0
            
            for nextWdg in self.windings
            {
                if nextWdg.extremeDimensions.bottom < lowerAddition
                {
                    lowerAddition = nextWdg.extremeDimensions.bottom
                }
                
                if self.core.windHt - nextWdg.extremeDimensions.top < upperAddition
                {
                    upperAddition = self.core.windHt - nextWdg.extremeDimensions.top
                }
                
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
                
                for nextTerm in self.wdgTerminals
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
            
            let newFld12Txfo = PCH_FLD12_TxfoDetails(id: "", inputUnits: 1, numPhases: Int32(self.numPhases), frequency: self.frequency, numberOfWoundLimbs: Int32(numWoundLimbs), lowerZ: -lowerAddition, upperZ: lowerAddition + self.core.windHt + upperAddition, coreDiameter: self.core.diameter, distanceToTank: tankDist, alcuShield: 0, sysSCgva: self.systemGVA, puImpedance: self.puForceImpedance, peakFactor: self.scFactor, numTerminals: Int32(fld12terminals.count), numLayers: Int32(fld12Layers.count), dispElon: 0, deAmount: 0, tankFactor: 0, legFactor: 0, yokeFactor: 0, scale: 1.0, numFluxLines: 25, terminals: fld12terminals, layers: fld12Layers)
            
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
        return Transformer(numPhases: self.numPhases, frequency: self.frequency, tempRise: self.tempRise, core: self.core, scFactor: self.scFactor, systemGVA: self.systemGVA, forceImpedance: self.puForceImpedance, windings: self.windings, terminals: self.wdgTerminals, vpnRefTermNum: self.vpnRefTerm, niRefTermNum: self.niRefTerm, niDistribution: self.niDistribution, scResults: self.scResults, zigzagTerms: self.zigzagTerms)
    }
    
    /// Some errors that can be thrown by various routines
    struct TransformerErrors:LocalizedError
    {
        enum errorType
        {
            case NoReferenceTerminalDefined
            case NoSuchTerminalNumber
            case UnexpectedZeroTurns
            case UnexpectedZeroVA
            case UnexpectedAmpTurnsOutOfBalance
            case MissingComplementConnection
            case UnimplementedFeature
        }
        
        let info:String
        let type:errorType
        
        var errorDescription: String?
        {
            get
            {
                if self.type == .NoReferenceTerminalDefined
                {
                    return "The reference VPN terminal has not been defined!"
                }
                else if self.type == .NoSuchTerminalNumber
                {
                    return "The terminal number \(info) does not exist in the model"
                }
                else if self.type == .UnexpectedZeroTurns
                {
                    return "The winding \(info) has zero effective turns (illegal situation)."
                }
                else if self.type == .UnexpectedZeroVA
                {
                    return "The terminal \(info) has an effective VA of 0 (illegal situation)."
                }
                else if self.type == .UnexpectedAmpTurnsOutOfBalance
                {
                    return "The transformer's ampere-turns are unexpectedly out of balance!"
                }
                else if self.type == .UnimplementedFeature
                {
                    return "This feature has not been implemented: \(info)"
                }
                else if self.type == .MissingComplementConnection
                {
                    return "A\(self.info) connection is missing one of its parts"
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
            if nextWdg.terminal.andersenNumber != 0
            {
                result = max(nextWdg.layers.last!.OD() / 2.0 + nextWdg.groundClearance, result)
            }
        }
        
        return result
    }
    
    /// Return the absolute value of the fraction of the total current-carrying turns of 'andersenNum' that are contributed by 'terminal'
    func FractionOfTerminal(terminal:Terminal, andersenNum:Int) -> Double
    {
        let fractionTurns = terminal.winding!.CurrentCarryingTurns() * Double(terminal.currentDirection)
        var totalTurns = fractionTurns
        
        for nextTerminal in self.wdgTerminals
        {
            if let term = nextTerminal
            {
                if term.winding!.coilID != terminal.winding!.coilID
                {
                    if term.andersenNumber == andersenNum
                    {
                        totalTurns += term.winding!.CurrentCarryingTurns() * Double(term.currentDirection)
                    }
                }
            }
        }
        
        return fabs(fractionTurns / totalTurns)
    }
    
    /// A quick way of finding the number of Terminals associated with a given Andersen terminal number (quick because it doesn't throw)
    func NumTerminalsFromAndersenNumber(termNum:Int) -> Int
    {
        var result = 0
        
        for nextTerm in self.wdgTerminals
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
        
        for nextTerm in self.wdgTerminals
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
            throw TransformerErrors(info: "\(termNum)", type: .NoSuchTerminalNumber)
        }
        
        return result
    }
    
    func OffsetWindingRadially(winding:Winding, deltaR:Double)
    {
        for nextWdg in self.windings
        {
            if nextWdg.coilID >= winding.coilID
            {
                nextWdg.OffsetWindingRadially(deltaR: deltaR)
            }
        }
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
            throw TransformerErrors(info: "\(termNum)", type: .NoSuchTerminalNumber)
        }
        
        return result
    }
    
    /// Return a set of Ints that represent the Andersen-terminals that are available
    func AvailableTerminals() -> Set<Int>
    {
        var result:Set<Int> = []
        
        for nextEntry in self.wdgTerminals
        {
            if let nextTerm = nextEntry, nextTerm.andersenNumber != 0
            {
                result.insert(nextTerm.andersenNumber)
            }
        }
        
        return result
    }
    
    func SetMVA(newMVA:Double, forceNIbalance:Bool) throws
    {
        if !forceNIbalance
        {
            self.mvaStore = newMVA
            return
        }
        
        do
        {
            
        }
        catch
        {
            
        }
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
        
        var autoFactor = 1.0
        
        let connection = terms[0].connection
        
        if connection == .auto_series
        {
            for nextTerm in self.wdgTerminals
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
                        
                        autoFactor = (seriesTurns + commonTurns) / seriesTurns
                    }
                }
            }
        }
        else if connection == .auto_common
        {
            for nextTerm in self.wdgTerminals
            {
                if let sTerm = nextTerm
                {
                    if sTerm.connection == .auto_series
                    {
                        var seriesTurns = CurrentCarryingTurns(terminal: sTerm.andersenNumber)
                        if seriesTurns == 0
                        {
                            seriesTurns = NoLoadTurns(terminal: sTerm.andersenNumber)
                        }
                        
                        var commonTurns = CurrentCarryingTurns(terminal: terminal)
                        if commonTurns == 0
                        {
                            commonTurns = NoLoadTurns(terminal: terminal)
                        }
                        
                        autoFactor = (seriesTurns + commonTurns) / seriesTurns
                    }
                }
            }
        }
        else if connection == .zig
        {
            // This is a bit weird. Andersen requires that the "per-term" MVA of zig-zag connected windings be equal to the sum total of the zig nd zag windings and that each of the terms be given that MVA. This is ONLY TRUE zigzag windings when they are one of the main windings (eg: a Dzn connection or something). If the transformer is a straightforward zigzag (grounding transformer), then each MVA should be the real MVA (ie not the sum) in each winding. This makes some sense to me since in a grounding transformer, the currents is single phase and the zig and zag windings currents are in opposing directions - just like a regular transformer leg. However, if the ZZ windings are treated as a 3-phase terminal, then phase angles get in the picture and the actual amp-turns in each zig (or zag) is actually 1/0.866 higher than what is needed to counter the other main winding(s) amp-turns. In that case, both zig and zag have currents running in the same direction. We assume that zig and zag are ALWAYS the same volts and amps, so we simply set the autofactor to 2 for the terminal.
            for nextTerm in self.wdgTerminals
            {
                if let zTerm = nextTerm
                {
                    if zTerm.connection == .zag && zTerm.currentDirection == terms[0].currentDirection
                    {
                        autoFactor = 2.0
                    }
                }
            }
        }
        else if connection == .zag
        {
            // See the blabber for .zig windings above for the logic used here
            for nextTerm in self.wdgTerminals
            {
                if let zTerm = nextTerm
                {
                    if zTerm.connection == .zig && zTerm.currentDirection == terms[0].currentDirection
                    {
                        autoFactor = 2.0
                    }
                }
            }
        }
        
        for nextTerm in terms
        {
            result += nextTerm.VA * autoFactor * Double(nextTerm.currentDirection)
        }
        
        return fabs(result)
    }
    
    /// Autofactor returns the ratio (seriesTurns + commonTurns) / seriesTurns IFF Andersen terminal 1 is auto-series and terminal 2 is auto-common. Otherwise, it returns 1.0. If any terminal other than 1 is auto-series (or any terminal other than 2 is auto-common, this function throws an error.
    func Autofactor() throws -> Double
    {
        do
        {
            let term1 = try self.TerminalsFromAndersenNumber(termNum: 1)
            var autoSeriesCount = 0
            
            for nextTerm in term1
            {
                if nextTerm.connection == .auto_series
                {
                    autoSeriesCount += 1
                }
            }
            
            let term2 = try self.TerminalsFromAndersenNumber(termNum: 2)
            var autoCommonCount = 0
            
            for nextTerm in term2
            {
                if nextTerm.connection == .auto_common
                {
                    autoCommonCount += 1
                }
            }
            
            if autoCommonCount == 0 && autoSeriesCount == 0
            {
                return 1.0
            }
            
            if autoCommonCount == 0 || autoCommonCount == 0
            {
                throw TransformerErrors(info: "n auto", type: .MissingComplementConnection)
            }
            
            let seriesTurns = self.CurrentCarryingTurns(terminal: 1)
            let commonTurns = self.CurrentCarryingTurns(terminal: 2)
            
            return (seriesTurns + commonTurns) / seriesTurns
        }
        catch
        {
            throw error
        }
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
            for nextTerm in self.wdgTerminals
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
                        
                        autoFactor = (seriesTurns + commonTurns) / seriesTurns
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
    
    /// This is a SIGNED quantity. It CANNOT be equal to 0.
    func ReferenceAmpTurns() throws -> Double
    {
        guard let refTerm = self.niRefTerm else
        {
            throw TransformerErrors(info: "", type: .NoReferenceTerminalDefined)
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
        
        guard va != 0.0 else
        {
            throw TransformerErrors(info: "\(refTerm)", type: .UnexpectedZeroVA)
        }
                
        return va / vpn
    }
    
    func TermName(termNum:Int) -> String?
    {
        for maybeTerminal in self.wdgTerminals
        {
            if let term = maybeTerminal
            {
                if term.andersenNumber == termNum
                {
                    return term.name
                }
            }
        }
        
        return nil
    }
    
    /// Total AmpereTurns for the Transformer in its current state (this value must equal 0 to be able to calculate impedance). If the reference terminal has not been defined, this function throws an error. Note that if forceBalance is true, then this function will modify all non-reference Terminals' 'nominalLineVoltage','VA', and 'currentDirection' fields to force amp-turns to be equal to 0.
    func AmpTurns(forceBalance:Bool, showDistributionDialog:Bool) throws -> Double
    {
        guard let refTerm = self.niRefTerm else {
            
            throw TransformerErrors(info: "", type: .NoReferenceTerminalDefined)
        }
        
        var termNames:[String?] = [nil, nil, nil, nil, nil, nil]
        for nextTermNum in self.AvailableTerminals()
        {
            termNames[nextTermNum - 1] = self.TermName(termNum: nextTermNum)
        }
        
        if forceBalance
        {
            var refTermNI = 0.0
            do
            {
                // refTermNI is a SIGNED quantity
                refTermNI = try self.ReferenceAmpTurns()
            }
            catch
            {
                throw error
            }
            
            let nonRefTerms = self.AvailableTerminals().subtracting([refTerm])
            
            var niArray:[Double] = Array(repeating: 0.0, count: 6)
            let refTermNIPercent = (refTermNI > 0.0 ? 100.0 : -100.0)
            niArray[refTerm - 1] = refTermNIPercent
            var niSum = refTermNI
            
            if nonRefTerms.count == 1
            {
                niArray[nonRefTerms.first! - 1] = -refTermNIPercent
                niSum = 0.0
            }
            else
            {
                for nextTerm in nonRefTerms
                {
                    var niTermLeg = 0.0
                    
                    for nextWdg in self.windings
                    {
                        if nextWdg.terminal.andersenNumber == nextTerm
                        {
                            let niTerm = nextWdg.terminal
                            
                            niTermLeg += nextWdg.CurrentCarryingTurns() * niTerm.nominalAmps * Double(niTerm.currentDirection)
                        }
                    }
                    
                    niArray[nextTerm - 1] = round(niTermLeg / fabs(refTermNI) * 100.0)
                    niSum += niTermLeg
                }
            }
            
            let availableTerms = self.AvailableTerminals()
            
            // check for an auto-connection, which requires that we jump in hoops to figure out amp-turns
            var gotAuto = false
            for nextWdg in self.windings
            {
                if nextWdg.terminal.connection == .auto_common || nextWdg.terminal.connection == .auto_series
                {
                    gotAuto = true
                    break
                }
            }
            
            if showDistributionDialog || fabs(niSum / refTermNI) > 0.001
            {
                let fixedTerm:Int? = gotAuto ? 1 : nil
                let calcTerm:Int? = gotAuto ? 2 : nil
                
                let niDlog = AmpTurnsDistributionDialog(termsToShow: availableTerms, termNames: termNames, fixedTerm: fixedTerm, autoCalcTerm: calcTerm, termPercentages: niArray, hideCancel:niSum != 0)
                
                // This HAS to be OK on return, but we test anyway
                if niDlog.runModal() == .OK
                {
                    niArray = niDlog.currentTerminalPercentages
                }
            }
            
            // DLog("NI-array: \(niArray)")
            
            do
            {
                let vpn = try self.VoltsPerTurn()
                
                for nextTerm in nonRefTerms
                {
                    let termsToFix = try TerminalsFromAndersenNumber(termNum: nextTerm)
                    
                    if fabs(niArray[nextTerm - 1]) < 1.0
                    {
                        for nextTermToZero in termsToFix
                        {
                            nextTermToZero.SetVoltsAndAmps(amps: 0.0)
                        }
                        
                        continue
                    }
                    
                    let niAbsolute = niArray[nextTerm - 1] / 100.0 * fabs(refTermNI)
                    
                    let effectiveTurns = CurrentCarryingTurns(terminal: nextTerm)
                    
                    guard effectiveTurns > 0.1  else
                    {
                        throw TransformerErrors(info: "terminal \(nextTerm)", type: .UnexpectedZeroTurns)
                    }
                    
                    let amps = niAbsolute / effectiveTurns
                    
                    for nextTermToFix in termsToFix
                    {
                        let volts = nextTermToFix.winding!.CurrentCarryingTurns() * vpn
                        
                        if volts < 0.1
                        {
                            nextTermToFix.SetVoltsAndAmps(amps: 0.0)
                        }
                        else
                        {
                            nextTermToFix.SetVoltsAndAmps(legVolts: volts, amps: amps)
                        }
                    }
                }
            }
            catch
            {
                throw error
            }
            
            return 0.0
        }
        else
        {
            // This branch simply uses the current VA and voltage (calculated using the current V/N, if any) to calculate total amp-turns and allows non-zero results (ie: the user has to figure it out)
            throw TransformerErrors(info: "Manual (user) calculation of terminal VAs to balance AmpTurns", type: .UnimplementedFeature)
        }
        
        
    }
    
    /// Calculate the V/N for the transformer given the reference terminal number. The voltage is the VECTOR SUM of the voltages assigned to the Terminals that make up the reference terminal. The turns are the VECTOR SUM of the current-carrying turns of the Terminals that make up the terminal. This function throws an error if the reference terminal has 0 active turns.
    func VoltsPerTurn() throws -> Double
    {
        guard let refTerm = self.vpnRefTerm else
        {
            throw TransformerErrors(info: "", type: .NoReferenceTerminalDefined)
        }
        
        var terminals:[Terminal] = []
        do
        {
            terminals = try self.TerminalsFromAndersenNumber(termNum: self.vpnRefTerm!)
        }
        catch
        {
            throw error
        }
        
        var result = 0.0
        
        // let legFactor = terminals[0].connectionFactor
        
        var noloadVoltageSum = 0.0
        for nextWdg in self.windings
        {
            if nextWdg.terminal.andersenNumber == refTerm
            {
                let currDir = Double(nextWdg.terminal.currentDirection)
                
                if nextWdg.CurrentCarryingTurns() != 0.0
                {
                    let parallelFactor = nextWdg.isDoubleStack && nextWdg.wdgType != .sheet ? 2.0 : 1.0
                    noloadVoltageSum += nextWdg.terminal.nominalLineVolts / nextWdg.terminal.connectionFactor * currDir / parallelFactor
                }
            }
        }
        
        noloadVoltageSum = fabs(noloadVoltageSum)
        
        let turnsToUse = self.CurrentCarryingTurns(terminal: refTerm)
        
        if turnsToUse == 0
        {
            throw TransformerErrors(info: terminals[0].name, type: .UnexpectedZeroTurns)
        }
        
        result = noloadVoltageSum / turnsToUse
        
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
    struct DesignFileError:LocalizedError
    {
        enum errorType
        {
            case InvalidDesignFile
            case InvalidFileVersion
            case InvalidValue
            case InvalidConnection
            case MissingComplementConnection
            case TooManySpecialTypes
            case IllegalTerminalNumber
            case IllegalAutoTerminalNumber
            case IllegalZigzagTerminalNumber
        }
        
        let info:String
        let type:errorType
        
        var errorDescription: String?
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
                else if self.type == .TooManySpecialTypes
                {
                    return "Cannot assign more than one \(self.info)-connected terminal."
                }
                else if self.type == .IllegalAutoTerminalNumber
                {
                    return "Auto-Series terminals must be assigned number 1; Auto-Common must be assigned number 2"
                }
                else if self.type == .IllegalTerminalNumber
                {
                    return "Could not assign an Andersen terminal number to winding: \(self.info)"
                }
                else if self.type == .IllegalZigzagTerminalNumber
                {
                    return "Zig terminal number MUST be Zag terminal number plus 1 (ie: consectuve numbers with Zag < Zig)"
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
            
            do
            {
                try nextWdg.InitializeLayers(windingCenter: GetWindingsCenter())
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
        
        var zigTerm = -1
        var zagTerm = -1
        
        var maxVA = -1.0
        var maxVAtermnum = 2
        
        var nameIndex = 1
        
        while currIndex < 9
        {
            lineElements = lineArray[currIndex].components(separatedBy: .whitespaces)
            
            if let voltage = Double(lineElements[0])
            {
                if voltage == 0.0
                {
                    currIndex += 1
                    wdgTerminals.append(nil)
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
                
                if VA == maxVA && newTermNum == 2
                {
                    maxVAtermnum = 2
                }
                else if VA > maxVA
                {
                    maxVA = VA
                    maxVAtermnum = newTermNum
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
                else if newTermNum != 0
                {
                    termName = "V\(nameIndex)"
                    nameIndex += 1
                }
                
                if connString == "D"
                {
                    connection = .delta
                }
                else if connString == "ZIG"
                {
                    if gotZig && newTermNum != zigTerm
                    {
                        throw DesignFileError(info: "Zig", type: .TooManySpecialTypes)
                    }
                    
                    if zagTerm > 0 && abs(zagTerm - newTermNum) != 1
                    {
                        throw DesignFileError(info: "", type: .IllegalZigzagTerminalNumber)
                    }
                    
                    zigTerm = newTermNum
                    self.zigzagTerms[0] = zigTerm
                    connection = .zig
                    gotZig = true
                    termName = "ZIG"
                }
                else if connString == "ZAG"
                {
                    if gotZag && newTermNum != zagTerm
                    {
                        throw DesignFileError(info: "Zag", type: .TooManySpecialTypes)
                    }
                    
                    if zigTerm > 0 && abs(zigTerm - newTermNum) != 1
                    {
                        throw DesignFileError(info: "", type: .IllegalZigzagTerminalNumber)
                    }
                    
                    zagTerm = newTermNum
                    self.zigzagTerms[1] = zagTerm
                    connection = .zag
                    gotZag = true
                    termName = "ZAG"
                }
                else if connString == "AS" // auto series
                {
                    if newTermNum != 1
                    {
                        throw DesignFileError(info: "", type: .IllegalAutoTerminalNumber)
                    }
                    
                    connection = .auto_series
                    gotAutoSeries = true
                    termName = "Auto-S"
                }
                else if connString == "AC" // auto common
                {
                    if newTermNum != 2
                    {
                        throw DesignFileError(info: "", type: .IllegalAutoTerminalNumber)
                    }
                    
                    connection = .auto_common
                    gotAutoCommon = true
                    termName = "Auto-C"
                }
                else if connString != "Y"
                {
                    throw DesignFileError(info: "\(newTermNum)", type: .InvalidConnection)
                }
                
                let connectionFactor = connection == .wye || connection == .auto_series || connection == .auto_common ? SQRT3 : 1.0
                let nlv = voltage / connectionFactor
                
                // ignore 0-level current directions, but set the current VA to zero
                if currDir == 0
                {
                    VA = 0.0
                    currDir = 1
                }
                
                let newTerm = Terminal(name: termName, lineVoltage: voltage, noloadLegVoltage: nlv, VA: VA, connection: connection, currDir:currDir, termNum: newTermNum)
                
                wdgTerminals.append(newTerm)
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
                var strandAxialDimn = Double(lineElements[i])! * mmPerInch
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
                let groundClearance = Double(lineElements[i]) != nil ? Double(lineElements[i])! * mmPerInch : 25.0
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
                
                if !isSpiral && !isMultistart && numAxialSections <= 4 && numRadialSections == 1
                {
                    wdgType = .sheet
                    
                    let axialSections = 1.0 + (axialGapCenter > 0 ? 1.0 : 0.0) + (axialGapLower > 0 ? 1.0 : 0.0) + (axialGapUpper > 0 ? 1.0 : 0.0)
                    
                    strandAxialDimn = strandAxialDimn / axialSections
                }
                else if isMultistart
                {
                    wdgType = .multistart
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
                
                let internalRadialTurnIns = (wdgType == .helix && numRadialDucts > 0 ? radialDuctDimn * Double(numRadialDucts) : 0.0)
                
                let multiStartWindingLoops = wdgType == .multistart ? numAxialCables : 0
                
                let turnDef = Winding.TurnDefinition(strandA: strandAxialDimn, strandR: strandRadialDimn, type: cableType, numStrands: numStrandsCTC, numCablesAxial: numAxialCables, numCablesRadial: numRadialCables, strandInsulation: strandInsulation, cableInsulation: cableInsulation, internalRadialInsulation: internalRadialTurnIns, internalAxialInsulation: internalTurnInsulation, multiStartWindingLoops: multiStartWindingLoops)
                
                // fix the terminal voltage for double-stacked windings
                if (isDoubleStack)
                {
                    let theTerm = wdgTerminals[termIndex - 1]!
                    let legV = theTerm.noloadLegVoltage
                    theTerm.SetVoltsAndAmps(legVolts: legV / 2.0)
                    // terminals[termIndex - 1]!.nominalLineVolts /= 2.0
                }
                
                let newWinding = Winding(preferences: prefs.wdgPrefs, wdgType: wdgType, isSpiral: isSpiral, isDoubleStack: isDoubleStack, numTurns: Winding.NumberOfTurns(minTurns: minTurns, nomTurns: nomTurns, maxTurns: maxTurns), elecHt: elecHt, numAxialSections: numAxialSections, radialSpacer: Winding.RadialSpacer(thickness: radialSpacerThickness, width: radialSpacerWidth), numAxialColumns: numAxialColumns, numRadialSections: numRadialSections, radialInsulation: insulationBetweenLayers, ducts: Winding.RadialDucts(count: numRadialDucts, dim: radialDuctDimn), numRadialSupports: numRadialColumns, turnDef: turnDef, axialGaps: Winding.AxialGaps(center: axialGapCenter, bottom: axialGapLower, top: axialGapUpper), bottomEdgePack: bottomEdgePack, coilID: windingID, radialOverbuild: overbuildAllowance, groundClearance: groundClearance, terminal: wdgTerminals[termIndex - 1]!)
                
                self.windings.append(newWinding)
            }
            
            currIndex = wdgDataStartIndex
        }
        
        self.scFactor = assymetryFactor
        self.systemGVA = systemStrength
        
        self.niRefTerm = maxVAtermnum
        
        self.windings.sort(by: {$0.coilID < $1.coilID})
        
        self.InitializeWindings(prefs: prefs)
        
    }
}
