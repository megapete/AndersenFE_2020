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
    var currentDirection:Int32 {
        get {
            
            if self.parentTerminal.currentDirection == 0
            {
                return 1
            }
            
            let andCurrDir = self.parentTerminal.nominalAmps * Double(self.parentTerminal.currentDirection)
            
            return andCurrDir < 0 ? -1 : 1
        }
    }
    
    /// The number of parallel axial groups in the Layer (either 1 or 2)
    let numberParallelGroups:Int
    
    /// The radial build of the Layer
    let radialBuild:Double
    
    /// The inner radius of the Layer
    var innerRadius:Double
    
    /// The lowest z-dim of the lowest segment in this layer
    var minZ:Double {
        
        get {
            
            var minZ = Double.greatestFiniteMagnitude
            
            for nextSegment in self.segments
            {
                if nextSegment.minZ < minZ
                {
                    minZ = nextSegment.minZ
                }
            }
            
            return minZ
        }
    }
    
    /// The highest z-dim of the highest segment in this layer
    var maxZ:Double {
        
        get {
            
            var maxZ = -Double.greatestFiniteMagnitude
            
            for nextSegment in self.segments
            {
                if nextSegment.maxZ > maxZ
                {
                    maxZ = nextSegment.maxZ
                }
            }
            
            return maxZ
        }
    }
    
    /// The Terminal to which this Layer belongs
    let parentTerminal:Terminal
    
    /// Andersen Layer Number
    var andersenLayerNum = -1
    
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
        self.andersenLayerNum = layernum
        
        var nextSegNum = firstSegNum
        var fld12SegArray:[PCH_FLD12_Segment] = []
        
        for nextSeg in self.segments
        {
            fld12SegArray.append(nextSeg.FLD12section(segNum: nextSegNum))
            nextSegNum += 1
        }
        
        
        
        let newLayer = PCH_FLD12_Layer(number: Int32(layernum), lastSegment: Int32(nextSegNum - 1), innerRadius: self.innerRadius, radialBuild: self.radialBuild, terminal: Int32(self.parentTerminal.andersenNumber), numParGroups: Int32(self.numberParallelGroups), currentDirection: self.currentDirection, cuOrAl: 1, numSpacerBlocks: Int32(self.numSpacerBlocks), spBlkWidth: self.spacerBlockWidth, segments: fld12SegArray)
        
        return newLayer
    }
    
    /// Convenience function to get the OD of a Layer
    func OD() -> Double
    {
        return 2.0 * (self.innerRadius + radialBuild)
    }
    
    func SplitSegment(segmentSerialNumber:Int, puForLowerSegment:Double)
    {
        guard let oldSegIndex = self.segArray.firstIndex(where: {$0.serialNumber == segmentSerialNumber}), puForLowerSegment >= 0.01, puForLowerSegment <= 99.0 else
        {
            return
        }
        
        let oldSegment = self.segArray.remove(at: oldSegIndex)
        
        var mirrors = oldSegment.mirrorSegments
        mirrors.removeAll(where: {$0 == segmentSerialNumber})
        
        if mirrors.count == 0
        {
            let loActiveTurns = puForLowerSegment * oldSegment.activeTurns
            let hiActiveTurns = oldSegment.activeTurns - loActiveTurns
            let loTotalTurns = puForLowerSegment * oldSegment.totalTurns
            let hiTotalTurns = oldSegment.totalTurns - loTotalTurns
            let splitZ = puForLowerSegment * oldSegment.height + oldSegment.minZ
            
            let newLoSegment = Segment(serialNumber: Segment.nextSerialNumber, strandA: oldSegment.strandA, strandR: oldSegment.strandR, strandsPerLayer: oldSegment.strandsPerLayer, strandsPerTurn: oldSegment.strandsPerTurn, activeTurns: loActiveTurns, totalTurns: loTotalTurns, minZ: oldSegment.minZ, maxZ: splitZ, mirrorSegments: [], inLayer: self)
            
            let newHiSegment = Segment(serialNumber: Segment.nextSerialNumber, strandA: oldSegment.strandA, strandR: oldSegment.strandR, strandsPerLayer: oldSegment.strandsPerLayer, strandsPerTurn: oldSegment.strandsPerTurn, activeTurns: hiActiveTurns, totalTurns: hiTotalTurns, minZ: splitZ, maxZ: oldSegment.maxZ, mirrorSegments: [], inLayer: self)
            
            self.segArray.append(newLoSegment)
            self.segArray.append(newHiSegment)
        }
        else if self.parentTerminal.winding!.isDoubleStack && mirrors.count == 1
        {
            let loActiveTurns = puForLowerSegment * oldSegment.activeTurns
            let hiActiveTurns = oldSegment.activeTurns - loActiveTurns
            let loTotalTurns = puForLowerSegment * oldSegment.totalTurns
            let hiTotalTurns = oldSegment.totalTurns - loTotalTurns
            var splitZ = puForLowerSegment * oldSegment.height + oldSegment.minZ
            
            let loLowerSerialNumber = Segment.nextSerialNumber
            let hiLowerSerialNumber = Segment.nextSerialNumber
            let loUpperSerialNumber = Segment.nextSerialNumber
            let hiUpperSerialNumber = Segment.nextSerialNumber
            
            let newLoLowerSegment = Segment(serialNumber: loLowerSerialNumber, strandA: oldSegment.strandA, strandR: oldSegment.strandR, strandsPerLayer: oldSegment.strandsPerLayer, strandsPerTurn: oldSegment.strandsPerTurn, activeTurns: loActiveTurns, totalTurns: loTotalTurns, minZ: oldSegment.minZ, maxZ: splitZ, mirrorSegments: [hiUpperSerialNumber], inLayer: self)
            
            let newHiLowerSegment = Segment(serialNumber: hiLowerSerialNumber, strandA: oldSegment.strandA, strandR: oldSegment.strandR, strandsPerLayer: oldSegment.strandsPerLayer, strandsPerTurn: oldSegment.strandsPerTurn, activeTurns: hiActiveTurns, totalTurns: hiTotalTurns, minZ: splitZ, maxZ: oldSegment.maxZ, mirrorSegments: [loUpperSerialNumber], inLayer: self)
            
            guard let mirrorIndex = self.segArray.firstIndex(where: {$0.serialNumber == mirrors.first!}) else
            {
                ALog("Could not find mirror index")
                self.segArray.append(oldSegment)
                self.segments.sort(by: {$0.minZ < $1.minZ})
                return
            }
            
            let mirrorSegment = self.segArray.remove(at: mirrorIndex)
            
            splitZ = (1.0 - puForLowerSegment) * mirrorSegment.height + mirrorSegment.minZ
            
            let newLoUpperSegment = Segment(serialNumber: loUpperSerialNumber, strandA: oldSegment.strandA, strandR: oldSegment.strandR, strandsPerLayer: oldSegment.strandsPerLayer, strandsPerTurn: oldSegment.strandsPerTurn, activeTurns: hiActiveTurns, totalTurns: hiTotalTurns, minZ: mirrorSegment.minZ, maxZ: splitZ, mirrorSegments: [hiLowerSerialNumber], inLayer: self)
            
            let newHiUpperSegment = Segment(serialNumber: hiUpperSerialNumber, strandA: oldSegment.strandA, strandR: oldSegment.strandR, strandsPerLayer: oldSegment.strandsPerLayer, strandsPerTurn: oldSegment.strandsPerTurn, activeTurns: loActiveTurns, totalTurns: loTotalTurns, minZ: splitZ, maxZ: mirrorSegment.maxZ, mirrorSegments: [loLowerSerialNumber], inLayer: self)
            
            self.segArray.append(contentsOf: [newLoLowerSegment, newHiLowerSegment, newLoUpperSegment, newHiUpperSegment])
        }
        else
        {
            ALog("Cannot split multi-start winding segments")
            self.segArray.append(oldSegment)
        }
        
        self.segments.sort(by: {$0.minZ < $1.minZ})
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
                self.segArray.append(oldSegment)
                self.segments.sort(by: {$0.minZ < $1.minZ})
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
        else
        {
            ALog("Cannot split multi-start winding segments")
            self.segArray.append(oldSegment)
        }
        
        self.segments.sort(by: {$0.minZ < $1.minZ})
    }
}
