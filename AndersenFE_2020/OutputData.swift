//
//  OutputData.swift
//  AndersenFE_2020
//
//  Created by Peter Huber on 2020-09-21.
//  Copyright © 2020 Peter Huber. All rights reserved.
//

import Foundation

struct OutputData {
    
    let description:String
    
    let MVA:Double
    
    let impedance:Double
    
    var z0:Double? = nil
    
    let impedanceForForces:Double
    let pkFactor:Double
    
    let lowerThrust:Double
    let upperThrust:Double
    
    struct TermData
    {
        let termNum:Int
        let termMVA:Double
        let termKV:Double
    }
    
    let terminals:[TermData]
    
    struct LayerData
    {
        let windingDesc:String
        
        let parentTerminal:Int
        
        let currentDirection:Int
        
        let ID:Double
        let OD:Double
        
        let minimumSpacerBars:Double
        
        let maxRadialForce:Double
        
        let maxSpacerBlockForce:Double
        
        let maxCombinedForce:Double
        
        fileprivate let dcLoss75:Double
        fileprivate let averageEddyPU75:Double
        fileprivate let maximumEddyPU75:Double
        let maxEddyLossRect:NSRect
        
        // Andersen calculates losses at 75C
        static let refTemp = 75.0
        
        func dcLoss(temp:Double) -> Double
        {
            return self.dcLoss75 * (234.5 + temp) / (234.5 + LayerData.refTemp) * 1000.0
        }
        
        func aveEddyLoss(temp:Double) -> Double
        {
            let refEddyLoss = self.dcLoss75 * self.averageEddyPU75
            
            return 1000.0 * refEddyLoss * (234.5 + LayerData.refTemp) / (234.5 + temp)
        }
        
        func maxEddyLoss(temp:Double) -> Double
        {
            let refEddyLoss = self.dcLoss75 * self.maximumEddyPU75
            
            return 1000.0 * refEddyLoss * (234.5 + LayerData.refTemp) / (234.5 + temp)
        }
        
        func aveEddyPU(temp:Double) -> Double
        {
            return self.aveEddyLoss(temp: temp) / self.dcLoss(temp: temp)
        }
        
        func maxEddyPU(temp:Double) -> Double
        {
            return self.maxEddyLoss(temp: temp) / self.dcLoss(temp: temp)
        }
        
    }
    
    let layers:[LayerData]
    
    let warnings:[String]
    
    init?(txfo:Transformer, outputDesc:String)
    {
        guard let results = txfo.scResults else
        {
            return nil
        }
        
        self.description = outputDesc
        self.MVA = results.baseMVA
        self.impedance = results.puImpedance
        self.z0 = txfo.zeroSequenceImpedance
        self.impedanceForForces = results.puForceImpedance
        self.pkFactor = results.pkFactor
        
        var termData:[TermData] = []
        let availableTermNums = txfo.AvailableTerminals()
        for nextTermNum in availableTermNums
        {
            let tryMVA = try? txfo.TotalVA(terminal: nextTermNum) / 1.0E6
            let tryV = try? txfo.TerminalLineVoltage(terminal: nextTermNum) / 1.0E3
            if tryMVA == nil || tryV == nil
            {
                return nil
            }
            
            let nextTermData = TermData(termNum: nextTermNum, termMVA: tryMVA!, termKV: tryV!)
            termData.append(nextTermData)
        }
        self.terminals = termData.sorted(by: {$0.termNum < $1.termNum})
        
        var layerData:[LayerData] = []
        for nextWdg in txfo.windings
        {
            for nextLayer in nextWdg.layers
            {
                let parent = nextLayer.parentTerminal
                let windingDesc = parent.name
                let parentTerm = parent.andersenNumber
                let currenTdir = parent.currentDirection
                let ID = nextLayer.innerRadius * 2.0
                let OD = nextLayer.OD()
                
                guard let nextLayerScData = results.LayerData(andersenLayerNum: nextLayer.andersenLayerNum) else
                {
                    DLog("Could not find layer short-circuit data for layer #\(nextLayer.andersenLayerNum)")
                    return nil
                }
                
                var minSpacerBars = 0.0
                var maxRadialForce = 0.0
                var maxBlockForce = 0.0
                var maxCombForce = 0.0
                
                for nextSegment in nextLayer.segments
                {
                    guard let segmentScData = results.SegmentData(andersenSegNum: nextSegment.andersenSegNum) else
                    {
                        DLog("Could not find layer short-circuit data for segment #\(nextLayer.andersenLayerNum)")
                        return nil
                    }
                    
                    if segmentScData.scMinSpacerBars > minSpacerBars
                    {
                        minSpacerBars = segmentScData.scMinSpacerBars
                    }
                    
                    if fabs(segmentScData.scMaxTensionCompression) > fabs(maxRadialForce)
                    {
                        maxRadialForce = segmentScData.scMaxTensionCompression
                    }
                    
                    if segmentScData.scForceInSpacerBlocks > maxBlockForce
                    {
                        maxBlockForce = segmentScData.scForceInSpacerBlocks
                    }
                    
                    if segmentScData.scCombinedForce > maxCombForce
                    {
                        maxCombForce = segmentScData.scCombinedForce
                    }
                }
                
                let newLayerData = LayerData(windingDesc: windingDesc, parentTerminal: parentTerm, currentDirection: currenTdir, ID: ID, OD: OD, minimumSpacerBars: minSpacerBars, maxRadialForce: maxRadialForce, maxSpacerBlockForce: maxBlockForce, maxCombinedForce: maxCombForce, dcLoss75: nextLayerScData.dcLoss, averageEddyPU75: nextLayerScData.eddyPUaverage, maximumEddyPU75: nextLayerScData.eddyPUmax, maxEddyLossRect: nextLayerScData.eddyMaxRect)
                
                layerData.append(newLayerData)
            }
        }
        
        self.layers = layerData.sorted(by: {$0.ID < $1.ID})
        
        self.lowerThrust = results.totalThrustLower
        self.upperThrust = results.totalThrustUpper
        
        let scWarnings = txfo.CheckForWarnings()
        var warningStrings:[String] = []
        for nextWarning in scWarnings
        {
            warningStrings.append(nextWarning.string)
        }
        
        self.warnings = warningStrings
    }
    
    func AvailableTerms() -> [Int]
    {
        var result:[Int] = []
        
        for nextTerm in self.terminals
        {
            result.append(nextTerm.termNum)
        }
        
        result.sort()
        
        return result
    }
    
    func DataForTerm(number:Int) -> (mva:Double, kv:Double)?
    {
        for nextTerm in self.terminals
        {
            if nextTerm.termNum == number
            {
                return (nextTerm.termMVA, nextTerm.termKV)
            }
        }
        
        return nil
    }
}
