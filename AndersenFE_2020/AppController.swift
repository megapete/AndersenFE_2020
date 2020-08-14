//
//  AppController.swift
//  AndersenFE_2020
//
//  Created by Peter Huber on 2020-07-20.
//  Copyright © 2020 Peter Huber. All rights reserved.
//

import Cocoa

// Keys into User Defaults
// Key (String) so that the user doesn't have to go searching for the last folder he opened
let LAST_OPENED_INPUT_FILE_KEY = "PCH_AFE2020_LastInputFile"
// Key (Bool) to decide if windings with radial ducts should be split into separate Andersen layers
let MODEL_RADIAL_DUCTS_KEY = "PCH_AFE2020_ModelRadialDucts"
// Key (Bool) to decide if terminals with number 0 should be modeled
let MODEL_ZERO_TERMINALS_KEY = "PCH_AFE2020_ModelZeroTerminals"
// Key (Bool) to decide if internal taps on layer windings should be modeled
let MODEL_INTERNAL_LAYER_TAPS_KEY = "PCH_AFE2020_ModelInternalLayerTaps"
// Key (Bool) to decide if upper and lower axial gaps are symmetric about the axial center
let UPPER_AND_LOWER_AXIAL_GAPS_SYMMETRIC_KEY = "PCH_AFE2020_UpperAndLowerAxialGapsSymmetrical"
// Key to indicate whether multistart windings electrical height is to the centers of the the conductor stack
let MULTI_START_ELECTRIC_HEIGHT_TO_CENTER_KEY = "PCH_AFE2020_MultiStartElecHeightIsToCenter"
// Key to default to Terminal 2 as the reference VA terminal
let DEFAULT_REFERENCE_TERMINAL_2_KEY = "PCH_AFE2020_DefaultReferenceTerminal2"
// Key to default to using the Andersen FLD12 program for finite-element calculations
let USE_ANDERSEN_FLD12_PROGRAM_KEY = "PCH_AFE2020_UseAndersenFLD12"
// Key to default to letting the program force Ampere-Turn balance at all times
let FORCE_AMPERE_TURN_BALANCE_AUTOMATICALLY_KEY = "PCH_AFE2020_ForceAmpereTurnBalance"

// Extension for our custonm file type
let AFE2020_EXTENSION = "afe2020"

// Struct for preferences. Preferences are handled as follows:
// 1) The currently-saved user preferences are used when opening an Excel-generated file. These preferences are applied to each Winding in the model (and saved as a property of each separate winding).
// 2) The user can selectively change the preferences for any winding as he likes.
// 3) SOme preferences are obviously not intended to be "saved" along with the file (like the "useAndersenFLD12" oreference) but they still will be. This shouldn't be an issue for now, but I will need to decide how to treat these things.
struct PCH_AFE2020_Prefs:Codable {
    
    struct WindingPrefs:Codable {
        var modelRadialDucts:Bool
        var model0Terminals:Bool
        var modelInternalLayerTaps:Bool
        var upperLowerAxialGapsAreSymmetrical:Bool
        var multiStartElecHtIsToCenter:Bool
    }
    
    var wdgPrefs:WindingPrefs
    
    struct GeneralPrefs:Codable {
        var defaultRefTerm2:Bool
        var useAndersenFLD12:Bool
        var forceAmpTurnBalance:Bool
    }
    
    var generalPrefs:GeneralPrefs
}

// Struct to save transformers to disk (this may grow with time)
struct PCH_AFE2020_Save_Struct:Codable {

    let transformer:Transformer
}

class AppController: NSObject, NSMenuItemValidation {
    
    // MARK: Transformer Properties
    var currentTxfo:Transformer? = nil
    var lastOpenedTxfoFile:URL? = nil
    var currentTxfoIsDirty:Bool = false
    var lastSavedTxfoFile:URL? = nil
    
    // MARK: Undo & Redo
    var undoStack:[PCH_AFE2020_Save_Struct] = []
    var redoStack:[PCH_AFE2020_Save_Struct] = []
    
    // MARK: Menu outlets
    @IBOutlet weak var saveMenuItem: NSMenuItem!
    @IBOutlet weak var saveAndersenFileMenuItem: NSMenuItem!
    @IBOutlet weak var closeTransformerMenuItem: NSMenuItem!
    
    @IBOutlet weak var setRefTerminalMenuItem: NSMenuItem!
    @IBOutlet weak var setMVAMenuItem: NSMenuItem!
    @IBOutlet weak var setNIdistMenuItem: NSMenuItem!
    
    
    
    @IBOutlet weak var zoomInMenuItem: NSMenuItem!
    @IBOutlet weak var zoomOutMenuItem: NSMenuItem!
    @IBOutlet weak var zoomRectMenuItem: NSMenuItem!
    @IBOutlet weak var zoomAllMenuItem: NSMenuItem!
    
    // MARK: Preferences
    var preferences = PCH_AFE2020_Prefs(wdgPrefs: PCH_AFE2020_Prefs.WindingPrefs(modelRadialDucts: false, model0Terminals: false, modelInternalLayerTaps: false, upperLowerAxialGapsAreSymmetrical: true, multiStartElecHtIsToCenter: true), generalPrefs: PCH_AFE2020_Prefs.GeneralPrefs(defaultRefTerm2: true, useAndersenFLD12: true, forceAmpTurnBalance: true))
    
    // MARK: UI elements
    @IBOutlet weak var mainWindow: NSWindow!
    @IBOutlet weak var txfoView: TransformerView!
    @IBOutlet weak var termsView: TerminalsView!
    @IBOutlet weak var dataView: DataView!
    
    
    // MARK: Initialization
    // set up our preference switches
    override func awakeFromNib() {
        
        // The default (original) values for these Bools is false anyway, so it doesn't matter if they don't exist
        self.preferences.wdgPrefs.modelRadialDucts = UserDefaults.standard.bool(forKey: MODEL_RADIAL_DUCTS_KEY)
        self.preferences.wdgPrefs.model0Terminals = UserDefaults.standard.bool(forKey: MODEL_ZERO_TERMINALS_KEY)
        self.preferences.wdgPrefs.modelInternalLayerTaps = UserDefaults.standard.bool(forKey: MODEL_INTERNAL_LAYER_TAPS_KEY)
        
        // The default (original) value for this Bool is true, so test to make sure it exists
        if UserDefaults.standard.object(forKey: UPPER_AND_LOWER_AXIAL_GAPS_SYMMETRIC_KEY) != nil
        {
            self.preferences.wdgPrefs.upperLowerAxialGapsAreSymmetrical = UserDefaults.standard.bool(forKey: UPPER_AND_LOWER_AXIAL_GAPS_SYMMETRIC_KEY)
        }
        
        // The default (original) value for this Bool is true, so test to make sure it exists
        if UserDefaults.standard.object(forKey: MULTI_START_ELECTRIC_HEIGHT_TO_CENTER_KEY) != nil
        {
            self.preferences.wdgPrefs.multiStartElecHtIsToCenter = UserDefaults.standard.bool(forKey: MULTI_START_ELECTRIC_HEIGHT_TO_CENTER_KEY)
        }
        
        // The default (original) value for this Bool is true, so test to make sure it exists
        if UserDefaults.standard.object(forKey: DEFAULT_REFERENCE_TERMINAL_2_KEY) != nil
        {
            self.preferences.generalPrefs.defaultRefTerm2 = UserDefaults.standard.bool(forKey: DEFAULT_REFERENCE_TERMINAL_2_KEY)
        }
        
        // The default (original) value for this Bool is true, so test to make sure it exists
        if UserDefaults.standard.object(forKey: USE_ANDERSEN_FLD12_PROGRAM_KEY) != nil
        {
            self.preferences.generalPrefs.useAndersenFLD12 = UserDefaults.standard.bool(forKey: USE_ANDERSEN_FLD12_PROGRAM_KEY)
        }
        
        // The default (original) value for this Bool is true, so test to make sure it exists
        if UserDefaults.standard.object(forKey: FORCE_AMPERE_TURN_BALANCE_AUTOMATICALLY_KEY) != nil
        {
            self.preferences.generalPrefs.forceAmpTurnBalance = UserDefaults.standard.bool(forKey: FORCE_AMPERE_TURN_BALANCE_AUTOMATICALLY_KEY)
        }
        
        // Set up things for the views
        SegmentPath.bkGroundColor = .white
        
        // Stuff a reference to this AppController into the TransformerView
        self.txfoView.appController = self
        
    }
    
    // MARK: Model Modification & Update functions
    func updateCurrentTransformer(newTransformer:Transformer, reinitialize:Bool = false) {
        
        DLog("Updating transformer model...")
        
        // make sure that the VAs of the various terminals is updated (this is done in the AmpTurns() function of Transformer)
        do
        {
            let _ = try newTransformer.AmpTurns(forceBalance: self.preferences.generalPrefs.forceAmpTurnBalance, showDistributionDialog: false)
        }
        catch
        {
            // An error occurred
            let alert = NSAlert(error: error)
            let _ = alert.runModal()
            return
        }
        
        // push old transformer (if any) onto the undo stack
        if let oldTransformer = self.currentTxfo
        {
            undoStack.insert(PCH_AFE2020_Save_Struct(transformer: oldTransformer), at: 0)
        }
        
        self.currentTxfo = newTransformer
        self.currentTxfoIsDirty = true
        
        if reinitialize
        {
            self.initializeViews()
        }
        else
        {
            self.updateViews()
        }
    }
    
    @IBAction func handleSetReferenceMVA(_ sender: Any) {
        
        let refTerm = self.currentTxfo!.refTermNum!
        
        var currentMVA = 0.0
        
        var va = 0.0
        let txfo = self.currentTxfo!
        for nextTerm in txfo.terminals
        {
            if let term = nextTerm
            {
                if term.andersenNumber == refTerm
                {
                    va += term.VA
                }
            }
        }
        
        currentMVA = va / 1.0E6
        
        let mvaDlog = ModifyReferenceMvaDialog(currentMVA: currentMVA)
        
        if mvaDlog.runModal() == .OK
        {
            doSetReferenceMVA(newMVA: mvaDlog.MVA)
        }
    }
    
    func doSetReferenceMVA(newMVA:Double)
    {
        guard let currTxfo = self.currentTxfo else
        {
            DLog("Current transformer is not defined")
            return
        }
        
        guard currTxfo.CurrentCarryingTurns(terminal: currTxfo.refTermNum!) != 0.0 else
        {
            let alert = NSAlert()
            alert.messageText = "Reference Terminal has no effective turns!"
            alert.informativeText = "Add some turns to the reference terminal before trying to change the MVA of the transformer"
            let _ = alert.runModal()
            return
        }
        
        do
        {
            let txfo = currTxfo.Copy()
            
            let vpn = try txfo.VoltsPerTurn()
            
            let refWdgs = try txfo.WindingsFromAndersenNumber(termNum: txfo.refTermNum!)
            
            let phaseFactor = refWdgs[0].terminal.phaseFactor
            let connFactor = refWdgs[0].terminal.connectionFactor
            
            var lineVolts = txfo.CurrentCarryingTurns(terminal: txfo.refTermNum!) * vpn
            var legVA = newMVA * 1.0E6 / phaseFactor
            
            if lineVolts == 0.0
            {
                lineVolts = txfo.NoLoadTurns(terminal: txfo.refTermNum!) * vpn
                legVA = 0.0
            }
            
            let legVolts = lineVolts / connFactor
            
            let legAmps = legVA / legVolts
            
            for nextWdg in refWdgs
            {
                let voltage = nextWdg.CurrentCarryingTurns() * vpn
                
                nextWdg.terminal.SetVoltsAndVA(legVolts: voltage, amps: legAmps)
            }
            
            self.updateCurrentTransformer(newTransformer: txfo)
        }
        catch
        {
            let alert = NSAlert(error: error)
            let _ = alert.runModal()
            return
        }
    }
    
    
    @IBAction func handleSetReferenceTerminal(_ sender: Any) {
        
        let refnumDlog = ModifyReferenceTerminalDialog(oldTerminal: self.currentTxfo!.refTermNum)
        
        var oldRefNumIndex = -1
        if let refNum = self.currentTxfo!.refTermNum
        {
            oldRefNumIndex = refNum - 1
        }
        
        if refnumDlog.runModal() == .OK
        {
            if refnumDlog.currentRefIndex != oldRefNumIndex
            {
                let alert = NSAlert()
                alert.messageText = "Changing the reference terminal will cause the transformer to be recreated from scratch, using the current terminal voltages, VAs, etc."
                alert.informativeText = "You may Undo this operation"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Cancel")
                
                if alert.runModal() == .OK
                {
                    if refnumDlog.currentRefIndex >= 0
                    {
                        self.doSetReferenceTerminal(refTerm: refnumDlog.currentRefIndex + 1)
                    }
                }
            }
        }
    }
    
    func doSetReferenceTerminal(refTerm:Int)
    {
        let newTransformer = self.currentTxfo!.Copy()
        newTransformer.refTermNum = refTerm
        self.updateCurrentTransformer(newTransformer: newTransformer, reinitialize: true)
    }
    
    
    /*
    // Code for testing View-related drawing stuff (will eventually be commented out)
    @IBAction func testInitView(_ sender: Any) {
        // testing for now
        self.txfoView.zoomAll(coreRadius: 10.0, windowHt: 1000.0, tankWallR: 250.0)
        print("Bounds: \(self.txfoView.bounds)")
        let segPath = NSBezierPath(rect: NSRect(x: 50.0, y: 50.0, width: 200.0, height: 800.0))
        let testSegment = SegmentPath(path: segPath, segmentColor: .red, isActive: true)
        self.txfoView.segments.append(testSegment)
        
        self.txfoView.needsDisplay = true
    }
    @IBAction func testZoomOut(_ sender: Any) {
        self.txfoView.scaleUnitSquare(to: NSSize(width: 0.5, height: 0.5))
        print("Bounds: \(self.txfoView.bounds)")
        self.txfoView.setBoundsOrigin(NSPoint(x: -50.0, y: -50.0))
        self.txfoView.needsDisplay = true
    }
    @IBAction func testZoomAll(_ sender: Any) {
        self.txfoView.zoomAll(coreRadius: 10.0, windowHt: 1000.0, tankWallR: 250.0)
    }
    @IBAction func testZoomIn(_ sender: Any) {
        self.txfoView.setBoundsOrigin(NSPoint(x: 20.0, y: 70.0))
        let aspectRatio = self.txfoView.frame.width / self.txfoView.frame.height
        let height:CGFloat = 200.0
        let width = height * aspectRatio
        self.txfoView.setBoundsSize(NSSize(width: width, height: height))
    }
    @IBAction func handleTestTermView(_ sender: Any) {
        termsView.SetTermData(termNum: 5, name: "TEST", displayVolts: 123000.0, VA: 47000000, connection: .auto_common)
    }
    
    @IBAction func handleTestAmpereTurnsView(_ sender: Any) {
        
        // let ampTurnDlog = AmpTurnsDistributionDialog(term1: -80.0, term2: -20.0, term3: 100.0)
        // let _ = ampTurnDlog.runModal()
    }
 */
    
    // MARK: Zoom functions
    @IBAction func handleZoomIn(_ sender: Any) {
        
        self.txfoView.zoomIn()
    }
    
    @IBAction func handleZoomOut(_ sender: Any) {
        
        self.txfoView.zoomOut()
    }
    
    @IBAction func handleZoomAll(_ sender: Any) {
        
        guard let txfo = self.currentTxfo else
        {
            return
        }
        
        self.txfoView.zoomAll(coreRadius: CGFloat(txfo.core.diameter / 2.0), windowHt: CGFloat(txfo.core.windHt), tankWallR: CGFloat(txfo.DistanceFromCoreCenterToTankWall()))
    }
    
    // MARK: View functions
    // This function does the following things:
    // 1) Sets the bounds of the transformer view to the window of the transformer (does a "zoom all" using the current transformer core)
    // 2) Calls updateViews() to draw the coil segments
    func initializeViews()
    {
        self.handleZoomAll(self)
        
        self.termsView.InitializeFields()
        
        self.dataView.InitializeFields()
        
        self.updateViews()
    }
    
    func updateViews()
    {
        guard let txfo = self.currentTxfo else
        {
            return
        }
        
        self.txfoView.segments = []
        
        for nextWdg in txfo.windings
        {
            for nextLayer in nextWdg.layers
            {
                if nextLayer.parentTerminal.andersenNumber < 1
                {
                    continue
                }
                
                let pathColor = TerminalsView.termColors[nextLayer.parentTerminal.andersenNumber - 1]
                
                for nextSegment in nextLayer.segments
                {
                    let newSegPath = SegmentPath(segment: nextSegment, segmentColor: pathColor)
                    
                    self.txfoView.segments.append(newSegPath)
                }
            }
        }
        
        self.txfoView.needsDisplay = true
        
        let termSet = txfo.AvailableTerminals()
        
        for nextTerm in termSet
        {
            do
            {
                let terminals = try txfo.TerminalsFromAndersenNumber(termNum: nextTerm)
                var isRef = false
                if let refTerm = txfo.refTermNum
                {
                    if refTerm == nextTerm
                    {
                        isRef = true
                    }
                }
                
                let termLineVolts = try txfo.TerminalLineVoltage(terminal: nextTerm)
                
                self.termsView.SetTermData(termNum: nextTerm, name: terminals[0].name, displayVolts: termLineVolts, VA: terminals[0].VA, connection: terminals[0].connection, isReference: isRef)
            }
            catch
            {
                // An error occurred
                let alert = NSAlert(error: error)
                let _ = alert.runModal()
                return
            }
        }
        
        do
        {
            let vpn = try txfo.VoltsPerTurn()
            self.dataView.SetVpN(newVpN: vpn, refTerm: txfo.refTermNum)
            
            let newNI = try txfo.AmpTurns(forceBalance: self.preferences.generalPrefs.forceAmpTurnBalance, showDistributionDialog: false)
            self.dataView.SetAmpereTurns(newNI: newNI)
        }
        catch
        {
            let alert = NSAlert(error: error)
            let _ = alert.runModal()
            return
        }
       
    }
    
    // MARK: Menu validation
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        
        if menuItem == self.saveMenuItem
        {
            return self.lastOpenedTxfoFile != nil && self.currentTxfoIsDirty
        }
        else if menuItem == self.closeTransformerMenuItem || menuItem == self.zoomInMenuItem || menuItem == self.zoomOutMenuItem || menuItem == self.zoomAllMenuItem || menuItem == self.zoomRectMenuItem || menuItem == self.setRefTerminalMenuItem
        {
            return currentTxfo != nil
        }
        else if menuItem == self.setMVAMenuItem
        {
            return currentTxfo != nil && currentTxfo!.refTermNum != nil && currentTxfo!.CurrentCarryingTurns(terminal: currentTxfo!.refTermNum!) != 0.0
        }
        else if menuItem == self.setNIdistMenuItem
        {
            return currentTxfo != nil && currentTxfo!.refTermNum != nil && currentTxfo!.AvailableTerminals().count >= 3
        }
        
        return true
    }
    
    // MARK: Preference functions
    @IBAction func handleGlobalPreferences(_ sender: Any) {
        
        let alert = NSAlert()
        alert.messageText = "Note: Making changes to the preferences will reset the model to the initially loaded model (but using the new preferences)."
        alert.alertStyle = .informational
        let _ = alert.runModal()
        
        let prefDlog = PreferencesDialog(scopeLabel: "When loading an Excel-generated design file:", modelRadialDucts: self.preferences.wdgPrefs.modelRadialDucts, modelZeroTerms: self.preferences.wdgPrefs.model0Terminals, modelLayerTaps: self.preferences.wdgPrefs.modelInternalLayerTaps, upperLowerGapsAreSymmetric: self.preferences.wdgPrefs.upperLowerAxialGapsAreSymmetrical, multiStartElecHtIsToCenters: self.preferences.wdgPrefs.multiStartElecHtIsToCenter, defaultRefTerm2: self.preferences.generalPrefs.defaultRefTerm2, useAndersenFLD12: self.preferences.generalPrefs.useAndersenFLD12, forceAmpTurnBalance: self.preferences.generalPrefs.forceAmpTurnBalance)
        
        let _ = prefDlog.runModal()
        
        var txfoNeedsUpdate = false
        
        if prefDlog.modelRadialDucts != self.preferences.wdgPrefs.modelRadialDucts
        {
            self.preferences.wdgPrefs.modelRadialDucts = !self.preferences.wdgPrefs.modelRadialDucts
            UserDefaults.standard.set(self.preferences.wdgPrefs.modelRadialDucts, forKey: MODEL_RADIAL_DUCTS_KEY)
            txfoNeedsUpdate = true
        }
        
        if prefDlog.modelZeroTerms != self.preferences.wdgPrefs.model0Terminals
        {
            self.preferences.wdgPrefs.model0Terminals = !self.preferences.wdgPrefs.model0Terminals
            UserDefaults.standard.set(self.preferences.wdgPrefs.model0Terminals, forKey: MODEL_ZERO_TERMINALS_KEY)
            txfoNeedsUpdate = true
        }
        
        if prefDlog.modelLayerTaps != self.preferences.wdgPrefs.modelInternalLayerTaps
        {
            self.preferences.wdgPrefs.modelInternalLayerTaps = !self.preferences.wdgPrefs.modelInternalLayerTaps
            UserDefaults.standard.set(self.preferences.wdgPrefs.modelInternalLayerTaps, forKey: MODEL_INTERNAL_LAYER_TAPS_KEY)
            txfoNeedsUpdate = true
        }
        
        if prefDlog.upperLowerGapsAreSymmetric != self.preferences.wdgPrefs.upperLowerAxialGapsAreSymmetrical
        {
            self.preferences.wdgPrefs.upperLowerAxialGapsAreSymmetrical = !self.preferences.wdgPrefs.upperLowerAxialGapsAreSymmetrical
            UserDefaults.standard.set(self.preferences.wdgPrefs.upperLowerAxialGapsAreSymmetrical, forKey: UPPER_AND_LOWER_AXIAL_GAPS_SYMMETRIC_KEY)
            txfoNeedsUpdate = true
        }
        
        if prefDlog.multiStartElecHtIsToCenters != self.preferences.wdgPrefs.multiStartElecHtIsToCenter
        {
            self.preferences.wdgPrefs.multiStartElecHtIsToCenter = !self.preferences.wdgPrefs.multiStartElecHtIsToCenter
            UserDefaults.standard.set(self.preferences.wdgPrefs.multiStartElecHtIsToCenter, forKey: MULTI_START_ELECTRIC_HEIGHT_TO_CENTER_KEY)
            txfoNeedsUpdate = true
        }
        
        if prefDlog.defaultRefTerm2 != self.preferences.generalPrefs.defaultRefTerm2
        {
            self.preferences.generalPrefs.defaultRefTerm2 = !self.preferences.generalPrefs.defaultRefTerm2
            UserDefaults.standard.set(self.preferences.generalPrefs.defaultRefTerm2, forKey: DEFAULT_REFERENCE_TERMINAL_2_KEY)
            txfoNeedsUpdate = true
        }
        
        if prefDlog.useAndersenFLD12 != self.preferences.generalPrefs.useAndersenFLD12
        {
            self.preferences.generalPrefs.useAndersenFLD12 = !self.preferences.generalPrefs.useAndersenFLD12
            UserDefaults.standard.set(self.preferences.generalPrefs.useAndersenFLD12, forKey: USE_ANDERSEN_FLD12_PROGRAM_KEY)
            // don't update the transformer for this
        }
        
        if txfoNeedsUpdate
        {
            if let oldTransformer = self.currentTxfo
            {
                let newTransformer = oldTransformer.Copy()
                newTransformer.InitializeWindings(prefs: self.preferences)
                self.updateCurrentTransformer(newTransformer: newTransformer, reinitialize: true)
            }
        }
    }
    
    // MARK: Saving and Loading functions
    @IBAction func handleSaveAndersenInputFile(_ sender: Any) {
        
    }
    
    @IBAction func handleSaveAFE2020File(_ sender: Any) {
        
        guard let fileURL = self.lastOpenedTxfoFile else {
            
            self.handleSaveAsAFE2020File(sender)
            return
        }
        
        self.doSaveAFE2020File(fileURL: fileURL)
    }
    
    @IBAction func handleSaveAsAFE2020File(_ sender: Any) {
        
        let saveAsPanel = NSSavePanel()
        saveAsPanel.title = "AndersenFE 2020 file"
        saveAsPanel.message = "Save AndersenFE 2020 file"
        saveAsPanel.allowedFileTypes = [AFE2020_EXTENSION]
        saveAsPanel.allowsOtherFileTypes = false
        
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
            
            let fileData = try encoder.encode(PCH_AFE2020_Save_Struct(transformer: currTxfo))
            
            if FileManager.default.fileExists(atPath: fileURL.path)
            {
                try FileManager.default.removeItem(at: fileURL)
            }
            
            FileManager.default.createFile(atPath: fileURL.path, contents: fileData, attributes: nil)
            
            self.lastOpenedTxfoFile = fileURL
            self.currentTxfoIsDirty = false
            
            self.mainWindow.title = fileURL.deletingPathExtension().lastPathComponent
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
        openPanel.allowedFileTypes = [AFE2020_EXTENSION]
        openPanel.allowsOtherFileTypes = false
        
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
                let _ = self.doOpen(fileURL: fileURL)
            }
            else
            {
                DLog("This shouldn't ever happen...")
            }
        }
    }
    
    
    @IBAction func handleOpenDesignFile(_ sender: Any)
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
                let _ = self.doOpen(fileURL: fileURL)
            }
            else
            {
                DLog("This shouldn't ever happen...")
            }
        }
    }
    
    func doOpen(fileURL:URL) -> Bool
    {
        if !FileManager.default.fileExists(atPath: fileURL.path)
        {
            let alert = NSAlert()
            alert.messageText = "The file does not exist!"
            alert.alertStyle = .critical
            let _ = alert.runModal()
            return false
        }
        
        if fileURL.pathExtension == AFE2020_EXTENSION
        {
            do {
                
                let fileData = try Data(contentsOf: fileURL)
                
                let decoder = PropertyListDecoder()
                
                let saveStruct:PCH_AFE2020_Save_Struct = try decoder.decode(PCH_AFE2020_Save_Struct.self, from: fileData)
                
                let newTxfo = saveStruct.transformer
                
                self.lastOpenedTxfoFile = fileURL
                
                NSDocumentController.shared.noteNewRecentDocumentURL(fileURL)
                
                self.mainWindow.title = fileURL.deletingPathExtension().lastPathComponent
                
                self.updateCurrentTransformer(newTransformer: newTxfo, reinitialize: true)
                
                // the call to updateModel will have set the "dirty" flag to true, set it back to false
                self.currentTxfoIsDirty = false
                
                return true
            }
            catch
            {
                let alert = NSAlert(error: error)
                let _ = alert.runModal()
                return false
            }
        }
        else
        {
            do {
                
                // create the current Transformer from the Excel design file
                let newTxfo = try Transformer(designFile: fileURL, prefs: self.preferences)
                
                // if we make it here, we have successfully opened the file, so save it as the "last successfully opened file"
                UserDefaults.standard.set(fileURL, forKey: LAST_OPENED_INPUT_FILE_KEY)
                
                if self.preferences.generalPrefs.defaultRefTerm2
                {
                    newTxfo.refTermNum = 2
                }
            
                self.lastOpenedTxfoFile = nil
                
                NSDocumentController.shared.noteNewRecentDocumentURL(fileURL)
                
                self.mainWindow.title = fileURL.lastPathComponent
                
                self.updateCurrentTransformer(newTransformer: newTxfo, reinitialize: true)
                
                return true
            }
            catch
            {
                let alert = NSAlert(error: error)
                let _ = alert.runModal()
                return false
            }
        }
    }
}
