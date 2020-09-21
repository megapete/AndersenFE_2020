//
//  Segment.swift
//  AndersenFE_2020
//
//  Created by Peter Huber on 2020-07-17.
//  Copyright © 2020 Peter Huber. All rights reserved.
//



import Foundation

/// A Segment is a collection of turns (made up of a number of strands per turn and strands per layer) with a lower dimension of minZ and an upper dimension of maxZ
class Segment:Codable, Equatable {
    
    static func == (lhs: Segment, rhs: Segment) -> Bool {
        
        return lhs.serialNumber == rhs.serialNumber
    }
    
    private static var nextSerialNumberStore:Int = 0
    
    static var nextSerialNumber:Int {
        get {
            
            let nextNum = Segment.nextSerialNumberStore
            Segment.nextSerialNumberStore += 1
            return nextNum
        }
    }
    
    /// Segment serial number (needed for the mirrorSegment property and to make the "==" operator code simpler
    let serialNumber:Int
    
    /// Strand Axial Dimension
    let strandA:Double
    /// Strand Radial Dimension
    let strandR:Double
    
    /// Number of strands across the Layer that this Segment belongs to
    let strandsPerLayer:Int
    /// The number of strands that make up a turn
    let strandsPerTurn:Int
    
    /// The number of active turns in the Segment (usually either 0 or totalTurns)
    var activeTurns:Double
    /// The total number of turns in the Segment
    let totalTurns:Double
    
    /// The lower dimension of the Segment
    let minZ:Double
    /// The upper dimesion of the Segment
    let maxZ:Double
    
    /// The associated segment(s) of either a double-axial stack winding or a multi-start winding. Self is always a member of this array.
    var mirrorSegments:[Int] = []
    
    var inLayer:Layer? = nil
    
    /// The FLD12 segment number of this segment from the last time FLD12Section() was called. A negative number means that Andersen has not yet been called
    var andersenSegNum = -1
    
    init(serialNumber:Int, strandA:Double, strandR:Double, strandsPerLayer:Int, strandsPerTurn:Int, activeTurns:Double, totalTurns:Double, minZ:Double, maxZ:Double, mirrorSegments:[Int] = [], inLayer:Layer? = nil) {
        
        self.serialNumber = serialNumber
        self.strandA = strandA
        self.strandR = strandR
        self.strandsPerLayer = strandsPerLayer
        self.strandsPerTurn = strandsPerTurn
        self.activeTurns = activeTurns
        self.totalTurns = totalTurns
        self.minZ = minZ
        self.maxZ = maxZ
        
        // make sure that this Segment's serial number is added to the mirrorSegment array
        var mirrorSet:Set<Int> = Set(mirrorSegments)
        mirrorSet.insert(serialNumber)
        self.mirrorSegments = Array(mirrorSet)
        
        self.inLayer = inLayer
    }
    
    /// Function to create a PCH_FLD12_Segment from this Segment
    func FLD12section(segNum:Int) -> PCH_FLD12_Segment
    {
        self.andersenSegNum = segNum
        
        let fld12Seg = PCH_FLD12_Segment(number: Int32(segNum), zMin: self.minZ, zMax: self.maxZ, turns: self.totalTurns, activeTurns: self.activeTurns, strandsPerTurn: Int32(self.strandsPerTurn), strandsPerLayer: Int32(self.strandsPerLayer), strandR: self.strandR, strandA: self.strandA)
        
        return fld12Seg
    }
    
    /// Convenience property for the height of the segment
    var height:Double {
        get {
            return self.maxZ - self.minZ
        }
    }
    
    /// Convenience routine to see if the turns of this segment are currently active
    func IsActive() -> Bool
    {
        return activeTurns != 0
    }
    
    func ToggleActivate()
    {
        guard let layer = self.inLayer else
        {
            return
        }
        
        let newTurns = (self.activeTurns == 0.0 ? self.totalTurns : 0.0)
        
        for nextSegment in layer.segments
        {
            if self.mirrorSegments.contains(nextSegment.serialNumber)
            {
                nextSegment.activeTurns = newTurns
                // DLog("Segment: \(nextSegment.serialNumber) is now \(nextSegment.IsActive() ? "ON" : "OFF")")
            }
        }
    }
    
}
