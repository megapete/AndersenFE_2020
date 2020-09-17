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
// Key to default to automatically calculate impedance, etc. after every change
let KEEP_IMPEDANCE_AND_FORCES_UPDATED_KEY = "PCH_AFE2020_KeepImpedanceAndForcesUpdated"

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
        var keepImpedanceUpdated:Bool
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
    // File Menu
    @IBOutlet weak var saveMenuItem: NSMenuItem!
    @IBOutlet weak var saveAndersenFileMenuItem: NSMenuItem!
    @IBOutlet weak var closeTransformerMenuItem: NSMenuItem!
    
    // Transformer Menu
    @IBOutlet weak var setTxfoDescriptionMenuItem: NSMenuItem!
    @IBOutlet weak var setRefTerminalMenuItem: NSMenuItem!
    @IBOutlet weak var setMVAMenuItem: NSMenuItem!
    @IBOutlet weak var setRefVoltageMenuItem: NSMenuItem!
    @IBOutlet weak var setNiRefTermMenuItem: NSMenuItem!
    @IBOutlet weak var setNIdistMenuItem: NSMenuItem!
    
    @IBOutlet weak var TxfoContextMenu:NSMenu!
    
    // Winding Menu
    @IBOutlet weak var reverseCurrentMenuItem: NSMenuItem!
    
    
    @IBOutlet weak var changeWdgNameMenuItem: NSMenuItem!
    @IBOutlet weak var activateAllWdgTurnsMenuItem: NSMenuItem!
    @IBOutlet weak var deactivateAllWdgTurnsMenuItem: NSMenuItem!
    @IBOutlet weak var toggleSegmentActivationMenuItem: NSMenuItem!
    
    // View Menu
    @IBOutlet weak var zoomInMenuItem: NSMenuItem!
    @IBOutlet weak var zoomOutMenuItem: NSMenuItem!
    @IBOutlet weak var zoomRectMenuItem: NSMenuItem!
    @IBOutlet weak var zoomAllMenuItem: NSMenuItem!
    
    // MARK: Preferences
    var preferences = PCH_AFE2020_Prefs(wdgPrefs: PCH_AFE2020_Prefs.WindingPrefs(modelRadialDucts: false, model0Terminals: false, modelInternalLayerTaps: false, upperLowerAxialGapsAreSymmetrical: true, multiStartElecHtIsToCenter: true), generalPrefs: PCH_AFE2020_Prefs.GeneralPrefs(defaultRefTerm2: true, useAndersenFLD12: true, forceAmpTurnBalance: true, keepImpedanceUpdated: true))
    
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
        
        // The default (original) value for this Bool is true, so test to make sure it exists
        if UserDefaults.standard.object(forKey: KEEP_IMPEDANCE_AND_FORCES_UPDATED_KEY) != nil
        {
            self.preferences.generalPrefs.keepImpedanceUpdated = UserDefaults.standard.bool(forKey: KEEP_IMPEDANCE_AND_FORCES_UPDATED_KEY)
        }
        
        // Set up things for the views
        SegmentPath.bkGroundColor = .white
        
        // Stuff a reference to this AppController into the TransformerView
        self.txfoView.appController = self
        
    }
    
    // MARK: Model Modification & Update functions
    func updateCurrentTransformer(newTransformer:Transformer, reinitialize:Bool = false, runAndersen:Bool = true) {
        
        // DLog("Updating transformer model...")
        
        if runAndersen || reinitialize
        {
            // make sure that the VAs of the various terminals is updated (this is done in the AmpTurns() function of Transformer)
            do
            {
                let _ = try newTransformer.AmpTurns(forceBalance: self.preferences.generalPrefs.forceAmpTurnBalance, showDistributionDialog: false)
                
                if self.preferences.generalPrefs.keepImpedanceUpdated
                {
                    if self.preferences.generalPrefs.useAndersenFLD12
                    {
                        let fld12txfo = try newTransformer.QuickFLD12transformer()
                        
                        // Next few lines used to debug the Andersen file - uncomment them to save the file somewhere
                        /*
                         let fileString = PCH_FLD12_Library.createFLD12InputFile(withTxfo: fld12txfo)
                         
                         let savePanel = NSSavePanel()
                         if (savePanel.runModal() == .OK)
                         {
                            try fileString.write(to: savePanel.url!, atomically: false, encoding: .utf8)
                         }
                         // */
                        
                        if let fld12output = PCH_FLD12_Library.runFLD12withTxfo(fld12txfo, outputType: .metric)
                        {
                            newTransformer.scResults = ImpedanceAndScData(andersenOutput: fld12output)
                        }
                        else
                        {
                            let alert = NSAlert()
                            alert.messageText = "Calculation of impedance & forces failed!"
                            alert.informativeText = "Do you wish to save the Andersen input file before reverting to the last transformer?"
                            alert.addButton(withTitle: "Save file")
                            alert.addButton(withTitle: "Continue")
                            alert.alertStyle = .critical
                            
                            if alert.runModal() == .alertFirstButtonReturn
                            {
                                let fileString = PCH_FLD12_Library.createFLD12InputFile(withTxfo: fld12txfo)
                                
                                let savePanel = NSSavePanel()
                                savePanel.message = "Save the Andersen Input File"
                                if (savePanel.runModal() == .OK)
                                {
                                    try fileString.write(to: savePanel.url!, atomically: false, encoding: .utf8)
                                }
                            }
                            
                            return
                        }
                    }
                    else
                    {
                        let alert = NSAlert()
                        alert.messageText = "Calculation of impedance & forces by anything other than Andersen FLD12 is not implemented!"
                        alert.alertStyle = .critical
                        let _ = alert.runModal()
                        return
                    }
                }
            }
            catch
            {
                // An error occurred
                let alert = NSAlert(error: error)
                let _ = alert.runModal()
                return
            }
        }
        
        // push old transformer (if any) onto the undo stack
        if let oldTransformer = self.currentTxfo
        {
            undoStack.insert(PCH_AFE2020_Save_Struct(transformer: oldTransformer), at: 0)
        }
        
        // DLog("Number of transformers currently on the undo stack: \(undoStack.count)")
        
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
    
    
    @IBAction func handleChangeWindingName(_ sender: Any) {
        
        guard let txfo = currentTxfo, let segPath = self.txfoView.currentSegment else
        {
            return
        }
        
        let oldName = segPath.segment.inLayer!.parentTerminal.name
        let winding = segPath.segment.inLayer!.parentTerminal.winding!
        
        let wdgNameDlog = ModifyWindingNameDialog(oldName: oldName)
        
        if wdgNameDlog.runModal() == .OK
        {
            let newTransformer = txfo.Copy()
            
            // This is kind of ugly, but we identify the winding in the copy by comparing the ID's of each winding
            var newWinding:Winding? = nil
            for nextWdg in newTransformer.windings
            {
                if nextWdg.coilID == winding.coilID
                {
                    newWinding = nextWdg
                    break
                }
            }
            
            guard let newWdg = newWinding else
            {
                let alert = NSAlert()
                alert.messageText = "Could not identify the winding to reverse!!"
                alert.informativeText = "This is a very serious problem in that it should be impossible for it to occur."
                alert.alertStyle = .critical
                let _ = alert.runModal()
                return
            }
            
            newWdg.terminal.name = wdgNameDlog.windingName
            
            self.updateCurrentTransformer(newTransformer: newTransformer, runAndersen: false)
        }
    }
    
    
    @IBAction func handleSetTxfoDesc(_ sender: Any) {
        
        guard let txfo = currentTxfo else
        {
            return
        }
        
        let descDlog = TransformerDescriptionDialog(description: txfo.txfoDesc)
        
        if descDlog.runModal() == .OK
        {
            let newTransformer = txfo.Copy()
            
            newTransformer.txfoDesc = descDlog.desc
            
            self.updateCurrentTransformer(newTransformer: newTransformer, runAndersen: false)
        }
    }
    
    
    @IBAction func handleActivateAllWdgTurns(_ sender: Any) {
        
        guard let segPath = self.txfoView.currentSegment else
        {
            return
        }
        
        self.doSetActivation(winding: segPath.segment.inLayer!.parentTerminal.winding!, activate: true)
    }
    
    
    @IBAction func handleDeactivateAllWdgTurns(_ sender: Any) {
        
        guard let segPath = self.txfoView.currentSegment else
        {
            return
        }
        
        self.doSetActivation(winding: segPath.segment.inLayer!.parentTerminal.winding!, activate: false)
    }
    
    func doSetActivation(winding:Winding, activate:Bool)
    {
        guard let txfo = currentTxfo, let segPath = self.txfoView.currentSegment else
        {
            return
        }
        
        let winding = segPath.segment.inLayer!.parentTerminal.winding!
        let totalTerminalTurns = txfo.CurrentCarryingTurns(terminal: winding.terminal.andersenNumber)
        let wdgTurns = winding.CurrentCarryingTurns()
        
        if fabs(totalTerminalTurns - wdgTurns) < 0.5
        {
            let alert = NSAlert()
            alert.messageText = "It is illegal deactivate ALL the turns for any terminal!"
            alert.informativeText = "You may change the ampere-distribution for transformers with 3 or more terminals."
            if txfo.AvailableTerminals().count < 3
            {
                alert.informativeText = ""
            }
            alert.alertStyle = .critical
            let _ = alert.runModal()
            return
        }
        
        let newTransformer = txfo.Copy()
        
        // This is kind of ugly, but we identify the winding in the copy by comparing the ID's of each winding
        var newWinding:Winding? = nil
        for nextWdg in newTransformer.windings
        {
            if nextWdg.coilID == winding.coilID
            {
                newWinding = nextWdg
                break
            }
        }
        
        guard let newWdg = newWinding else
        {
            let alert = NSAlert()
            alert.messageText = "Could not identify the winding to reverse!!"
            alert.informativeText = "This is a very serious problem in that it should be impossible for it to occur."
            alert.alertStyle = .critical
            let _ = alert.runModal()
            return
        }
        
        newWdg.SetTurnsActivation(activate: activate)
        
        self.updateCurrentTransformer(newTransformer: newTransformer)
    }
    
    
    @IBAction func handleToggleSegmentActivation(_ sender: Any) {
        
        guard let segPath = self.txfoView.currentSegment else
        {
            return
        }
        
        let newTitle = segPath.segment.IsActive() ? "Activate Segment" : "Deactivate Segment"
        
        self.doToggleSegmentActivation(segment: segPath.segment)
        
        self.toggleSegmentActivationMenuItem.title = newTitle
        
    }
    
    func doToggleSegmentActivation(segment:Segment)
    {
        guard let txfo = currentTxfo else
        {
            return
        }
        
        let newTransformer = txfo.Copy()
        
        for nextWinding in newTransformer.windings
        {
            for nextLayer in nextWinding.layers
            {
                for nextSegment in nextLayer.segments
                {
                    if nextSegment == segment
                    {
                        nextSegment.ToggleActivate()
                        self.updateCurrentTransformer(newTransformer: newTransformer)
                        return
                    }
                }
            }
        }
    }
    
    @IBAction func handleReverseCurrentDirection(_ sender: Any) {
        
        guard let segPath = self.txfoView.currentSegment else
        {
            return
        }
        
        if let winding = segPath.segment.inLayer!.parentTerminal.winding
        {
            self.doReverseCurrentDirection(winding: winding)
        }
    }
    
    func doReverseCurrentDirection(winding:Winding) {
        
        // if the calling routine got as far as specifying a winding, it's guaranteed that there's a transformer defined, but who knows what the future holds
        guard let txfo = currentTxfo else
        {
            return
        }
        
        if winding.CurrentCarryingTurns() == 0.0
        {
            let alert = NSAlert()
            alert.messageText = "Cannot reverse the current direction of a winding that has NO active turns!"
            alert.informativeText = "Either activate some turns or select a different winding."
            alert.alertStyle = .informational
            let _ = alert.runModal()
            return
        }
        
        // If the user wants to change the direction of a reference-terminal associated winding, and there are only two terminals, that's okay, but if he wants to change the direction of any other winding, we only allow it if it does not reverse the direction of the ENTIRE Andersen-terminal
        if self.preferences.generalPrefs.forceAmpTurnBalance
        {
            if let refTerm = txfo.vpnRefTerm
            {
                if winding.terminal.andersenNumber != refTerm && txfo.AvailableTerminals().count == 2
                {
                    // let totalTerminalTurns = txfo.CurrentCarryingTurns(terminal: winding.terminal.andersenNumber)
                    // let wdgTurns = winding.CurrentCarryingTurns()
                    
                    // if wdgTurns / totalTerminalTurns >= 0.5
                    if txfo.FractionOfTerminal(terminal: winding.terminal, andersenNum: winding.terminal.andersenNumber) >= 0.5
                    {
                        let alert = NSAlert()
                        alert.messageText = "You may not change the direction of the main winding for a terminal unless it is the reference terminal."
                        alert.alertStyle = .informational
                        let _ = alert.runModal()
                        return
                    }
                }
            }
        }
        
        let newTransformer = txfo.Copy()
        
        // This is kind of ugly, but we identify the winding in the copy by comparing the ID's of each winding
        var newWinding:Winding? = nil
        for nextWdg in newTransformer.windings
        {
            if nextWdg.coilID == winding.coilID
            {
                newWinding = nextWdg
                break
            }
        }
        
        guard let newWdg = newWinding else
        {
            let alert = NSAlert()
            alert.messageText = "Could not identify the winding to reverse!!"
            alert.informativeText = "This is a very serious problem in that it should be impossible for it to occur."
            alert.alertStyle = .critical
            let _ = alert.runModal()
            return
        }
        
        newWdg.terminal.currentDirection = -newWdg.terminal.currentDirection
        self.updateCurrentTransformer(newTransformer: newTransformer)
    }
    
    
    @IBAction func handleSetRefTermVoltage(_ sender: Any) {
        
        let refTerm = self.currentTxfo!.vpnRefTerm!
        
        do
        {
            let voltage = try self.currentTxfo!.TerminalLineVoltage(terminal: refTerm)
            
            let modRefVoltageDlog = ModifyReferenceVoltageDialog(currentVolts: voltage)
            
            if modRefVoltageDlog.runModal() == .OK
            {
                self.doSetRefTermVoltage(newVoltage: modRefVoltageDlog.voltage)
            }
        }
        catch
        {
            let alert = NSAlert(error: error)
            let _ = alert.runModal()
            return
        }
    }
    
    func doSetRefTermVoltage(newVoltage:Double)
    {
        // This function is complicated by the fact that a "terminal" can be made up of one or more "Terminals" (ie: Windings)
        
        guard let currTxfo = self.currentTxfo else
        {
            DLog("Current transformer is not defined")
            return
        }
        
        guard let refTerm = currTxfo.vpnRefTerm else
        {
            DLog("No reference terminal defined")
            return
        }
        
        let totalEffectiveTurns = currTxfo.CurrentCarryingTurns(terminal: refTerm)
        
        do
        {
            let newTransformer = currTxfo.Copy()
            
            let refWdgs = try newTransformer.WindingsFromAndersenNumber(termNum: refTerm)
            
            for nextWdg in refWdgs
            {
                let wdgTurns = nextWdg.CurrentCarryingTurns()
                
                nextWdg.terminal.SetVoltsAndAmps(legVolts: (newVoltage / nextWdg.terminal.connectionFactor) * wdgTurns / totalEffectiveTurns)
                
                // nextWdg.terminal.nominalLineVolts = newVoltage * wdgTurns / totalEffectiveTurns
            }
            
            self.updateCurrentTransformer(newTransformer: newTransformer)
        }
        catch
        {
            let alert = NSAlert(error: error)
            let _ = alert.runModal()
            return
        }
    }
    
    
    @IBAction func handleSetAmpTurnDistribution(_ sender: Any) {
        
        guard let currTxfo = self.currentTxfo else
        {
            DLog("Current transformer is not defined")
            return
        }
        
        do
        {
            let newTransformer = currTxfo.Copy()
            let _ = try newTransformer.AmpTurns(forceBalance: self.preferences.generalPrefs.forceAmpTurnBalance, showDistributionDialog: true)
            
            self.updateCurrentTransformer(newTransformer: newTransformer)
        }
        catch
        {
            let alert = NSAlert(error: error)
            let _ = alert.runModal()
            return
        }
    }
    
    
    @IBAction func handleSetReferenceMVA(_ sender: Any) {
        
        let refTerm = self.currentTxfo!.vpnRefTerm!
        
        do
        {
            let va = try self.currentTxfo!.TotalVA(terminal: refTerm)
            let currentMVA = va / 1.0E6
            
            let mvaDlog = ModifyReferenceMvaDialog(currentMVA: currentMVA)
            
            if mvaDlog.runModal() == .OK
            {
                doSetReferenceMVA(newMVA: mvaDlog.MVA)
            }
        }
        catch
        {
            let alert = NSAlert(error: error)
            let _ = alert.runModal()
            return
        }
        /*
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
         */
        
        
    }
    
    func doSetReferenceMVA(newMVA:Double)
    {
        guard let currTxfo = self.currentTxfo else
        {
            DLog("Current transformer is not defined")
            return
        }
        
        guard currTxfo.CurrentCarryingTurns(terminal: currTxfo.vpnRefTerm!) != 0.0 else
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
            
            let refWdgs = try txfo.WindingsFromAndersenNumber(termNum: txfo.vpnRefTerm!)
            
            let phaseFactor = refWdgs[0].terminal.phaseFactor
            
            var legVolts = txfo.CurrentCarryingTurns(terminal: txfo.vpnRefTerm!) * vpn
            
            var autoFactor = 1.0
            
            let terms = try txfo.TerminalsFromAndersenNumber(termNum: txfo.vpnRefTerm!)
            
            if terms[0].connection == .auto_series
            {
                for nextTerm in txfo.wdgTerminals
                {
                    if let cTerm = nextTerm
                    {
                        if cTerm.connection == .auto_common
                        {
                            var commonTurns = txfo.CurrentCarryingTurns(terminal: cTerm.andersenNumber)
                            if commonTurns == 0
                            {
                                commonTurns = txfo.NoLoadTurns(terminal: cTerm.andersenNumber)
                            }
                            
                            var seriesTurns = txfo.CurrentCarryingTurns(terminal: txfo.vpnRefTerm!)
                            if seriesTurns == 0
                            {
                                seriesTurns = txfo.NoLoadTurns(terminal: txfo.vpnRefTerm!)
                            }
                            
                            autoFactor = (seriesTurns + commonTurns) / seriesTurns
                        }
                    }
                }
            }
            else if terms[0].connection == .auto_common
            {
                for nextTerm in txfo.wdgTerminals
                {
                    if let sTerm = nextTerm
                    {
                        if sTerm.connection == .auto_series
                        {
                            var seriesTurns = txfo.CurrentCarryingTurns(terminal: sTerm.andersenNumber)
                            if seriesTurns == 0
                            {
                                seriesTurns = txfo.NoLoadTurns(terminal: sTerm.andersenNumber)
                            }
                            
                            var commonTurns = txfo.CurrentCarryingTurns(terminal: txfo.vpnRefTerm!)
                            if commonTurns == 0
                            {
                                commonTurns = txfo.NoLoadTurns(terminal: txfo.vpnRefTerm!)
                            }
                            
                            autoFactor = (seriesTurns + commonTurns) / seriesTurns
                        }
                    }
                }
            }
            
            
            var legVA = newMVA * 1.0E6 / phaseFactor / autoFactor
            
            if legVolts == 0.0
            {
                legVolts = txfo.NoLoadTurns(terminal: txfo.vpnRefTerm!) * vpn
                legVA = 0.0
            }
            
            let legAmps = legVA / legVolts
            
            for nextWdg in refWdgs
            {
                let voltage = nextWdg.CurrentCarryingTurns() * vpn
                
                nextWdg.terminal.SetVoltsAndAmps(legVolts: voltage, amps: legAmps)
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
    
    
    @IBAction func handleSetAmpTurnReferenceTerminal(_ sender: Any) {
        
        let refnumDlog = ModifyReferenceTerminalDialog(oldTerminal: self.currentTxfo!.niRefTerm, type: .ni)
        
        if refnumDlog.runModal() == .OK
        {
            self.doSetAmpTurnReferenceTerminal(refTerm: refnumDlog.currentRefIndex + 1)
        }
    }
    
    func doSetAmpTurnReferenceTerminal(refTerm:Int)
    {
        
    }
    
    @IBAction func handleSetVpnReferenceTerminal(_ sender: Any) {
        
        let refnumDlog = ModifyReferenceTerminalDialog(oldTerminal: self.currentTxfo!.vpnRefTerm, type: .vpn)
        
        var oldRefNumIndex = -1
        if let refNum = self.currentTxfo!.vpnRefTerm
        {
            oldRefNumIndex = refNum - 1
        }
        
        if refnumDlog.runModal() == .OK
        {
            if refnumDlog.currentRefIndex != oldRefNumIndex
            {
                let alert = NSAlert()
                alert.messageText = "Changing the reference terminal will cause the transformer to be recreated from scratch, using the current terminal voltages, VAs, etc."
                alert.informativeText = "(You can Undo this operation if necessary)"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Ok")
                alert.addButton(withTitle: "Cancel")
                
                if alert.runModal() == .alertFirstButtonReturn
                {
                    if refnumDlog.currentRefIndex >= 0
                    {
                        self.doSetVpnReferenceTerminal(refTerm: refnumDlog.currentRefIndex + 1)
                    }
                }
            }
        }
    }
    
    func doSetVpnReferenceTerminal(refTerm:Int)
    {
        guard let currTxfo = self.currentTxfo else
        {
            DLog("Current transformer is not defined")
            return
        }
        
        if let oldRefTerm = currTxfo.vpnRefTerm
        {
            if oldRefTerm == refTerm
            {
                // The same reference terminal is being selected, do nothing
                DLog("Attempt to set the same reference terminal - ignoring")
                return
            }
        }
        
        let newTransformer = currTxfo.Copy()
        newTransformer.vpnRefTerm = refTerm
        self.updateCurrentTransformer(newTransformer: newTransformer, reinitialize: true)
    }
    
    // MARK: Transformer SC Information
    func GetSCdataForSegment(andersenSegNum:Int) -> ImpedanceAndScData.SegmentScData?
    {
        guard let currTxfo = self.currentTxfo, let results = currTxfo.scResults else
        {
            DLog("Current transformer is not defined")
            return nil
        }
        
        return results.SegmentData(andersenSegNum: andersenSegNum)
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
    // MARK: Contextual Menus
    
    
    // MARK: Zoom functions
    @IBAction func handleZoomIn(_ sender: Any) {
        
        self.txfoView.handleZoomIn()
    }
    
    @IBAction func handleZoomOut(_ sender: Any) {
        
        self.txfoView.handleZoomOut()
    }
    
    @IBAction func handleZoomAll(_ sender: Any) {
        
        guard let txfo = self.currentTxfo else
        {
            return
        }
        
        self.txfoView.handleZoomAll(coreRadius: CGFloat(txfo.core.diameter / 2.0), windowHt: CGFloat(txfo.core.windHt), tankWallR: CGFloat(txfo.DistanceFromCoreCenterToTankWall()))
    }
    
    @IBAction func handleZoomRect(_ sender: Any) {
        
        guard self.currentTxfo != nil else
        {
            return
        }
        
        self.txfoView.mode = .zoomRect
        
    }
    
    
    // MARK: View functions
    // This function does the following things:
    // 1) Sets the bounds of the transformer view to the window of the transformer (does a "zoom all" using the current transformer core)
    // 2) Calls updateViews() to draw the coil segments
    func initializeViews()
    {
        self.handleZoomAll(self)
        
        self.termsView.InitializeFields(appController: self)
        
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
        
        self.txfoView.removeAllToolTips()
        
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
                    var newSegPath = SegmentPath(segment: nextSegment, segmentColor: pathColor)
                    
                    newSegPath.toolTipTag = self.txfoView.addToolTip(newSegPath.rect, owner: self.txfoView as Any, userData: nil)
                    // DLog("New ToolTag: \(newSegPath.toolTipTag)")
                    
                    // update the currently-selected segment in the TransformerView
                    if let currentSegment = self.txfoView.currentSegment
                    {
                        if currentSegment.segment.serialNumber == nextSegment.serialNumber
                        {
                            self.txfoView.currentSegment = newSegPath
                        }
                    }
                    
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
                if let refTerm = txfo.vpnRefTerm
                {
                    if refTerm == nextTerm
                    {
                        isRef = true
                    }
                }
                
                let termLineVolts = try txfo.TerminalLineVoltage(terminal: nextTerm)
                let termVA = try round(txfo.TotalVA(terminal: nextTerm) / 1.0E5) * 1.0E5
                
                self.termsView.SetTermData(termNum: nextTerm, name: terminals[0].name, displayVolts: termLineVolts, VA: termVA, connection: terminals[0].connection, isReference: isRef)
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
            self.dataView.SetVpN(newVpN: vpn, refTerm: txfo.vpnRefTerm)
            
            // amp-turns are guaranteed to be 0 if forceAmpTurnsBalance is true
            let newNI = self.preferences.generalPrefs.forceAmpTurnBalance ? 0.0 : try txfo.AmpTurns(forceBalance: self.preferences.generalPrefs.forceAmpTurnBalance, showDistributionDialog: false)
            self.dataView.SetAmpereTurns(newNI: newNI, refTerm: txfo.niRefTerm)
            
            if self.preferences.generalPrefs.keepImpedanceUpdated && txfo.scResults != nil
            {
                self.dataView.SetImpedance(newImpPU: txfo.scResults!.puImpedance, baseMVA: txfo.scResults!.baseMVA)
            }
            else
            {
                self.dataView.SetImpedance(newImpPU: nil, baseMVA: nil)
            }
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
        else if menuItem == self.closeTransformerMenuItem || menuItem == self.zoomInMenuItem || menuItem == self.zoomOutMenuItem || menuItem == self.zoomAllMenuItem || menuItem == self.zoomRectMenuItem || menuItem == self.setRefTerminalMenuItem || menuItem == self.setTxfoDescriptionMenuItem
        {
            return self.currentTxfo != nil
        }
        else if menuItem == self.setMVAMenuItem || menuItem == self.setRefVoltageMenuItem
        {
            return self.currentTxfo != nil && self.currentTxfo!.vpnRefTerm != nil && self.currentTxfo!.CurrentCarryingTurns(terminal: self.currentTxfo!.vpnRefTerm!) != 0.0
        }
        else if menuItem == self.setNIdistMenuItem
        {
            return self.currentTxfo != nil && self.currentTxfo!.vpnRefTerm != nil && self.currentTxfo!.AvailableTerminals().count >= 3
        }
        else if menuItem == self.reverseCurrentMenuItem
        {
            guard let txfo = self.currentTxfo, let currSeg = self.txfoView.currentSegment else
            {
                DLog("Returning false")
                return false
            }
            
            let termNum = currSeg.segment.inLayer!.parentTerminal.andersenNumber
            
            if let refTerm = txfo.niRefTerm
            {
                if refTerm != termNum
                {
                    // DLog("Fraction: \(txfo.FractionOfTerminal(terminal: terminal, andersenNum: termNum))")
                    if txfo.FractionOfTerminal(terminal: currSeg.segment.inLayer!.parentTerminal, andersenNum: termNum) >= 0.5
                    {
                        // DLog("Returning false because this would cause a reversal of a non-ref terminal")
                        return false
                    }
                }
            }
            
            return currSeg.segment.inLayer!.parentTerminal.winding!.CurrentCarryingTurns() != 0.0
        }
        else if menuItem == self.activateAllWdgTurnsMenuItem || menuItem == self.changeWdgNameMenuItem
        {
            guard  self.currentTxfo != nil, self.txfoView.currentSegment != nil else
            {
                return false
            }
        }
        else if menuItem == self.toggleSegmentActivationMenuItem
        {
            guard let txfo = currentTxfo, let segPath = self.txfoView.currentSegment else
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
        else if menuItem == self.deactivateAllWdgTurnsMenuItem
        {
            guard let txfo = currentTxfo, let segPath = self.txfoView.currentSegment else
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
    
    /// Function to update the activation toggle menu item title. The calling function should pass the current state of isActive.
    func UpdateToggleActivationMenu(deactivate:Bool)
    {
        if deactivate
        {
            self.toggleSegmentActivationMenuItem.title = "Deactivate segment"
        }
        else
        {
            self.toggleSegmentActivationMenuItem.title = "Activate segment"
        }
    }
    
    // MARK: Preference functions
    @IBAction func handleGlobalPreferences(_ sender: Any) {
        
        let alert = NSAlert()
        alert.messageText = "Note: Making changes to the preferences will reset the model to the initially loaded model (but using the new preferences)."
        alert.alertStyle = .informational
        let _ = alert.runModal()
        
        let prefDlog = PreferencesDialog(scopeLabel: "When loading an Excel-generated design file:", modelRadialDucts: self.preferences.wdgPrefs.modelRadialDucts, modelZeroTerms: self.preferences.wdgPrefs.model0Terminals, modelLayerTaps: self.preferences.wdgPrefs.modelInternalLayerTaps, upperLowerGapsAreSymmetric: self.preferences.wdgPrefs.upperLowerAxialGapsAreSymmetrical, multiStartElecHtIsToCenters: self.preferences.wdgPrefs.multiStartElecHtIsToCenter, defaultRefTerm2: self.preferences.generalPrefs.defaultRefTerm2, useAndersenFLD12: self.preferences.generalPrefs.useAndersenFLD12, forceAmpTurnBalance: self.preferences.generalPrefs.forceAmpTurnBalance, keepImpedancesUpdated: self.preferences.generalPrefs.keepImpedanceUpdated)
        
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
        
        if prefDlog.keepImpedancesUpdated != self.preferences.generalPrefs.keepImpedanceUpdated
        {
            self.preferences.generalPrefs.keepImpedanceUpdated = !self.preferences.generalPrefs.keepImpedanceUpdated
            UserDefaults.standard.set(self.preferences.generalPrefs.keepImpedanceUpdated, forKey: KEEP_IMPEDANCE_AND_FORCES_UPDATED_KEY)
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
        
        guard let txfo = currentTxfo else
        {
            return
        }
        
        if txfo.txfoDesc == ""
        {
            self.handleSetTxfoDesc(self)
        }
        
        let descString = txfo.txfoDesc == "" ? " " : String(txfo.txfoDesc.prefix(80))
        
        do
        {
            let txfoDetails = try txfo.QuickFLD12transformer()
            
            txfoDetails.identification = descString
            
            let fileString = PCH_FLD12_Library.createFLD12InputFile(withTxfo: txfoDetails)
            
            let savePanel = NSSavePanel()
            savePanel.title = "Andersen FLD12 file"
            savePanel.message = "Save Andersen FLD12 Input file"
            savePanel.allowedFileTypes = ["inp"]
            savePanel.allowsOtherFileTypes = false
            
            if savePanel.runModal() == .OK
            {
                if let fileUrl = savePanel.url
                {
                    try fileString.write(to: fileUrl, atomically: false, encoding: .utf8)
                }
            }
        }
        catch
        {
            // An error occurred
            let alert = NSAlert(error: error)
            let _ = alert.runModal()
            return
        }
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
                    newTxfo.vpnRefTerm = 2
                    
                    if newTxfo.niRefTerm == nil
                    {
                        newTxfo.niRefTerm = 2
                    }
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
