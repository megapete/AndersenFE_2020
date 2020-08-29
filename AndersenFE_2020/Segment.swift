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
    
    /// Function to split this segment into a given number of "subsegments". It is the calling routines responsibility to delete this segment and insert the array of new segments into the the correct place. Note that when creating the new segments, this function sets the active turns to be equal to the total turns - ie: turning off turns is also the calling routines responsibilty
    ///  - Parameter numSegs: The number of segments to split this one into
    ///  - Parameter gap: The axial dimension of the gaps between the new segments
    ///  - Returns: An array of Segments
    func SplitSegment(numSegs:Int, gap:Double = 0.0) -> [Segment]
    {
        var result:[Segment] = []
        
        let zPerSegment:Double = ((self.maxZ - self.minZ) - (Double(numSegs - 1)) * gap) / Double(numSegs);
        
        let turnsPerSegment = self.totalTurns / Double(numSegs)
        
        var currentZ = self.minZ
        
        while result.count < numSegs
        {
            let newSegment = Segment(serialNumber: Segment.nextSerialNumber, strandA: self.strandA, strandR: self.strandR, strandsPerLayer: self.strandsPerLayer, strandsPerTurn: self.strandsPerTurn, activeTurns: turnsPerSegment, totalTurns: turnsPerSegment, minZ: currentZ, maxZ: currentZ + zPerSegment)
            
            result.append(newSegment)
            
            currentZ = newSegment.maxZ + gap
        }
        
        return result
    }
    
    /// Function to split this segment into two segments, the bottom-most of which has the height and number of turns equal to the percentageNewBottom parameter. The new top segment will have the balance of the height and the turms. Note that all of the turns of the new segments are set as active, regardless of the state of the turs in the current segment.
    ///  - Parameter percentNewBottom: The percentage of height and turns that the new bottom segment will have
    ///  - Returns: An array of two Segments
    func SplitSegment(percentNewBottom:Double) -> [Segment]
    {        
        if percentNewBottom <= 0.0 || percentNewBottom >= 100.0
        {
            DLog("Percentage outside of allowed range - returnimng array of this segment")
            return [self]
        }
        
        let bottomTurns = self.totalTurns * percentNewBottom / 100.0
        let topTurns = self.totalTurns - bottomTurns
        
        let selfDeltaZ = self.maxZ - self.minZ
        let bottomDeltaZ = selfDeltaZ * percentNewBottom / 100.0
        let topDeltaZ = selfDeltaZ - bottomDeltaZ
        
        let bottomSegment = Segment(serialNumber: Segment.nextSerialNumber, strandA: self.strandA, strandR: self.strandR, strandsPerLayer: self.strandsPerLayer, strandsPerTurn: self.strandsPerTurn, activeTurns: bottomTurns, totalTurns: bottomTurns, minZ: self.minZ, maxZ: self.minZ + bottomDeltaZ)
        
        let topSegment = Segment(serialNumber: Segment.nextSerialNumber, strandA: self.strandA, strandR: self.strandR, strandsPerLayer: self.strandsPerLayer, strandsPerTurn: self.strandsPerTurn, activeTurns: topTurns, totalTurns: topTurns, minZ: bottomSegment.maxZ, maxZ: bottomSegment.maxZ + topDeltaZ)
        
        return [bottomSegment, topSegment]
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
