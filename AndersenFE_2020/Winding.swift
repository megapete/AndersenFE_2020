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
    
    struct AxialGaps:Codable {
        let center:Double
        let bottom:Double
        let top:Double
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
    
    func InitializeLayers(preferences:PCH_AFE2020_Prefs, windingCenter:Double)
    {
        if !preferences.model0Terminals && self.terminal.andersenNumber == 0
        {
            return
        }
        
        let minLayerZ = windingCenter - self.elecHt / 2.0
        let maxLayerZ = minLayerZ + self.elecHt
        
        var numLayers = (preferences.modelRadialDucts ? self.ducts.count + 1 : 1)
        
        let turnsPerLayer = self.numTurns.maxTurns / Double(numLayers)
    }
}
