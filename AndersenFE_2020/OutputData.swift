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
    
    struct TermData
    {
        let termNum:Int
        let termMVA:Double
        let termKV:Double
    }
    
    let terminals:[TermData]
    
    struct LayerData
    {
        let windingID:String
        
        let parentTerminal:Int
        
        let currentDirection:Int
        
        let ID:Double
        let OD:Double
        
        let minimumSpacerBars:Double
        
        let maxRadialForce:Double
        
        let maxSpacerBlockForce:Double
        
        let maxCombinedForce:Double
        
        let dcLoss:Double
        let averageEddyLoss:Double
        let maximumEddyLoss:Double
        
    }
    
    let layers:[LayerData]
    
    init?(txfo:Transformer, outputDesc:String)
    {
        guard let results = txfo.scResults else
        {
            return nil
        }
        
        self.description = outputDesc
        self.MVA = 0.0
        self.terminals = []
        self.layers = []
    }
}
