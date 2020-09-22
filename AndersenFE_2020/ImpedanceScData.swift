//
//  ImpedanceScData.swift
//  AndersenFE_2020
//
//  Created by Peter Huber on 2020-08-20.
//  Copyright © 2020 Peter Huber. All rights reserved.
//

// Ths is essentially an interface between the FLD library struct PCH_FLD12_OutputData and our program (the main reason for creating this struct is a) for the maybe-one-day change from Andersen to my own FE program; and b) to make it Codable

import Foundation

struct ImpedanceAndScData:Codable {
    
    /// The MVA rating upon which the reactance, resistance, and impedance are based
    let baseMVA:Double
    
    /// The temperature at which the eddy and resistive losses are saved
    let baseTemp:Double
    
    /// Transformer reactance (p.u.)
    let puReactance:Double
    
    /// Transformer resistance (p.u.)
    let puResistance:Double
    
    /// Transformer impedance (p.u.)
    let puImpedance:Double
    
    /// Induction level at the tank (T)
    let BmaxAtTank:Double
    
    /// Induction level at legs (T)
    let BmaxAtLeg:Double
    
    /// Struct to save the various SC data for a segment (this is based on Andersen)
    struct SegmentScData:Codable {
        
        let number:Int
        let ampTurns:Double
        let kVA:Double
        let dcLoss:Double
        let eddyLossAxialFlux:Double
        let eddyLossRadialFlux:Double
        let eddyPUaverage:Double
        let eddyPUmax:Double
        let eddyMaxRect:NSRect
        let scForceTotalRadial:Double
        let scForceTotalAxial:Double
        let scMinRadially:Double
        let scMaxRadially:Double
        let scMaxAccumAxially:Double
        let scAxially:Double
        let scMaxTensionCompression:Double
        let scMinSpacerBars:Double
        let scForceInSpacerBlocks:Double
        let scCombinedForce:Double
    }
    
    var segDataArray:[SegmentScData] = []
    
    struct LayerScData:Codable {
        
        let number:Int
        let dcLoss:Double
        let eddyLossAxialFlux:Double
        let eddyLossRadialFlux:Double
        let eddyPUaverage:Double
        let eddyPUmax:Double
        let eddyMaxRect:NSRect
    }
    
    var layerDataArray:[LayerScData] = []
    
    // Thrust is in Newtons (metric) or Pounds (inch)
    let totalThrustUpper:Double
    let totalThrustLower:Double
    
    init(andersenOutput:PCH_FLD12_OutputData)
    {
        self.baseMVA = andersenOutput.baseMVA
        self.baseTemp = 75.0 // Andersen is always based on 55C rise
        self.puReactance = andersenOutput.transformerPuReactance
        self.puResistance = andersenOutput.transformerPuResistance
        self.puImpedance = andersenOutput.transformerPuImpedance
        self.BmaxAtTank = andersenOutput.bmaxAtTank
        self.BmaxAtLeg = andersenOutput.bmaxAtLeg
        self.totalThrustLower = andersenOutput.totalThrustLower
        self.totalThrustUpper = andersenOutput.totalThrustUpper
        
        guard let andersenSegDataArray:[SegmentData] = ConvertDataArray(dataArray: andersenOutput.segmentData! as! [Data]) else
        {
            DLog("Could not open segment data array")
            return
        }
        
        for nextData in andersenSegDataArray
        {
            
            let newSegScData = SegmentScData(number: Int(nextData.number), ampTurns: nextData.ampTurns, kVA: nextData.kVA, dcLoss: nextData.dcLoss, eddyLossAxialFlux: nextData.eddyLossAxialFlux, eddyLossRadialFlux: nextData.eddyLossRadialFlux, eddyPUaverage: nextData.eddyPUaverage, eddyPUmax: nextData.eddyPUmax, eddyMaxRect: nextData.eddyMaxRect, scForceTotalRadial: nextData.scForceTotalRadial, scForceTotalAxial: nextData.scForceTotalAxial, scMinRadially: nextData.scMinRadially, scMaxRadially: nextData.scMaxRadially, scMaxAccumAxially: nextData.scMaxAccumAxially, scAxially: nextData.scAxially, scMaxTensionCompression: nextData.scMaxTensionCompression, scMinSpacerBars: nextData.scMinSpacerBars, scForceInSpacerBlocks: nextData.scForceInSpacerBlocks, scCombinedForce: nextData.scCombinedForce)
            
            self.segDataArray.append(newSegScData)
        }
        
        guard let andersenLayerDataArray:[LayerData] = ConvertDataArray(dataArray: andersenOutput.layerData! as! [Data]) else
        {
            DLog("Could not open layer data array")
            return
        }
        
        for nextData in andersenLayerDataArray
        {
            let newLayerScData = LayerScData(number: Int(nextData.number), dcLoss: nextData.dcLoss, eddyLossAxialFlux: nextData.eddyLossAxialFlux, eddyLossRadialFlux: nextData.eddyLossRadialFlux, eddyPUaverage: nextData.eddyPUaverage, eddyPUmax: nextData.eddyPUmax, eddyMaxRect: nextData.eddyMaxRect)
            
            self.layerDataArray.append(newLayerScData)
        }
    }
    
    func SegmentData(andersenSegNum:Int) -> ImpedanceAndScData.SegmentScData?
    {
        for nextSegmentData in self.segDataArray
        {
            if nextSegmentData.number == andersenSegNum
            {
                return nextSegmentData
            }
        }
        
        return nil
    }
}
