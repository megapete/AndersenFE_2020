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
    
    var toolTipTag:NSView.ToolTipTag = 0
    
    var path:NSBezierPath? {
        get {
            
            guard let parentLayer = segment.inLayer else
            {
                return nil
            }
            
            return NSBezierPath(rect: NSRect(x: parentLayer.innerRadius, y: self.segment.minZ, width: parentLayer.radialBuild, height: self.segment.height))
        }
    }
    
    var rect:NSRect {
        
        var result = NSRect()
        
        if let parentLayer = segment.inLayer
        {
            result = NSRect(x: parentLayer.innerRadius, y: self.segment.minZ, width: parentLayer.radialBuild, height: self.segment.height)
        }
        
        return result
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

class TransformerView: NSView, NSViewToolTipOwner {

    // I suppose that I could get fancy and create a TransformerViewDelegate protocol but since the calls are so specific, I'm unable to justify the extra complexity, so I'll just save a weak reference to the AppController here
    weak var appController:AppController? = nil
    
    enum Mode {
        
        case selectSegment
        case zoomRect
    }
    
    private var modeStore:Mode = .selectSegment
    
    var mode:Mode {
        
        get {
            
            return self.modeStore
        }
        
        set {
            
            if newValue == .selectSegment
            {
                NSCursor.arrow.set()
            }
            else if newValue == .zoomRect
            {
                NSCursor.crosshair.set()
            }
            
            self.modeStore = newValue
        }
    }
    
    var segments:[SegmentPath] = []
    var boundary:NSRect = NSRect(x: 0, y: 0, width: 0, height: 0)
    let boundaryColor:NSColor = .gray
    
    var zoomRect:NSRect? = nil
    let zoomRectLineDash:[CGFloat] = [15.0, 8.0]
    
    var currentSegment:SegmentPath? = nil
    
    // MARK: Draw function override
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let oldLineWidth = NSBezierPath.defaultLineWidth
        
        // This is my "simple" way to get a one-pixel (ish) line thickness
        NSBezierPath.defaultLineWidth = self.bounds.width / self.frame.width
        
        // Drawing code here.
        let boundaryPath = NSBezierPath(rect: boundary)
        self.boundaryColor.set()
        boundaryPath.stroke()
        
        for nextSegment in self.segments
        {
            nextSegment.show()
        }
        
        if let currSeg = self.currentSegment
        {
            self.ShowHandles(segment: currSeg)
        }
        
        if self.mode == .zoomRect
        {
            if let rect = self.zoomRect
            {
                // print(rect)
                NSColor.gray.set()
                let zoomPath = NSBezierPath(rect: rect)
                zoomPath.setLineDash(self.zoomRectLineDash, count: 2, phase: 0.0)
                zoomPath.stroke()
            }
        }
        
        NSBezierPath.defaultLineWidth = oldLineWidth
    }
    
    override var acceptsFirstResponder: Bool
    {
        return true
    }
    
    // MARK: Current segment functions
    
    func ShowHandles(segment:SegmentPath)
    {
        let handleSide = NSBezierPath.defaultLineWidth * 5.0
        let handleBaseRect = NSRect(x: 0.0, y: 0.0, width: handleSide, height: handleSide)
        let handleFillColor = NSColor.white
        let handleStrokeColor = NSColor.darkGray
        
        var corners:[NSPoint] = [segment.rect.origin]
        corners.append(NSPoint(x: segment.rect.origin.x + segment.rect.size.width, y: segment.rect.origin.y))
        corners.append(NSPoint(x: segment.rect.origin.x + segment.rect.size.width, y: segment.rect.origin.y + segment.rect.size.height))
        corners.append(NSPoint(x: segment.rect.origin.x, y: segment.rect.origin.y + segment.rect.size.height))
        
        for nextPoint in corners
        {
            let handleRect = NSRect(origin: NSPoint(x: nextPoint.x - handleSide / 2.0, y: nextPoint.y - handleSide / 2.0), size: handleBaseRect.size)
            
            let handlePath = NSBezierPath(rect: handleRect)
            
            handleFillColor.set()
            handlePath.fill()
            handleStrokeColor.setStroke()
            handlePath.stroke()
        }
    }
    
    // MARK: Tooltips to display over segments
    func view(_ view: NSView, stringForToolTip tag: NSView.ToolTipTag, point: NSPoint, userData data: UnsafeMutableRawPointer?) -> String
    {
        var result = "Error!"
        
        // DLog("Tooltip tag to display: \(tag)")
        for nextSegment in self.segments
        {
            if nextSegment.toolTipTag == tag
            {
                let terminal = nextSegment.segment.inLayer!.parentTerminal
                var currDir = "+"
                if terminal.currentDirection < 0
                {
                    currDir = "-"
                }
                
                result = "Terminal: \(terminal.name)\nCurrent Direction: \(currDir)"
            }
        }
        
        return result
    }
    
    // MARK: Mouse Events
    override func mouseDown(with event: NSEvent) {
        
        if self.mode == .zoomRect
        {
            self.mouseDownWithZoomRect(event: event)
            return
        }
        else if self.mode == .selectSegment
        {
            self.mouseDownWithSelectSegment(event: event)
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
        
        if self.mode == .zoomRect
        {
            let endPoint = self.convert(event.locationInWindow, from: nil)
            let newSize = NSSize(width: endPoint.x - self.zoomRect!.origin.x, height: endPoint.y - self.zoomRect!.origin.y)
            self.zoomRect!.size = newSize
            self.handleZoomRect(zRect: self.zoomRect!)
        }
        
        self.mode = .selectSegment
        self.needsDisplay = true
    }
    
    func mouseDraggedWithZoomRect(event:NSEvent)
    {
        let endPoint = self.convert(event.locationInWindow, from: nil)
        let newSize = NSSize(width: endPoint.x - self.zoomRect!.origin.x, height: endPoint.y - self.zoomRect!.origin.y)
        self.zoomRect!.size = newSize
        self.needsDisplay = true
    }
    
    func mouseDownWithSelectSegment(event:NSEvent)
    {
        let clickPoint = self.convert(event.locationInWindow, from: nil)
        
        self.currentSegment = nil
        
        for nextSegment in self.segments
        {
            if nextSegment.contains(point: clickPoint)
            {
                self.currentSegment = nextSegment
                self.appController!.UpdateToggleActivationMenu(deactivate: nextSegment.isActive)
                break
            }
        }
        
        self.needsDisplay = true
    }
    
    func mouseDownWithZoomRect(event:NSEvent)
    {
        let eventLocation = event.locationInWindow
        let localLocation = self.convert(eventLocation, from: nil)
        
        self.zoomRect = NSRect(origin: localLocation, size: NSSize())
        self.needsDisplay = true
    }
    
    // MARK: Zoom Functions
    // transformer display zoom functions
    func handleZoomAll(coreRadius:CGFloat, windowHt:CGFloat, tankWallR:CGFloat)
    {
        // aspectRatio is defined as width/height
        // it is assumed that the window height (z) is ALWAYS the dominant dimension compared to the "half tank-width" in the r-direction
        let aspectRatio = self.frame.width / self.frame.height
        let boundsW = windowHt * aspectRatio
        
        let newRect = NSRect(x: coreRadius, y: 0.0, width: boundsW, height: windowHt)
        // DLog("NewRect: \(newRect)")
        
        self.bounds = newRect
        
        // DLog("Bounds: \(self.bounds)")
        self.boundary = self.bounds
        
        self.boundary.size.width = tankWallR - coreRadius
        // DLog("Boundary: \(self.boundary)")
        
        self.needsDisplay = true
    }
    
    // the zoom in/out ratio (maybe consider making this user-settable)
    let zoomRatio:CGFloat = 0.75
    func handleZoomOut()
    {
        self.scaleUnitSquare(to: (NSSize(width: zoomRatio, height: zoomRatio)))
        self.needsDisplay = true
    }
    
    func handleZoomIn()
    {
        self.scaleUnitSquare(to: NSSize(width: 1.0 / zoomRatio, height: 1.0 / zoomRatio))
        self.needsDisplay = true
    }
    
    func handleZoomRect(zRect:NSRect)
    {
        self.zoomRect = NSRect()
        
        let aspectRatio = self.frame.width / self.frame.height
        
        // Call PCH standard function (in GlobalDefs.swift) to force the current aspect ratio on the zoom rectangle
        self.bounds = ForceAspectRatioAndNormalize(srcRect: zRect, widthOverHeightRatio: aspectRatio)
        self.needsDisplay = true
    }
    
}
