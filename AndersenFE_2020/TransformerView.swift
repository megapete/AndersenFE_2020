//
//  TransformerView.swift
//  AndersenFE_2020
//
//  Created by Peter Huber on 2020-07-29.
//  Copyright © 2020 Peter Huber. All rights reserved.
//

import Cocoa

struct SegmentPath {
    
    let path:NSBezierPath
    let segmentColor:NSColor
    static var bkGroundColor:NSColor = .white
    var isActive:Bool
    
    // constant for showing that a segment is not active
    let nonActiveAlpha:CGFloat = 0.25
    
    mutating func activate()
    {
        if !isActive
        {
            self.clear()
            self.isActive = true
        }
    }
    
    mutating func deactivate()
    {
        if isActive
        {
            self.fill(alpha: nonActiveAlpha)
            self.isActive = false
        }
    }
    
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
        if self.isActive
        {
            self.segmentColor.set()
            self.path.stroke()
        }
    }
    
    func fill(alpha:CGFloat)
    {
        self.segmentColor.withAlphaComponent(alpha).set()
        self.path.fill()
        self.segmentColor.set()
        self.path.stroke()
    }
    
    // fill the path with the background color
    func clear()
    {
        SegmentPath.bkGroundColor.set()
        self.path.fill()
        self.segmentColor.set()
        self.path.stroke()
    }
}

class TransformerView: NSView {

    var segments:[SegmentPath] = []
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
        for nextSegment in self.segments
        {
            nextSegment.show()
        }
        
    }
    
    func zoomAll(windowHt:CGFloat)
    {
        // aspectRatio is defined as width/height
        let aspectRatio = self.frame.width / self.frame.height
        let boundsW = windowHt * aspectRatio
        
        self.bounds = NSRect(x: 0.0, y: 0.0, width: boundsW, height: windowHt)
        
        self.needsDisplay = true
    }
    
}
