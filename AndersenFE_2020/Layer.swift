//
//  Layer.swift
//  AndersenFE_2020
//
//  Created by Peter Huber on 2020-07-17.
//  Copyright © 2020 Peter Huber. All rights reserved.
//

import Foundation

struct Layer {
    
    enum ConductorMaterial {
        case copper
        case aluminum
    }
    
    var segments:[Segment]
    
    let numSpacerBlocks:Int
    let spacerBlockWidth:Double
    
    let material:ConductorMaterial
    
    let currentDirection:Int
    
    let numberParallelGroups:Int
    
    let parentTerminalNumber:Int
    
    let radialBuild:Double
    
    let innerRadius:Double
}
