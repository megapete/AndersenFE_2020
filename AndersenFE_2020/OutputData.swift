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
        
        private let dcLoss75:Double
        private let averageEddyPU75:Double
        private let maximumEddyPU75:Double
        let maxEddyLossRect:NSRect
        
        // Andersen calculates losses at 75C
        static let refTemp = 75.0
        
        func dcLoss(temp:Double) -> Double
        {
            return self.dcLoss75 * (234.5 + temp) / (234.5 + LayerData.refTemp)
        }
        
        func aveEddyLoss(temp:Double) -> Double
        {
            let refEddyLoss = self.dcLoss75 * self.averageEddyPU75
            
            return refEddyLoss * (234.5 + LayerData.refTemp) / (234.5 + temp)
        }
        
        func maxEddyLoss(temp:Double) -> Double
        {
            let refEddyLoss = self.dcLoss75 * self.maximumEddyPU75
            
            return refEddyLoss * (234.5 + LayerData.refTemp) / (234.5 + temp)
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
    
    init?(txfo:Transformer, outputDesc:String)
    {
        guard let results = txfo.scResults else
        {
            return nil
        }
        
        self.description = outputDesc
        self.MVA = results.baseMVA
        self.impedance = results.puImpedance
        
        var termData:[TermData] = []
        let availableTermNums = txfo.AvailableTerminals()
        for nextTermNum in availableTermNums
        {
            let tryMVA = try? txfo.TotalVA(terminal: nextTermNum)
            let tryV = try? txfo.TerminalLineVoltage(terminal: nextTermNum)
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
                
            }
        }
        
        self.layers = []
    }
}
