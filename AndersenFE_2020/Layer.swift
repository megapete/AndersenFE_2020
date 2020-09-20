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
    
    /// function to create a  PCH_FLD12_Layer from self
    func FLD12layer(layernum:Int, firstSegNum:Int) -> PCH_FLD12_Layer
    {
        var nextSegNum = firstSegNum
        var fld12SegArray:[PCH_FLD12_Segment] = []
        
        for nextSeg in self.segments
        {
            fld12SegArray.append(nextSeg.FLD12section(segNum: nextSegNum))
            nextSegNum += 1
        }
        
        let newLayer = PCH_FLD12_Layer(number: Int32(layernum), lastSegment: Int32(nextSegNum - 1), innerRadius: self.innerRadius, radialBuild: self.radialBuild, terminal: Int32(self.parentTerminal.andersenNumber), numParGroups: Int32(self.numberParallelGroups), currentDirection: Int32(self.currentDirection), cuOrAl: 1, numSpacerBlocks: Int32(self.numSpacerBlocks), spBlkWidth: self.spacerBlockWidth, segments: fld12SegArray)
        
        return newLayer
    }
    
    /// Convenience function to get the OD of a Layer
    func OD() -> Double
    {
        return 2.0 * (self.innerRadius + radialBuild)
    }
    
    func SplitSegment(segmentSerialNumber:Int, numSegments:Int)
    {
        guard let oldSegIndex = self.segArray.firstIndex(where: {$0.serialNumber == segmentSerialNumber}), numSegments > 1 else
        {
            return
        }
        
        let oldSegment = self.segArray.remove(at: oldSegIndex)
        
        var mirrors = oldSegment.mirrorSegments
        mirrors.removeAll(where: {$0 == segmentSerialNumber})
        
        if mirrors.count == 0
        {
            let activeTurns = oldSegment.activeTurns / Double(numSegments)
            let totalTurns = oldSegment.totalTurns / Double(numSegments)
            let zHt = (oldSegment.maxZ - oldSegment.minZ) / Double(numSegments)
            
            var currentZbottom = oldSegment.minZ
            for _ in 0..<numSegments
            {
                let newSegment = Segment(serialNumber: Segment.nextSerialNumber, strandA: oldSegment.strandA, strandR: oldSegment.strandR, strandsPerLayer: oldSegment.strandsPerLayer, strandsPerTurn: oldSegment.strandsPerTurn, activeTurns: activeTurns, totalTurns: totalTurns, minZ: currentZbottom, maxZ: currentZbottom + zHt, mirrorSegments: [], inLayer: self)
                
                self.segments.append(newSegment)
                currentZbottom += zHt
            }
        }
        else if self.parentTerminal.winding!.isDoubleStack && mirrors.count == 1
        {
            let activeTurns = oldSegment.activeTurns / Double(numSegments)
            let totalTurns = oldSegment.totalTurns / Double(numSegments)
            let zHt = (oldSegment.maxZ - oldSegment.minZ) / Double(numSegments)
            
            guard let mirrorIndex = self.segArray.firstIndex(where: {$0.serialNumber == mirrors.first!}) else
            {
                ALog("Could not find mirror index")
                return
            }
            
            let mirrorSegment = self.segArray.remove(at: mirrorIndex)
            
            let lowerSegment = oldSegment.minZ < mirrorSegment.minZ ? oldSegment : mirrorSegment
            let upperSegment = oldSegment.minZ < mirrorSegment.minZ ? mirrorSegment : oldSegment
            
            var lowerBottomZ = lowerSegment.minZ
            var upperTopZ = upperSegment.maxZ
            for _ in 0..<numSegments
            {
                let newLowerSerialNumber = Segment.nextSerialNumber
                let newUpperSerialNumber = Segment.nextSerialNumber
                
                let newLowerSegment = Segment(serialNumber: newLowerSerialNumber, strandA: oldSegment.strandA, strandR: oldSegment.strandR, strandsPerLayer: oldSegment.strandsPerLayer, strandsPerTurn: oldSegment.strandsPerTurn, activeTurns: activeTurns, totalTurns: totalTurns, minZ: lowerBottomZ, maxZ: lowerBottomZ + zHt, mirrorSegments: [newUpperSerialNumber], inLayer: self)
                
                let newUpperSegment = Segment(serialNumber: newUpperSerialNumber, strandA: oldSegment.strandA, strandR: oldSegment.strandR, strandsPerLayer: oldSegment.strandsPerLayer, strandsPerTurn: oldSegment.strandsPerTurn, activeTurns: activeTurns, totalTurns: totalTurns, minZ: upperTopZ - zHt, maxZ: upperTopZ, mirrorSegments: [newLowerSerialNumber], inLayer: self)
                
                self.segments.append(newLowerSegment)
                self.segments.append(newUpperSegment)
                
                lowerBottomZ += zHt
                upperTopZ -= zHt
            }
            
        }
        
        self.segments.sort(by: {$0.minZ < $1.minZ})
    }
}
