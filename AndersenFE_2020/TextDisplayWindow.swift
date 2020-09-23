//
//  TextDisplayWindow.swift
//  AndersenFE_2020
//
//  Created by Peter Huber on 2020-09-23.
//  Copyright © 2020 Peter Huber. All rights reserved.
//

import Cocoa

class TextDisplayWindow: NSObject {
    
    @IBOutlet var window: NSWindow!
    @IBOutlet var textView: NSTextView!
    
    var stringToDisplay = ""
    
    init(stringToDisplay:String) {
        
        super.init()
        
        self.stringToDisplay = stringToDisplay
        
        guard let newNib = NSNib(nibNamed: "TextDisplay", bundle: Bundle.main) else
        {
            ALog("Could not load Nib file")
            return
        }
        
        if !newNib.instantiate(withOwner: self, topLevelObjects: nil)
        {
            ALog("Could not instantiate window")
            return
        }
    }
    
    override func awakeFromNib() {
        
        self.textView.textContainer?.size = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        self.textView.string = self.stringToDisplay
        
        self.window.title = "FLD8 Output"
        self.window.makeKeyAndOrderFront(self)
    }
}
