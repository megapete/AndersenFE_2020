//
//  EditOutputDataDialog.swift
//  AndersenFE_2020
//
//  Created by Peter Huber on 2020-09-30.
//  Copyright © 2020 Peter Huber. All rights reserved.
//

import Cocoa

class EditOutputDataDialog: PCH_DialogBox, NSTableViewDataSource, NSTableViewDelegate {
        
    @IBOutlet weak var outDataTableView: NSTableView!
    
    var outputDataStrings:[String] = []
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        
        return self.outputDataStrings.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        var result:NSTextField? = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "OutputData"), owner: self) as? NSTextField
        
        if result == nil
        {
            result = NSTextField(frame: NSRect(x: 0.0, y: 0.0, width: tableView.frame.width, height: 10.0))
            
            result!.identifier = NSUserInterfaceItemIdentifier(rawValue: "OutputData")
        }
        
        result!.stringValue = self.outputDataStrings[row]
        
        return result
    }
}
