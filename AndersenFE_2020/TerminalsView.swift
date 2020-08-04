//
//  TerminalsView.swift
//  AndersenFE_2020
//
//  Created by Peter Huber on 2020-08-03.
//  Copyright © 2020 Peter Huber. All rights reserved.
//

import Cocoa

class TerminalsView: NSView {
    
    var termFields:[NSTextField] = []
    
    override func awakeFromNib() {
        
        for nextView in self.subviews
        {
            if let nextField = nextView as? NSTextField
            {
                self.termFields.append(nextField)
            }
        }
        
        self.termFields.sort(by: {$0.tag < $1.tag})
        
        DLog("Textfield count: \(termFields.count)")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
    }
    
}
