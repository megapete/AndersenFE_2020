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
    
    // Test whether this segment contains 'point'
    func contains(point:NSPoint) -> Bool
    {
        guard let segPath = self.path else
        {
            return false
        }
        
        return segPath.contains(point)
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

    // I suppose that I could get fancy and create a TransformerViewDelegate protocol but since the calls are so specific, I'm unable to justify the extra complexity, so I'll just save a weak reference to the AppController here
    weak var appController:AppController? = nil
    
    enum Mode {
        
        case selectWinding
        case zoomRect
    }
    
    var mode:Mode = .selectWinding
    
    var zoomRect:NSRect? = nil
    
    var segments:[SegmentPath] = []
    var boundary:NSRect = NSRect(x: 0, y: 0, width: 0, height: 0)
    let boundaryColor:NSColor = .gray
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSBezierPath.defaultLineWidth *= 2.0
        
        // Drawing code here.
        let boundaryPath = NSBezierPath(rect: boundary)
        self.boundaryColor.set()
        boundaryPath.stroke()
        
        for nextSegment in self.segments
        {
            nextSegment.show()
        }
        
        if self.mode == .zoomRect
        {
            if let rect = self.zoomRect
            {
                print("I got here")
                NSColor.black.set()
                let zoomPath = NSBezierPath(rect: rect)
                zoomPath.stroke()
            }
        }
        
        NSBezierPath.defaultLineWidth /= 2.0
    }
    
    // MARK: Mouse Events
    override func mouseDown(with event: NSEvent) {
        
        if self.mode == .zoomRect
        {
            self.mouseDownWithZoomRect(event: event)
            return
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        
        if self.mode == .zoomRect
        {
            self.mouseDraggedWithZoomRect(event: event)
            return
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        
        self.mode = .selectWinding
        self.needsDisplay = true
    }
    
    func mouseDraggedWithZoomRect(event:NSEvent)
    {
        let endPoint = event.locationInWindow
        self.convert(endPoint, from: nil)
        let newSize = NSSize(width: endPoint.x - self.zoomRect!.origin.x, height: endPoint.y - self.zoomRect!.origin.y)
        self.zoomRect!.size = newSize
        print(self.zoomRect!)
        self.needsDisplay = true
    }
    
    func mouseDownWithZoomRect(event:NSEvent)
    {
        let eventLocation = event.locationInWindow
        self.convert(eventLocation, from: nil)
        
        self.zoomRect = NSRect(origin: eventLocation, size: NSSize())
        self.needsDisplay = true
    }
    
    // MARK: Zoom Functions
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
