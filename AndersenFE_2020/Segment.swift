//
//  Segment.swift
//  AndersenFE_2020
//
//  Created by Peter Huber on 2020-07-17.
//  Copyright © 2020 Peter Huber. All rights reserved.
//

import Foundation

struct Segment {
    
    enum TapType {
        
        case nonTap
        case posTap
        case negTap
    }
    
    let type:TapType
    
    // let num:Int
    
    let strandA:Double
    let strandR:Double
    
    let strandsPerLayer:Int
    let strandsPerTurn:Int
    
    let activeTurns:Double
    let totalTurns:Double
    
    let minZ:Double
    let maxZ:Double
    
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
            let newSegment = Segment(type: self.type, strandA: self.strandA, strandR: self.strandR, strandsPerLayer: self.strandsPerLayer, strandsPerTurn: self.strandsPerTurn, activeTurns: turnsPerSegment, totalTurns: turnsPerSegment, minZ: currentZ, maxZ: currentZ + zPerSegment)
            
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
        
        let bottomSegment = Segment(type: self.type, strandA: self.strandA, strandR: self.strandR, strandsPerLayer: self.strandsPerLayer, strandsPerTurn: self.strandsPerTurn, activeTurns: bottomTurns, totalTurns: bottomTurns, minZ: self.minZ, maxZ: self.minZ + bottomDeltaZ)
        
        let topSegment = Segment(type: self.type, strandA: self.strandA, strandR: self.strandR, strandsPerLayer: self.strandsPerLayer, strandsPerTurn: self.strandsPerTurn, activeTurns: topTurns, totalTurns: topTurns, minZ: bottomSegment.maxZ, maxZ: bottomSegment.maxZ + topDeltaZ)
        
        return [bottomSegment, topSegment]
    }
    
    /// Convenience routine to see if the turns of this segment are currently active
    func IsActive() -> Bool
    {
        return activeTurns != 0
    }
    
    
}
