//
//  Layer.swift
//  AndersenFE_2020
//
//  Created by Peter Huber on 2020-07-17.
//  Copyright © 2020 Peter Huber. All rights reserved.
//

import Foundation

/// A Layer is a "solid" radial section, made up of Segments (ie: this is the "Andersen" definition of a "Layer")
struct Layer {
    
    /// Andersen-accepted conductor materials
    enum ConductorMaterial {
        case copper
        case aluminum
    }
    
    /// The segments that make up the layer. It is assumed that the segment with the lowest dimension is first in the array, then subsequent arrays move closer towar the top.
    var segments:[Segment]
    
    /// The number of spacer blocks ("radial spacers"), or "axial columns" in the Layer
    let numSpacerBlocks:Int
    
    /// The circumferential dimension of an axial column
    let spacerBlockWidth:Double
    
    /// The widning material used in the Layer
    let material:ConductorMaterial
    
    /// The current direction (-1, 1, or 0)
    let currentDirection:Int
    
    /// The number of parallel axial groups in the Layer (either 1 or 2)
    let numberParallelGroups:Int
    
    /// The radial build of the Layer
    let radialBuild:Double
    
    /// The inner radius of the Layer
    let innerRadius:Double
    
    /// The Terminal to which this Layer belongs
    let parentTerminal:Terminal
}
