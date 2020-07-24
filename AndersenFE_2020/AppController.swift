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
    
    // Currently-loaded transformer properties
    var currentTxfo:Transformer? = nil
    var currentTxfoFile:URL? = nil
    var currentTxfoIsDirty:Bool = false
    var lastSavedTxfoFile:URL? = nil
    
    // My stab at Undo and Redo
    var undoStack:[Transformer] = []
    var redoStack:[Transformer] = []
    
    // Menu outlets for turning them on/off
    @IBOutlet weak var saveMenuItem: NSMenuItem!
    @IBOutlet weak var saveAndersenFileMenuItem: NSMenuItem!
    @IBOutlet weak var closeTransformerMenuItem: NSMenuItem!
    
    
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        
        if menuItem == self.saveMenuItem
        {
            return self.currentTxfoFile != nil && self.currentTxfoIsDirty
        }
        else if menuItem == self.closeTransformerMenuItem
        {
            return currentTxfo != nil
        }
        
        return true
    }
    
    
    @IBAction func handleSaveAndersenInputFile(_ sender: Any) {
        
        
        
    }
    
    @IBAction func handleSaveAFE2020File(_ sender: Any){
        
        guard let fileURL = self.currentTxfoFile else {
            
            self.handleSaveAsAFE2020File(sender)
            return
        }
        
        self.doSaveAFE2020File(fileURL: fileURL)
    }
    
    @IBAction func handleSaveAsAFE2020File(_ sender: Any) {
        
        let saveAsPanel = NSSavePanel()
        saveAsPanel.title = "AndersenFE 2020 file"
        saveAsPanel.message = "Save AndersenFE 2020 file"
        saveAsPanel.allowedFileTypes = ["afe"]
        
        if saveAsPanel.runModal() == .OK
        {
            if let fileURL = saveAsPanel.url
            {
                self.doSaveAFE2020File(fileURL: fileURL)
            }
        }
    }
    
    func doSaveAFE2020File(fileURL:URL)
    {
        guard let currTxfo = self.currentTxfo else {
            
            DLog("Current transformer is not defined")
            return
        }
        let encoder = PropertyListEncoder()
        
        do {
            
            let fileData = try encoder.encode(currTxfo)
            
            if FileManager.default.fileExists(atPath: fileURL.path)
            {
                try FileManager.default.removeItem(at: fileURL)
            }
            
            FileManager.default.createFile(atPath: fileURL.path, contents: fileData, attributes: nil)
        }
        catch
        {
            let alert = NSAlert(error: error)
            let _ = alert.runModal()
            return
        }
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
                    
                    // create the current Transformer from the Excel design file
                    self.currentTxfo = try Transformer(designFile: fileURL)
                    
                    // if we make it here, we have successfully opened the file, so save it as the "last successfully opened file"
                    UserDefaults.standard.set(fileURL, forKey: LAST_OPENED_INPUT_FILE_KEY)
                    
                    // a design file was opened, set the current Transformer as dirty to make sure that the user is prompted to save it as an AndersenFE-2020 file
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
