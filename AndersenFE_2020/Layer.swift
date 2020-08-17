//
//  Layer.swift
//  AndersenFE_2020
//
//  Created by Peter Huber on 2020-07-17.
//  Copyright © 2020 Peter Huber. All rights reserved.
//

import Foundation

/// A Layer is a "solid" radial section, made up of Segments (ie: this is similar to the "Andersen" definition of a "Layer")
class Layer:Codable {
    
    /// Andersen-accepted conductor materials
    enum ConductorMaterial:Int, Codable {
        case copper
        case aluminum
    }
    
    /// The backing store for the segments that make up the layer
    private var segArray:[Segment] = []
    
    /// The segments that make up the layer. It is assumed that the segment with the lowest dimension is first in the array, then subsequent arrays move closer towar the top.
    var segments:[Segment] {
        
        get {
            
            return self.segArray
        }
        
        set {
            
            for nextSeg in newValue
            {
                nextSeg.inLayer = self
            }
            
            self.segArray = newValue
        }
    }
    
    /// The number of spacer blocks ("radial spacers"), or "axial columns" in the Layer
    let numSpacerBlocks:Int
    
    /// The circumferential dimension of an axial column
    let spacerBlockWidth:Double
    
    /// The widning material used in the Layer
    let material:ConductorMaterial
    
    /// The current direction, which comes from the parent Terminal unless that value is 0, in which case we simply change it to 1
    var currentDirection:Int {
        get {
            
            if self.parentTerminal.currentDirection == 0
            {
                return 1
            }
            
            return self.parentTerminal.currentDirection
        }
    }
    
    /// The number of parallel axial groups in the Layer (either 1 or 2)
    let numberParallelGroups:Int
    
    /// The radial build of the Layer
    let radialBuild:Double
    
    /// The inner radius of the Layer
    let innerRadius:Double
    
    /// The Terminal to which this Layer belongs
    let parentTerminal:Terminal
    
    init(segments:[Segment] = [], numSpacerBlocks:Int, spacerBlockWidth:Double, material:ConductorMaterial, numberParallelGroups:Int, radialBuild:Double, innerRadius:Double, parentTerminal:Terminal)
    {
        self.numSpacerBlocks = numSpacerBlocks
        self.spacerBlockWidth = spacerBlockWidth
        self.material = material
        self.numberParallelGroups = numberParallelGroups
        self.radialBuild = radialBuild
        self.innerRadius = innerRadius
        self.parentTerminal = parentTerminal
        self.segments = segments
    }
    
    /// Convenience function to get the OD of a Layer
    func OD() -> Double
    {
        return 2.0 * (self.innerRadius + radialBuild)
    }
}
