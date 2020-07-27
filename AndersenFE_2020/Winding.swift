//
//  Winding.swift
//  AndersenFE_2020
//
//  Created by Peter Huber on 2020-07-19.
//  Copyright © 2020 Peter Huber. All rights reserved.
//

import Foundation

/// A Winding is essentialy an interface between the Excel-generated design model and the more "Andersen-friendly" model that this program uses.
struct Winding:Codable {
    
    /// WindingType represents the different types of Windings that we can build
    enum WindingType:Int, Codable {
        case disc
        case helix
        case sheet
        case layer
        case section
        case multistart
    }
    
    /// The type of winding
    var wdgType:WindingType
    
    /// The winding is a spiral
    let isSprial:Bool
    
    /// The winding is a double stack
    let isDoubleStack:Bool
    
    /// The winding is a multistart
    var isMultiStart:Bool {
        get {
            return self.wdgType == .multistart
        }
    }
    
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
    }
    
    /// The turn definition for this winding
    let turnDef:TurnDefinition
    
    struct AxialGaps:Codable{
        
        let center:Double
        let bottom:Double
        let top:Double
        
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
    
    func InitializeLayers(preferences:PCH_AFE2020_Prefs, windingCenter:Double) throws {
        
        //
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
        var numLayers = (preferences.modelRadialDucts ? self.ducts.count + 1 : 1)
        
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
            // more complicated, there are offload taps in there
            
            let gapCount = self.axialGaps.count(assumeSymmetry: preferences.upperLowerAxialGapsAreSymmetrical)
            
            // first make sure that there are a sufficient number of axial gaps for the taps
            if (self.isDoubleStack && gapCount < 2) || (gapCount < 1)
            {
                throw LayerError(info: "Offload taps require an axial re-entrant gap at each tapping break.", type: .IllegalDesignIssue)
            }
            
            if self.isDoubleStack
            {
                
            }
            else
            {
                
            }
        }
        else if self.wdgType == .multistart
        {
            if self.hasTaps
            {
                throw LayerError(info: "Multistart windings can not have offload taps!", type: .IllegalDesignIssue)
            }
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
    }
}
