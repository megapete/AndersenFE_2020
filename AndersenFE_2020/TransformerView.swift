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

class TransformerView: NSView, NSViewToolTipOwner, NSMenuItemValidation {
    
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
    
    var fluxlines:[NSBezierPath] = []
    
    @IBOutlet weak var contextualMenu:NSMenu!
    @IBOutlet weak var reverseCurrentDirectionMenuItem:NSMenuItem!
    @IBOutlet weak var toggleActivationMenuItem:NSMenuItem!
    @IBOutlet weak var activateAllWdgTurnsMenuItem:NSMenuItem!
    @IBOutlet weak var deactivateAllWdgTurnsMenuItem:NSMenuItem!
    @IBOutlet weak var moveWdgRadiallyMenuItem:NSMenuItem!
    @IBOutlet weak var moveWdgAxiallyMenuItem:NSMenuItem!
    @IBOutlet weak var splitSegmentMenuItem:NSMenuItem!
    
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
        
        if !fluxlines.isEmpty
        {
            NSColor.black.set()
            
            for nextPath in fluxlines
            {
                nextPath.stroke()
            }
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
                
                var andersenData = ""
                if let andersenResults = self.appController!.GetSCdataForSegment(andersenSegNum: nextSegment.segment.andersenSegNum)
                {
                    andersenData = "\nAve. Eddy p.u.: \(andersenResults.eddyPUaverage)\n"
                    
                    let maxOrigin = andersenResults.eddyMaxRect.origin
                    let maxOuter = NSPoint(x: maxOrigin.x + andersenResults.eddyMaxRect.width, y: maxOrigin.y + andersenResults.eddyMaxRect.height)
                    let maxRectString = String(format: "(%.1f, %.1f, %.1f, %.1f)", maxOrigin.x, maxOrigin.y, maxOuter.x, maxOuter.y)
                    andersenData += "Max. Eddy p.u. : \(andersenResults.eddyPUmax)\n In Rect: \(maxRectString)\n"
                    if andersenResults.scMinSpacerBars > 0.0
                    {
                        let actualSpacerBars = nextSegment.segment.inLayer!.parentTerminal.winding!.numRadialSupports
                        andersenData += "Min. Spacer Bars: \(andersenResults.scMinSpacerBars) (Actual: \(actualSpacerBars))\n"
                    }
                    andersenData += "Compression in Radial Spacers: \(andersenResults.scForceInSpacerBlocks) MPa\n"
                    andersenData += "Combined Axial Force: \(andersenResults.scCombinedForce) MPa"
                    
                }
                
                result = "Terminal: \(terminal.name)\nCurrent Direction: \(currDir)\(andersenData)"
            }
        }
        
        return result
    }
    
    // MARK: Contextual Menu Handlers

    @IBAction func handleReverseCurrent(_ sender: Any) {
        
        guard let appCtrl = self.appController, let currSeg = self.currentSegment else
        {
            return
        }
        
        let winding = currSeg.segment.inLayer!.parentTerminal.winding!
        
        appCtrl.doReverseCurrentDirection(winding: winding)
    }
    
    @IBAction func handleMoveWdgRadially(_ sender: Any) {
        
        guard let appCtrl = self.appController, self.currentSegment != nil else
        {
            return
        }
        
        appCtrl.handleMoveWindingRadially(self)
    }
    
    @IBAction func handleMoveWdgAxially(_ sender: Any) {
        
        guard let appCtrl = self.appController, self.currentSegment != nil else
        {
            return
        }
        
        appCtrl.handleMoveWindingAxially(self)
    }
    
    @IBAction func handleToggleActivation(_ sender: Any) {
        
        guard let appCtrl = self.appController, let currSeg = self.currentSegment else
        {
            return
        }
        
        appCtrl.doToggleSegmentActivation(segment: currSeg.segment)
    }
    
    @IBAction func handleActivateAllWindingTurns(_ sender: Any) {
        
        guard let appCtrl = self.appController, let currSeg = self.currentSegment else
        {
            return
        }
        
        appCtrl.doSetActivation(winding: currSeg.segment.inLayer!.parentTerminal.winding!, activate: true)
    }
    
    @IBAction func handleDeactivateAllWindingTurns(_ sender: Any) {
        
        guard let appCtrl = self.appController, let currSeg = self.currentSegment else
        {
            return
        }
        
        appCtrl.doSetActivation(winding: currSeg.segment.inLayer!.parentTerminal.winding!, activate: false)
    }
    
    
    @IBAction func handleSplitSegment(_ sender: Any) {
        
        guard let appCtrl = self.appController, self.currentSegment != nil else
        {
            return
        }
        
        appCtrl.handleSplitSegment(self)
    }
    
    
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        
        guard let appCtrl = self.appController, let txfo = appCtrl.currentTxfo else
        {
            return false
        }
        
        if menuItem == self.reverseCurrentDirectionMenuItem
        {
            guard let currSeg = self.currentSegment else
            {
                return false
            }
            
            let terminal = currSeg.segment.inLayer!.parentTerminal
            let termNum = terminal.andersenNumber
            
            if let refTerm = txfo.niRefTerm
            {
                if refTerm != termNum
                {
                    // DLog("Fraction: \(txfo.FractionOfTerminal(terminal: terminal, andersenNum: termNum))")
                    if txfo.FractionOfTerminal(terminal: terminal, andersenNum: termNum) >= 0.5
                    {
                        // DLog("Returning false because this would cause a reversal of a non-ref terminal")
                        return false
                    }
                }
            }
            
            return currSeg.segment.inLayer!.parentTerminal.winding!.CurrentCarryingTurns() != 0.0
        }
        else if menuItem == self.toggleActivationMenuItem
        {
            guard let segPath = self.currentSegment else
            {
                return false
            }
            
            if segPath.isActive
            {
                let winding = segPath.segment.inLayer!.parentTerminal.winding!
                let totalTerminalTurns = txfo.CurrentCarryingTurns(terminal: winding.terminal.andersenNumber)
                let wdgTurns = winding.CurrentCarryingTurns()
                let segTurns = segPath.segment.activeTurns
                
                if wdgTurns == segTurns && fabs(totalTerminalTurns - wdgTurns) < 0.5
                {
                    return false
                }
            }
        }
        else if menuItem == self.activateAllWdgTurnsMenuItem || menuItem == self.moveWdgAxiallyMenuItem || menuItem == self.moveWdgRadiallyMenuItem || menuItem == self.splitSegmentMenuItem
        {
            return self.currentSegment != nil
        }
        else if menuItem == self.deactivateAllWdgTurnsMenuItem
        {
            guard let segPath = self.currentSegment else
            {
                return false
            }
            
            let winding = segPath.segment.inLayer!.parentTerminal.winding!
            let totalTerminalTurns = txfo.CurrentCarryingTurns(terminal: winding.terminal.andersenNumber)
            let wdgTurns = winding.CurrentCarryingTurns()
            
            if fabs(totalTerminalTurns - wdgTurns) < 0.5
            {
                return false
            }
        }
        
        return true
    }
    
    func UpdateToggleActivationMenu(deactivate:Bool)
    {
        if deactivate
        {
            self.toggleActivationMenuItem.title = "Deactivate segment"
        }
        else
        {
            self.toggleActivationMenuItem.title = "Activate segment"
        }
        
        guard let appCtrl = self.appController else
        {
            return
        }
        
        appCtrl.UpdateToggleActivationMenu(deactivate: deactivate)
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
        
        // check if it was actually a double-click
        if event.clickCount == 2
        {
            if let segmentPath = self.currentSegment
            {
                self.appController!.doToggleSegmentActivation(segment: segmentPath.segment)
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
    
    // MARK: Contextual Menu handling
    
    override func rightMouseDown(with event: NSEvent) {
        
        // reset the mode
        self.mode = .selectSegment
        let eventLocation = event.locationInWindow
        let clickPoint = self.convert(eventLocation, from: nil)
        
        for nextPath in self.segments
        {
            if nextPath.contains(point: clickPoint)
            {
                self.currentSegment = nextPath
                self.UpdateToggleActivationMenu(deactivate: nextPath.segment.IsActive())
                self.needsDisplay = true
                NSMenu.popUpContextMenu(self.contextualMenu, with: event, for: self)
                return
            }
        }
    }
    
    // MARK: Zoom Functions
    // transformer display zoom functions
    func handleZoomAll(coreRadius:CGFloat, windowHt:CGFloat, tankWallR:CGFloat)
    {
        guard let parentView = self.superview else
        {
            return
        }
        
        self.frame = parentView.bounds
        // aspectRatio is defined as width/height
        // it is assumed that the window height (z) is ALWAYS the dominant dimension compared to the "half tank-width" in the r-direction
        let aspectRatio = parentView.bounds.width / parentView.bounds.height
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
        // reset the zoomRect
        self.zoomRect = NSRect()
        
        // get the parent  view's aspect ratio
        guard let parentView = self.superview else
        {
            return
        }
                
        let contentRectangle = parentView.bounds
        let contentAspectRatio = contentRectangle.width / contentRectangle.height
        
        print("Old frame: \(self.frame); Old Bounds: \(self.bounds)")
        
        // Call PCH standard function (in GlobalDefs.swift) to force the current aspect ratio on the zoom rectangle
        let newViewRect = ForceAspectRatioAndNormalize(srcRect: zRect, widthOverHeightRatio: contentAspectRatio)
        let newScale = self.bounds.width / newViewRect.width
        let frameToBoundsRatio = self.frame.width / self.bounds.width
        let deltaX = newViewRect.origin.x - self.bounds.origin.x
        let deltaY = newViewRect.origin.y - self.bounds.origin.y
        let newFrameOrigin = NSPoint(x: -deltaX * newScale * frameToBoundsRatio, y: -deltaY * newScale * frameToBoundsRatio)
        let newFrameSize = NSSize(width: self.boundary.width * newScale * frameToBoundsRatio, height: self.boundary.height * newScale * frameToBoundsRatio)
        self.bounds = newViewRect
        self.frame = NSRect(origin: newFrameOrigin, size: newFrameSize)
        
        
        print("New frame: \(self.frame); New Bounds: \(self.bounds)")
        
        self.needsDisplay = true
        
    }
    

    
}
