//
//  Winding.swift
//  AndersenFE_2020
//
//  Created by Peter Huber on 2020-07-19.
//  Copyright © 2020 Peter Huber. All rights reserved.
//

import Foundation

/// A Winding is essentialy an interface between the Excel-generated design model and the more "Andersen-friendly" model that this program uses.
class Winding:Codable {
    
    /// WindingType represents the different types of Windings that we can build
    enum WindingType:Int, Codable {
        case disc
        case helix
        case sheet
        case layer
        case section
        case multistart
    }
    
    /// Each winding has its own "preferences", which can be changed by the user
    var preferences:PCH_AFE2020_Prefs
    
    /// The type of winding
    var wdgType:WindingType
    
    /// The winding is a spiral
    let isSpiral:Bool
    
    /// The winding is a double stack
    let isDoubleStack:Bool
    
    /// The winding is a multistart
    var isMultiStart:Bool {
        get {
            return self.wdgType == .multistart
        }
    }
    
    /// Set if the winding is a regulating winding (ie: regulatingWindingLoops is non-nil)
    var isRegulating:Bool {
        get {
            return self.regulatingWindingLoops != nil
        }
    }
    
    /// For regulating windings, define the number of loops (this value is nil for other winding types)
    var regulatingWindingLoops:Int? = nil
    
    struct NumberOfTurns:Codable {
        
        let minTurns:Double
        let nomTurns:Double
        let maxTurns:Double
        
        func puPerTap(numSections:Int = 4) -> Double
        {
            let turnsPerSection = (self.maxTurns - self.minTurns) / Double(numSections)
            
            return turnsPerSection / nomTurns
        }
    }
    
    /// The winding has embedded taps
    var hasTaps:Bool {
        get {
            return self.numTurns.maxTurns != self.numTurns.nomTurns || self.numTurns.minTurns != self.numTurns.nomTurns
        }
    }
    
    /// The number of turns in the Winding
    let numTurns:NumberOfTurns
    
    /// The nominal electric height of the Winding
    let elecHt:Double
    
    /// The number of axial sections in the Winding (what this means depends on the type)
    let numAxialSections:Int
    
    struct RadialSpacer:Codable {
        let thickness:Double
        let width:Double
    }
    /// The radial spacer dimensions (thickness is the gap between axial sections)
    let radialSpacer:RadialSpacer
    
    /// The number of axial columns
    let numAxialColumns:Int
    
    /// The number of radial sections in the Winding (actually, the number of layers in the classic sense of the word)
    let numRadialSections:Int
    
    /// The solid insulation to use between radial sections
    let radialInsulation:Double
    
    struct RadialDucts:Codable {
        let count:Int
        let dim:Double
    }
    
    /// The number of radial ducts in the Winding and their radial dimension
    let ducts:RadialDucts
    
    /// The number of radial supports under (and within) the Winding
    let numRadialSupports:Int
    
    /// The different cable types that are used to compose a turn
    enum CableType:Int, Codable {
        case single
        case twin
        case CTC
    }
    
    /// A turn can be made up of any number of CableTypes
    struct TurnDefinition:Codable
    {
        let strandA:Double
        let strandR:Double
        let type:CableType
        let numStrands:Int
        let numCablesAxial:Int
        let numCablesRadial:Int
        let strandInsulation:Double // total
        let cableInsulation:Double // total
        let internalRadialInsulation:Double // ie: space between EACH cable
        let internalAxialInsulation:Double
        
        /// Function to get the overall (shrunk) dimensions of a single turn. Note that this routine assumes a 0.8 shrinkage factor for paper, and 1.0 for epoxy. It also assumes that all insulation is paper, except for the strand insulation of CTC, which is assumed to be epoxy.
        /// - Returns: The axial and radial dimensions of the turn after shrinking
        func Dimensions() -> (axial:Double, radial:Double)
        {
            let shrinkageInsulation = (self.type == .CTC ? 1.0 : 0.8)
            
            var cableA:Double = strandA + strandInsulation * shrinkageInsulation
            var cableR:Double = strandR + strandInsulation * shrinkageInsulation
            
            var cableDim = (axial:cableA, radial:cableR)
            
            if self.type == .CTC
            {
                cableA *= 2.0
                cableA += cableInsulation * shrinkageInsulation
                let numStrandsR = (numStrands + 1) / 2
                cableR = cableR * Double(numStrandsR) + cableInsulation * shrinkageInsulation
                cableDim = (axial:cableA, radial:cableR)
                
            }
            else if self.type == .twin
            {
                cableA += cableInsulation * shrinkageInsulation
                cableR *= 2.0
                cableR += cableInsulation * shrinkageInsulation
                cableDim = (axial:cableA, radial:cableR)
            }
            
            return (cableDim.axial * Double(numCablesAxial) + internalAxialInsulation * Double(numCablesAxial - 1), cableDim.radial * Double(numCablesRadial) + internalRadialInsulation * Double(numCablesRadial - 1))
        }
        
        func NumStrandsPerTurn() -> Int
        {
            let strandsPerCable = (self.type == .single ? 1 : (self.type == .twin ? 2 : numStrands))
            
            return strandsPerCable * self.numCablesRadial * self.numCablesAxial
        }
        
        func NumStrandsRadially() -> Int
        {
            let radialPerCable = (self.type == .single ? 1 : (self.type == .twin ? 2 : (numStrands + 1 ) / 2))
            
            return radialPerCable * numCablesRadial
        }
    }
    
    /// The turn definition for this winding
    let turnDef:TurnDefinition
    
    struct AxialGaps:Codable{
        
        let center:Double
        let bottom:Double
        let top:Double
        
        func overallGapZ(assumeSymmetry:Bool) -> Double
        {
            var useTop = self.top
            var useBottom = self.bottom
            
            if assumeSymmetry
            {
                useTop = max(self.top, self.bottom)
                useBottom = useTop
            }
            
            return self.center + useTop + useBottom
        }
        
        func count(assumeSymmetry:Bool) -> Int
        {
            var result = 0
            
            if self.center > 0.0
            {
                result += 1
            }
            
            if assumeSymmetry
            {
                if (self.bottom > 0.0 || self.top > 0.0)
                {
                    result += 2
                }
            }
            else
            {
                if self.bottom > 0.0
                {
                    result += 1
                }
                
                if self.top > 0.0
                {
                    result += 1
                }
            }
            
            return result
        }
    }
    
    /// Axial gaps (usually for taps, or to balance taps on a different winding)
    let axialGaps:AxialGaps
    
    /// The distance from the bottom yoke to the copper of this Winding
    let bottomEdgePack:Double
    
    /// The inner diameter of this winding
    let coilID:Double
    
    /// The radial overbuild factor (usually 1.06)
    let radialOverbuild:Double
    
    /// The recommended ground clearance for this winding
    let groundClearance:Double
    
    /// The Terminal to which this Winding belongs
    let terminal:Terminal
    
    /// The Layers that make up this winding
    var layers:[Layer] = []
    
    /// Errors that can be thrown by the Layer creation and modification routines
    struct LayerError:Error
    {
        enum errorType
        {
            case UnimplementedFeature
            case IllegalDesignIssue
        }
        
        let info:String
        let type:errorType
        
        var localizedDescription: String
        {
            get
            {
                if self.type == .UnimplementedFeature
                {
                    return "This feature has not been implemented: \(self.info)"
                }
                else if self.type == .IllegalDesignIssue
                {
                    return "An illegal design issue has been discovered: \(self.info)"
                }
                
                return "An unknown error occurred."
            }
        }
    }
    
    /// Designated initializer for the class, does not set the 'layers' member (the calling routine must call InitializeLayers to come up with an array of default Layers)
    init(preferences: PCH_AFE2020_Prefs, wdgType: WindingType, isSpiral:Bool, isDoubleStack:Bool, numTurns:NumberOfTurns, elecHt:Double, numAxialSections:Int, radialSpacer:RadialSpacer, numAxialColumns:Int, numRadialSections:Int, radialInsulation:Double, ducts:RadialDucts, numRadialSupports:Int, turnDef:TurnDefinition, axialGaps:AxialGaps, bottomEdgePack:Double, coilID:Double, radialOverbuild:Double, groundClearance:Double, terminal:Terminal)
    {
        self.preferences = preferences
        self.wdgType = wdgType
        self.isSpiral = isSpiral
        self.isDoubleStack = isDoubleStack
        self.numTurns = numTurns
        self.elecHt = elecHt
        self.numAxialSections = numAxialSections
        self.radialSpacer = radialSpacer
        self.numAxialColumns = numAxialColumns
        self.numRadialSections = numRadialSections
        self.radialInsulation = radialInsulation
        self.ducts = ducts
        self.numRadialSupports = numRadialSupports
        self.turnDef = turnDef
        self.axialGaps = axialGaps
        self.bottomEdgePack = bottomEdgePack
        self.coilID = coilID
        self.radialOverbuild = radialOverbuild
        self.groundClearance = groundClearance
        self.terminal = terminal
    }
    
    /// Convenience initializer that copies an existing Winding, including the 'layers' array (designed to be used for implementing Undo). Use this instead of '='.
    convenience init(srcWdg:Winding)
    {
        self.init(preferences: srcWdg.preferences, wdgType: srcWdg.wdgType, isSpiral:srcWdg.isSpiral, isDoubleStack:srcWdg.isDoubleStack, numTurns:srcWdg.numTurns, elecHt:srcWdg.elecHt, numAxialSections:srcWdg.numAxialSections, radialSpacer:srcWdg.radialSpacer, numAxialColumns:srcWdg.numAxialColumns, numRadialSections:srcWdg.numRadialSections, radialInsulation:srcWdg.radialInsulation, ducts:srcWdg.ducts, numRadialSupports:srcWdg.numRadialSupports, turnDef:srcWdg.turnDef, axialGaps:srcWdg.axialGaps, bottomEdgePack:srcWdg.bottomEdgePack, coilID:srcWdg.coilID, radialOverbuild:srcWdg.radialOverbuild, groundClearance:srcWdg.groundClearance, terminal:srcWdg.terminal)
        
        self.layers = srcWdg.layers
    }
    
    
    
    
    /// The current-carrying turns are the effective turns, and a SIGNED quantity, depending on the current direction
    func CurrentCarryingTurns() -> Double
    {
        var result = 0.0
        
        let parallelFactor = self.isDoubleStack ? 2.0 : 1.0
        
        for nextLayer in self.layers
        {
            for nextSegment in nextLayer.segments
            {
                result += nextSegment.totalTurns * Double(nextLayer.currentDirection)
            }
        }
        
        return result / parallelFactor
    }
    
    /// The no-load turns are the effective turns that make up the winding, regardless of whether they carry current.
    func NoLoadTurns() -> Double
    {
        var result = 0.0
        
        let parallelFactor = self.isDoubleStack ? 2.0 : 1.0
        
        for nextLayer in self.layers
        {
            for nextSegment in nextLayer.segments
            {
                result += nextSegment.totalTurns
            }
        }
        
        return result / parallelFactor
    }
    
    
    /// Initialize the 'layers' array based on the data currently in this Winding's properties. The old 'layers' array will be cleared.
    /// - Parameter windingCenter: The center of this Winding
    /// - Throws: Errors caused by unimplemented features or design errors
    func InitializeLayers(windingCenter:Double) throws {
        
        let preferences = self.preferences
        
        guard !preferences.modelInternalLayerTaps else {
            
            throw LayerError(info: "Embedded layer taps", type: .UnimplementedFeature)
        }
        
        // The calling routine should know better than to call this routine with a terminal number of 0, but just in case...
        if !preferences.model0Terminals && self.terminal.andersenNumber == 0
        {
            return
        }
        
        // start with the simple Z-values for the segments
        let minLayerZ = windingCenter - self.elecHt / 2.0
        let maxLayerZ = minLayerZ + self.elecHt
        
        // number of layers to model depends on whether we're modeling ducts
        let numLayers = (preferences.modelRadialDucts ? self.ducts.count + 1 : 1)
        
        // initialize the radial turns for a layer (or multi-start) winding
        var numTurnsRadiallyPerLayer = Double(self.numRadialSections) / Double(numLayers)
        if self.wdgType == .disc || self.wdgType == .sheet
        {
            numTurnsRadiallyPerLayer = self.numTurns.maxTurns / Double(self.numAxialSections) / Double(numLayers)
        }
        else if self.wdgType == .helix
        {
            numTurnsRadiallyPerLayer = 1.0 / Double(numLayers)
        }
        
        
        let turnsPerLayer = self.numTurns.maxTurns / Double(numLayers)
        
        let assumeGapSymmetry = preferences.upperLowerAxialGapsAreSymmetrical
        let numSegsPerLayer = 1 + self.axialGaps.count(assumeSymmetry: assumeGapSymmetry)
        
        // initialize an empty "default" list of Z-values
        var zList:[(min:Double, max:Double)] = []
        // initialize an empty "default" list of turns per segment
        var segmentTurns:[Double] = []
        
        if wdgType != .multistart && !self.hasTaps || ((self.wdgType == .layer || self.wdgType == .section) && !preferences.modelInternalLayerTaps) {
            
            if numSegsPerLayer == 1 // no axial gaps
            {
                zList.append((minLayerZ, maxLayerZ))
                
                segmentTurns = [turnsPerLayer]
            }
            else if numSegsPerLayer == 2 // one axial gap in the center of the winding
            {
                let bottomZmax = windingCenter - self.axialGaps.center / 2.0
                let topZmin = bottomZmax + self.axialGaps.center
                
                zList.append((minLayerZ, bottomZmax))
                zList.append((topZmin, maxLayerZ))
                
                segmentTurns = [turnsPerLayer / 2.0, turnsPerLayer / 2.0]
            }
            else if numSegsPerLayer == 3 // two axial gaps, each 1/4 of the length from the winding ends
            {
                if (self.axialGaps.center > 0.0) {
                    
                    throw LayerError(info: "Only top OR bottom axial gap", type: .UnimplementedFeature)
                }
                
                let bottomGapCenter = windingCenter - elecHt / 4.0
                let topGapCenter = bottomGapCenter + elecHt / 2.0
                
                zList.append((minLayerZ, bottomGapCenter - self.axialGaps.bottom / 2.0))
                zList.append((bottomGapCenter + self.axialGaps.bottom / 2.0, topGapCenter - self.axialGaps.top / 2.0))
                zList.append((topGapCenter + self.axialGaps.top / 2.0, maxLayerZ))
                
                segmentTurns = [turnsPerLayer / 4.0, turnsPerLayer / 2.0, turnsPerLayer / 4.0]
            }
            else if numSegsPerLayer == 4
            {
                let bottomGapCenter = windingCenter - elecHt / 4.0
                let topGapCenter = bottomGapCenter + elecHt / 2.0
                
                zList.append((minLayerZ, bottomGapCenter - self.axialGaps.bottom / 2.0))
                zList.append((bottomGapCenter + self.axialGaps.bottom / 2.0, windingCenter - self.axialGaps.center / 2.0))
                zList.append((windingCenter + self.axialGaps.center / 2.0, topGapCenter - self.axialGaps.top / 2.0))
                zList.append((topGapCenter + self.axialGaps.top / 2.0, maxLayerZ))
                
                segmentTurns = Array(repeating: turnsPerLayer / 4.0, count: 4)
            }
            
        }
        else if self.wdgType == .disc
        {
            // more complicated, there are offload taps in there (NOTE: we assume that there are 4 tap steps)
            
            let gapCount = self.axialGaps.count(assumeSymmetry: preferences.upperLowerAxialGapsAreSymmetrical)
            
            // first make sure that there are a sufficient number of axial gaps for the taps
            if (self.isDoubleStack && gapCount < 2) || (gapCount < 1)
            {
                throw LayerError(info: "Offload taps require an axial re-entrant gap at each tapping break.", type: .IllegalDesignIssue)
            }
            
            if self.isDoubleStack
            {
                let tapSectionTurns = self.numTurns.nomTurns / 2.0 * self.numTurns.puPerTap()
                let nonTapSectionTurns = self.numTurns.maxTurns / 2.0 - 4.0 * tapSectionTurns
                
                let tapSectionZ = (self.elecHt - self.axialGaps.overallGapZ(assumeSymmetry: preferences.upperLowerAxialGapsAreSymmetrical)) / 2.0 * self.numTurns.puPerTap()
                
                let tapCenter1 = windingCenter - elecHt / 4.0
                let tapCenter2 = windingCenter + elecHt / 4.0
                
                var useTopGap = self.axialGaps.top
                var useBottomGap = self.axialGaps.bottom
                
                if preferences.upperLowerAxialGapsAreSymmetrical
                {
                    useTopGap = max(useTopGap, useBottomGap)
                    useBottomGap = useTopGap
                }
                
                var currentBottomZ = minLayerZ
                var currentTopZ = tapCenter1 - useBottomGap / 2.0 - 2.0 * tapSectionZ
                
                // coil bottom to tap F
                zList.append((currentBottomZ, currentTopZ))
                segmentTurns.append(nonTapSectionTurns)
                currentBottomZ = currentTopZ
                currentTopZ += tapSectionZ
                // tap F to tap D
                zList.append((currentBottomZ, currentTopZ))
                segmentTurns.append(tapSectionTurns)
                currentBottomZ = currentTopZ
                currentTopZ += tapSectionZ
                // tap D to tap B
                zList.append((currentBottomZ, currentTopZ))
                segmentTurns.append(tapSectionTurns)
                
                currentBottomZ = currentTopZ + useBottomGap
                currentTopZ += currentBottomZ + tapSectionZ
                // tap A to tap C
                zList.append((currentBottomZ, currentTopZ))
                segmentTurns.append(tapSectionTurns)
                currentBottomZ = currentTopZ
                currentTopZ += tapSectionZ
                // tap C to tap E
                zList.append((currentBottomZ, currentTopZ))
                segmentTurns.append(tapSectionTurns)
                currentBottomZ = currentTopZ
                currentTopZ = windingCenter - self.axialGaps.center / 2.0
                // tap E to coil center (minus half of the center gap, if any)
                zList.append((currentBottomZ, currentTopZ))
                segmentTurns.append(nonTapSectionTurns)
                
                // coil center (plus half the center gap, if any) to tap E
                currentBottomZ = windingCenter + self.axialGaps.center / 2.0
                currentTopZ = tapCenter2 - useTopGap / 2.0 - 2.0 * tapSectionZ
                zList.append((currentBottomZ, currentTopZ))
                segmentTurns.append(nonTapSectionTurns)
                // tap E to tap C
                currentBottomZ = currentTopZ
                currentTopZ += tapSectionZ
                zList.append((currentBottomZ, currentTopZ))
                segmentTurns.append(tapSectionTurns)
                // tap C to tap A
                currentBottomZ = currentTopZ
                currentTopZ += tapSectionZ
                zList.append((currentBottomZ, currentTopZ))
                segmentTurns.append(tapSectionTurns)
                
                // tap B to tap D
                currentBottomZ = currentTopZ + useTopGap
                currentTopZ = currentBottomZ + tapSectionZ
                zList.append((currentBottomZ, currentTopZ))
                segmentTurns.append(tapSectionTurns)
                // tap D to tap F
                currentBottomZ = currentTopZ
                currentTopZ += tapSectionZ
                zList.append((currentBottomZ, currentTopZ))
                segmentTurns.append(tapSectionTurns)
                // tap F to coil top
                currentBottomZ = currentTopZ
                currentTopZ = maxLayerZ
                zList.append((currentBottomZ, currentTopZ))
                segmentTurns.append(nonTapSectionTurns)
                
            }
            else
            {
                let tapSectionTurns = self.numTurns.nomTurns * self.numTurns.puPerTap()
                let nonTapSectionTurns = self.numTurns.maxTurns - 4.0 * tapSectionTurns
                
                let tapSectionZ = (self.elecHt - self.axialGaps.overallGapZ(assumeSymmetry: preferences.upperLowerAxialGapsAreSymmetrical)) * self.numTurns.puPerTap()
                
                let tapCenter1 = windingCenter
                
                var currentBottomZ = minLayerZ
                var currentTopZ = tapCenter1 - self.axialGaps.center / 2.0 - 2.0 * tapSectionZ
                
                // coil bottom to tap F
                zList.append((currentBottomZ, currentTopZ))
                segmentTurns.append(nonTapSectionTurns)
                currentBottomZ = currentTopZ
                currentTopZ += tapSectionZ
                // tap F to tap D
                zList.append((currentBottomZ, currentTopZ))
                segmentTurns.append(tapSectionTurns)
                currentBottomZ = currentTopZ
                currentTopZ += tapSectionZ
                // tap D to tap B
                zList.append((currentBottomZ, currentTopZ))
                segmentTurns.append(tapSectionTurns)
                
                currentBottomZ = currentTopZ + self.axialGaps.center
                currentTopZ += currentBottomZ + tapSectionZ
                // tap A to tap C
                zList.append((currentBottomZ, currentTopZ))
                segmentTurns.append(tapSectionTurns)
                currentBottomZ = currentTopZ
                currentTopZ += tapSectionZ
                // tap C to tap E
                zList.append((currentBottomZ, currentTopZ))
                segmentTurns.append(tapSectionTurns)
                currentBottomZ = currentTopZ
                currentTopZ = maxLayerZ
                // tap E to coil center (minus half of the center gap, if any)
                zList.append((currentBottomZ, currentTopZ))
                segmentTurns.append(nonTapSectionTurns)

            }
        }
        else if self.wdgType == .multistart
        {
            if self.hasTaps
            {
                throw LayerError(info: "Multistart windings can not have offload taps!", type: .IllegalDesignIssue)
            }
            
            // Take a stab at the helix dimension by assuming that the number of 'loops' is equal to the number of axial cables.
            // This means that multi-start windings default to regulating windings
            // This can always be changed later by the user.
            let loops = Double(self.turnDef.numCablesAxial)
            self.regulatingWindingLoops = self.turnDef.numCablesAxial
            
            let helixAddition = self.preferences.multiStartElecHtIsToCenter ? self.turnDef.Dimensions().axial : 0.0
            
            let oneStartAxialDimn = self.turnDef.Dimensions().axial / loops
            
            var currentBottomZ = minLayerZ - helixAddition / 2.0
            
            for _ in 0..<Int(self.numTurns.maxTurns)
            {
                for _ in 0..<self.turnDef.numCablesAxial
                {
                    zList.append((currentBottomZ, currentBottomZ + oneStartAxialDimn))
                    currentBottomZ += oneStartAxialDimn
                }
            }
            
            // I'm not sure this is the way that this whole thing will actually work for regulating windings, but we'll use it for now...
            segmentTurns = Array(repeating: 1.0, count: self.turnDef.numCablesAxial * Int(self.numTurns.maxTurns))
        }
        else
        {
            var wdgString = "helical"
            if wdgType == .section
            {
                wdgString = "section"
            }
            else if wdgType == .sheet
            {
                wdgString = "sheet"
            }
        
            throw LayerError(info: "Taps for \(wdgString)-type windings", type: .UnimplementedFeature)
        }
        
        var nextIR = self.coilID / 2.0
        let copperRadialBuild = numTurnsRadiallyPerLayer * self.turnDef.Dimensions().radial + (preferences.modelRadialDucts ? 0.0 : Double(self.ducts.count) * self.ducts.dim)
        
        var layerSegments:[Segment] = []
        let strandsRadiallyPerLayer:Int = Int(ceil(numTurnsRadiallyPerLayer)) * self.turnDef.NumStrandsRadially()
        
        var zIndex = 0
        for zPair in zList
        {
            let newSegment = Segment(strandA: self.turnDef.strandA, strandR: self.turnDef.strandR, strandsPerLayer: strandsRadiallyPerLayer, strandsPerTurn: self.turnDef.NumStrandsPerTurn(), activeTurns: segmentTurns[zIndex], totalTurns: segmentTurns[zIndex], minZ: zPair.min, maxZ: zPair.max)
            
            layerSegments.append(newSegment)
            
            zIndex += 1
        }
        
        self.layers.removeAll()
        
        for _ in 0..<numLayers
        {
            let newLayer = Layer(segments: layerSegments, numSpacerBlocks: self.numAxialColumns, spacerBlockWidth: self.radialSpacer.width, material: .copper, currentDirection: self.terminal.currentDirection, numberParallelGroups: (self.isDoubleStack ? 2 : 1), radialBuild: copperRadialBuild, innerRadius: nextIR, parentTerminal: self.terminal)
            
            self.layers.append(newLayer)
            
            nextIR += copperRadialBuild + self.ducts.dim
        }
    }
}
