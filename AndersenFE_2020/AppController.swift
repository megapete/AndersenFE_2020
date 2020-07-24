//
//  AppController.swift
//  AndersenFE_2020
//
//  Created by Peter Huber on 2020-07-20.
//  Copyright © 2020 Peter Huber. All rights reserved.
//

import Cocoa

let LAST_OPENED_INPUT_FILE_KEY = "PCH_AFE2020_LastInputFile"

class AppController: NSObject, NSMenuItemValidation {
    
    
    var currentTxfo:Transformer? = nil
    var currentTxfoFile:URL?
    var currentTxfoIsDirty:Bool = false
    
    // My stab at Undo and Redo
    var undoStack:[Transformer] = []
    var redoStack:[Transformer] = []
    
    // Menu outlets for turning them on/off
    @IBOutlet weak var saveMenuItem: NSMenuItem!
    @IBOutlet weak var saveAndersenFileMenuItem: NSMenuItem!
    
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        
        return true
    }
    
    
    @IBAction func handleSaveAndersenInputFile(_ sender: Any) {
    }
    
    @IBAction func handleSaveAFE2020File(_ sender: Any){
        
        guard let fileURL = self.currentTxfoFile else {
            
            self.handleSaveAsAFE2020File(sender)
            return
        }
        
        
    }
    
    @IBAction func handleSaveAsAFE2020File(_ sender: Any) {
    }
    
    @IBAction func handleOpenAFE2020File(_ sender: Any) {
        
        let openPanel = NSOpenPanel()
        
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.title = "AndersenFE 2020 file"
        openPanel.message = "Open a valid AndersenFE 2020 file"
        openPanel.allowsMultipleSelection = false
        openPanel.allowedFileTypes = ["afe"]
        
        // If there was a previously successfully opened design file, set that file's directory as the default, otherwise go to the user's Documents folder
        if let lastFile = UserDefaults.standard.url(forKey: LAST_OPENED_INPUT_FILE_KEY)
        {
            openPanel.directoryURL = lastFile.deletingLastPathComponent()
        }
        else
        {
            openPanel.directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        }
    }
    
    
    @IBAction func handleOpenDesignFIle(_ sender: Any)
    {
        let openPanel = NSOpenPanel()
        
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.title = "Design file"
        openPanel.message = "Open a valid Excel-design-sheet-generated file"
        openPanel.allowsMultipleSelection = false
        
        // If there was a previously successfully opened design file, set that file's directory as the default, otherwise go to the user's Documents folder
        if let lastFile = UserDefaults.standard.url(forKey: LAST_OPENED_INPUT_FILE_KEY)
        {
            openPanel.directoryURL = lastFile.deletingLastPathComponent()
        }
        else
        {
            openPanel.directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        }
        
        if openPanel.runModal() == .OK
        {
            if let fileURL = openPanel.url
            {
                do {
                    
                    self.currentTxfo = try Transformer(designFile: fileURL)
                    
                    UserDefaults.standard.set(fileURL, forKey: LAST_OPENED_INPUT_FILE_KEY)
                    
                    self.currentTxfoIsDirty = true
                }
                catch
                {
                    let alert = NSAlert(error: error)
                    let _ = alert.runModal()
                    return
                }
            }
            else
            {
                DLog("This shouldn't ever happen...")
            }
            
        }
    }
    
}
