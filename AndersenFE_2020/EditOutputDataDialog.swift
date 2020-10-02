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
    var removedRows:[Int] = []
    
    init(outputStrings:[String])
    {
        super.init(viewNibFileName: "EditOutputData", windowTitle: "Edit Output List", hideCancel: false, okTitle: "Done", cancelTitle: "Remove", cancelIsEnabled: false)
        
        self.outputDataStrings = outputStrings
    }
    
    override func awakeFromNib() {
        
        DLog("Got awakeFromNib")
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        
        return self.outputDataStrings.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        // This code comes from a variety of sources, including Apple's "Table View Programming Guide" (which can only be seen on the Internet now, and not in the documentation). The comments are my own, based on what I understand about NSTableViews.
        
        // See if we already created the textfield at this row or not
        var result:NSTextField? = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "OutputData"), owner: self) as? NSTextField
        
        // This is the first time through, create the NSTextField
        if result == nil
        {
            // We set the width of the field equal to the tableView's width (the height doesn't matter, set it to something arbitrary)
            result = NSTextField(frame: NSRect(x: 0.0, y: 0.0, width: tableView.frame.width, height: 55.0))
            // Turn off some properties so that the fields look "right" in the table view
            result!.isBezeled = false
            result!.isEditable = false
            result!.drawsBackground = false
            
            // set the identifier for the field so we can find it again
            result!.identifier = NSUserInterfaceItemIdentifier(rawValue: "OutputData")
            
            // DLog("Created one")
        }
        
        // I don't think it's possible for 'result' to be nil at this point, but...
        guard result != nil else
        {
            DLog("Could not create NSTextField!")
            return nil
        }
        
        result!.stringValue = self.outputDataStrings[row]
        
        return result
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
              
        guard let removeButton = self.cancelButton else
        {
            return
        }
        
        removeButton.isEnabled = self.outDataTableView.selectedRow >= 0
        self.cancelButtonIsEnabled = removeButton.isEnabled
        
        guard let theView = self.view else
        {
            return
        }
        
        theView.needsDisplay = true
    }
    
    override func handleCancel() {
        
        // This is kind of kludgy, but we change the function of the Cancel button to removal of the currently-highlighted output data title (if any)
        let rowClicked = self.outDataTableView.selectedRow
        
        if rowClicked < 0
        {
            return
        }
        
        self.outputDataStrings.remove(at: rowClicked)
        self.removedRows.append(rowClicked)
        let indexSet = IndexSet(integer: rowClicked)
        self.outDataTableView.removeRows(at: indexSet, withAnimation: .effectFade)
        
    }
}
