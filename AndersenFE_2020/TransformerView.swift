//
//  TransformerView.swift
//  AndersenFE_2020
//
//  Created by Peter Huber on 2020-07-29.
//  Copyright © 2020 Peter Huber. All rights reserved.
//

import Cocoa

struct SegmentPath {
    
    let segment:Segment
    
    var path:NSBezierPath? {
        get {
            
            guard let parentLayer = segment.inLayer else
            {
                return nil
            }
            
            return NSBezierPath(rect: NSRect(x: parentLayer.innerRadius, y: self.segment.minZ, width: parentLayer.radialBuild, height: self.segment.height))
        }
    }
        
    let segmentColor:NSColor
    static var bkGroundColor:NSColor = .white
    
    var isActive:Bool {
        get {
            return self.segment.IsActive()
        }
    }
    
    // constant for showing that a segment is not active
    let nonActiveAlpha:CGFloat = 0.25
    
    func show()
    {
        if isActive
        {
            self.clear()
        }
        else
        {
            self.fill(alpha: nonActiveAlpha)
        }
    }
    
    // Some functions that make it so we can use SegmentPaths in a similar way as NSBezierPaths
    func stroke()
    {
        guard let path = self.path else
        {
            return
        }
        
        if self.isActive
        {
            self.segmentColor.set()
            path.stroke()
        }
    }
    
    func fill(alpha:CGFloat)
    {
        guard let path = self.path else
        {
            return
        }
        
        self.segmentColor.withAlphaComponent(alpha).set()
        path.fill()
        self.segmentColor.set()
        path.stroke()
    }
    
    // fill the path with the background color
    func clear()
    {
        guard let path = self.path else
        {
            return
        }
        
        SegmentPath.bkGroundColor.set()
        path.fill()
        self.segmentColor.set()
        path.stroke()
    }
}

class TransformerView: NSView {

    // I suppose that I could get fancy and create a TransformerViewDelegate protocol but since the calls are so specific, I'm unable to justify the extra complexity
    var appController:AppController? = nil
    
    var segments:[SegmentPath] = []
    var boundary:NSRect = NSRect(x: 0, y: 0, width: 0, height: 0)
    let boundaryColor:NSColor = .gray
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
        let boundaryPath = NSBezierPath(rect: boundary)
        self.boundaryColor.set()
        boundaryPath.stroke()
        
        for nextSegment in self.segments
        {
            nextSegment.show()
        }
        
    }
    
    // transformer display zoom functions
    func zoomAll(coreRadius:CGFloat, windowHt:CGFloat, tankWallR:CGFloat)
    {
        // aspectRatio is defined as width/height
        // it is assumed that the window height (z) is ALWAYS the dominant dimension compared to the "half tank-width" in the r-direction
        let aspectRatio = self.frame.width / self.frame.height
        let boundsW = windowHt * aspectRatio
        
        self.bounds = NSRect(x: coreRadius, y: 0.0, width: boundsW, height: windowHt)
        
        self.boundary = self.bounds
        self.boundary.size.width = tankWallR - coreRadius
        
        self.needsDisplay = true
    }
    
    // Mouse events
    override func mouseDown(with event: NSEvent) {
        
        
    }
    
    // the zoom in/out ratio (maybe consider making this user-settable)
    let zoomRatio:CGFloat = 0.75
    func zoomOut()
    {
        self.scaleUnitSquare(to: (NSSize(width: zoomRatio, height: zoomRatio)))
        self.needsDisplay = true
    }
    
    func zoomIn()
    {
        self.scaleUnitSquare(to: NSSize(width: 1.0 / zoomRatio, height: 1.0 / zoomRatio))
        self.needsDisplay = true
    }
    
    func zoomRect(zRect:NSRect)
    {
        self.bounds = zRect
        self.needsDisplay = true
    }
    
}
