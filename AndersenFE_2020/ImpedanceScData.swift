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
    
    /// Data needed to draw fluxlines correctly
    let zMin:Double
    let coreRadius:Double
    
    /// The impedance (in pu) used to calculate sc forces
    let puForceImpedance:Double
    
    /// The system impedance used in the force calculations
    let puSystemImpedance:Double
    
    /// The peak factor used in the force calculations (without the √2)
    let pkFactor:Double
    
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
    
    let fluxLineString:String
    /// This routine returns an array of an array of NSPoints. The first array has a single NSPoint in it, representing the maximum dimensions required for the flux lines. Afger that, each array represents the points on the flux line. NOTE: The fluxline x-dimensions are from the core leg (not the center of the core).
    var fluxLines:[[NSPoint]] {
        get {
            
            // The logic for this comes from my old AndersenFE program. Where I got THAT from is anyone's guess. The Andersen-supplied BASIC program PLOTSCR.BAS seems to be the source for the variable names, but I don't know how I figured out the file format. I have simplified it somewhat based on what I'm seeing in the actual BAS.FIL file.
            var result:[[NSPoint]] = []
            
            let fluxFileComponents = self.fluxLineString.components(separatedBy: .newlines)
            
            // skip past the first couple of lines of the file
            var currentComponentIndex = 3
            var currentComponent = fluxFileComponents[currentComponentIndex]
            
            // get the maximum X & Y values
            var currentLine = currentComponent.components(separatedBy: .whitespaces)
            currentLine.removeAll(where: {$0 == ""})
            let maxDims:NSPoint = NSPoint(x: Double(currentLine[2])!, y: Double(currentLine[3])!)
            result.append([maxDims])
            
            // advance to the next line
            currentComponentIndex += 1
            currentComponent = fluxFileComponents[currentComponentIndex]
            currentLine = currentComponent.components(separatedBy: .whitespaces)
            currentLine.removeAll(where: {$0 == ""})
            
            var IPNTS:Int = Int(currentLine[0])!
            var ICOL:Int = Int(currentLine[1])!
            
            while (ICOL != 0)
            {
                currentComponentIndex += 1
                
                if ICOL == 4
                {
                    currentComponent = fluxFileComponents[currentComponentIndex]
                    currentLine = currentComponent.components(separatedBy: .whitespaces)
                    currentLine.removeAll(where: {$0 == ""})
                    
                    // At some point (I think when IPNTS reached 250), the dimensions are split onto multiple lines.
                    while currentLine.count < IPNTS * 2
                    {
                        currentComponentIndex += 1
                        currentComponent = fluxFileComponents[currentComponentIndex]
                        var currentLine2 = currentComponent.components(separatedBy: .whitespaces)
                        currentLine2.removeAll(where: {$0 == ""})
                        
                        currentLine += currentLine2
                    }
                    
                    var dimArray:[NSPoint] = []
                    for i in 0..<IPNTS
                    {
                        let nextPoint = NSPoint(x: Double(currentLine[i])! + self.coreRadius, y: Double(currentLine[i + IPNTS])! + self.zMin)
                        dimArray.append(nextPoint)
                    }
                    
                    result.append(dimArray)
                }
                
                // advance to the next line
                currentComponentIndex += 1
                currentComponent = fluxFileComponents[currentComponentIndex]
                currentLine = currentComponent.components(separatedBy: .whitespaces)
                currentLine.removeAll(where: {$0 == ""})
                
                IPNTS = Int(currentLine[0])!
                ICOL = Int(currentLine[1])!
            }
            
            // DLog("Done")
            return result
        }
    }
    
    let fld8File:String
    
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
        self.puForceImpedance = andersenOutput.scForcePuImpedance
        self.puSystemImpedance = andersenOutput.systemPuImpedance
        
        if let inputData = andersenOutput.inputData
        {
            self.zMin = inputData.lowerZ
            self.coreRadius = inputData.coreDiameter / 2.0
            self.pkFactor = inputData.peakFactor
        }
        else
        {
            self.zMin = 0.0
            self.coreRadius = 0.0
            self.pkFactor = 1.8
        }
        
        if let fluxLines = andersenOutput.fluxLineData
        {
            self.fluxLineString = fluxLines
        }
        else
        {
            self.fluxLineString = ""
        }
        
        if let fld8File = andersenOutput.fld8FileString
        {
            self.fld8File = fld8File
        }
        else
        {
            self.fld8File = ""
        }
        
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
    
    func LayerData(andersenLayerNum:Int) -> ImpedanceAndScData.LayerScData?
    {
        for nextLayerData in self.layerDataArray
        {
            if nextLayerData.number == andersenLayerNum
            {
                return nextLayerData
            }
        }
        
        return nil
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
