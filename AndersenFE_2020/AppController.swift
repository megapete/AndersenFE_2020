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

class AppController: NSObject, NSMenuItemValidation, NSWindowDelegate {
    
    // MARK: Transformer Properties
    var currentTxfo:Transformer? = nil
    var lastOpenedTxfoFile:URL? = nil
    var currentTxfoIsDirty:Bool = false
    var lastSavedTxfoFile:URL? = nil
    
    // MARK: Undo & Redo
    var undoStack:[PCH_AFE2020_Save_Struct] = []
    var redoStack:[PCH_AFE2020_Save_Struct] = []
    
    // Output array
    var outputDataArray:[OutputData] = []
    var outputDataIsDirty:Bool = false
    
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
    
    @IBOutlet weak var setPeakFactorMenuItem: NSMenuItem!
    @IBOutlet weak var setImpForForcesMenuItem: NSMenuItem!
    @IBOutlet weak var setSystemGVAMenuItem: NSMenuItem!
    
    
    @IBOutlet weak var TxfoContextMenu:NSMenu!
    
    // Winding Menu
    @IBOutlet weak var reverseCurrentMenuItem: NSMenuItem!
    @IBOutlet weak var moveWdgRadiallyMenuItem: NSMenuItem!
    @IBOutlet weak var changeWdgNameMenuItem: NSMenuItem!
    @IBOutlet weak var activateAllWdgTurnsMenuItem: NSMenuItem!
    @IBOutlet weak var deactivateAllWdgTurnsMenuItem: NSMenuItem!
    @IBOutlet weak var toggleSegmentActivationMenuItem: NSMenuItem!
    @IBOutlet weak var splitSegmentMenuItem: NSMenuItem!
    
    
    // View Menu
    @IBOutlet weak var showFld8MenuItem: NSMenuItem!
    @IBOutlet weak var showFld12MenuItem: NSMenuItem!
    @IBOutlet weak var showFluxLinesMenuItem: NSMenuItem!
    @IBOutlet weak var zoomInMenuItem: NSMenuItem!
    @IBOutlet weak var zoomOutMenuItem: NSMenuItem!
    @IBOutlet weak var zoomRectMenuItem: NSMenuItem!
    @IBOutlet weak var zoomAllMenuItem: NSMenuItem!
    
    
    
    // Output Menu
    @IBOutlet weak var saveAndOutputMenuItem: NSMenuItem!
    @IBOutlet weak var addTxfoOutputMenuItem: NSMenuItem!
    @IBOutlet weak var editOutputListMenuItem: NSMenuItem!
    @IBOutlet weak var saveOutputDataMenuItem: NSMenuItem!
    
    
    // MARK: Preferences
    var preferences = PCH_AFE2020_Prefs(wdgPrefs: PCH_AFE2020_Prefs.WindingPrefs(modelRadialDucts: false, model0Terminals: false, modelInternalLayerTaps: false, upperLowerAxialGapsAreSymmetrical: true, multiStartElecHtIsToCenter: true), generalPrefs: PCH_AFE2020_Prefs.GeneralPrefs(defaultRefTerm2: true, useAndersenFLD12: true, forceAmpTurnBalance: true, keepImpedanceUpdated: true))
    
    // MARK: UI elements
    @IBOutlet weak var mainWindow: NSWindow!
    @IBOutlet weak var txfoView: TransformerView!
    @IBOutlet weak var termsView: TerminalsView!
    @IBOutlet weak var dataView: DataView!
    
    var fluxLinesAreHidden = true
    
    
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
    
    func InitializeAppController()
    {
        self.fluxLinesAreHidden = true
        self.outputDataArray = []
        self.undoStack = []
        self.redoStack = []
    }
    
    // MARK: Model Modification & Update functions
    func updateCurrentTransformer(newTransformer:Transformer, reinitialize:Bool = false, runAndersen:Bool = true) {
                
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
                
        self.currentTxfo = newTransformer
        self.currentTxfoIsDirty = true
        
        if reinitialize
        {
            self.InitializeAppController()
            self.initializeViews()
        }
        else
        {
            self.updateViews()
        }
    }
    
    @IBAction func handleSetImpedanceForSC(_ sender: Any) {
        
        guard let txfo = self.currentTxfo else
        {
            return
        }
        
        let initValue = txfo.puForceImpedance
        
        let formatter = NumberFormatter()
        formatter.minimum = 0.0
        formatter.maximum = 100.0
        formatter.minimumFractionDigits = 2
        
        let setImpDlog = GetNumberDialog(descriptiveText: "Impedance to use:", unitsText: "%", noteText: "(Enter 0 to use txfo impedance)", windowTitle: "Impedance For Force Calcs", initialValue: initValue, fieldFormatter: formatter)
        
        if setImpDlog.runModal() == .OK
        {
            self.doSetImpedanceForSc(impedance: setImpDlog.numberValue / 100.0)
        }
        
    }
    
    func doSetImpedanceForSc(impedance:Double)
    {
        guard let txfo = self.currentTxfo else
        {
            return
        }
        
        let newTransformer = txfo.Copy()
        
        newTransformer.puForceImpedance = impedance
        
        self.updateCurrentTransformer(newTransformer: newTransformer, runAndersen: true)
    }
    
    @IBAction func handleSetSystemGVA(_ sender: Any) {
        
        guard let txfo = self.currentTxfo else
        {
            return
        }
        
        let initValue = txfo.systemGVA
        
        let formatter = NumberFormatter()
        formatter.minimum = 0.0
        formatter.maximum = 1000.0
        formatter.minimumFractionDigits = 2
        
        let setSysGVADlog = GetNumberDialog(descriptiveText: "System Strength:", unitsText: "GVA", noteText: "(Enter 0 to use infinity)", windowTitle: "System Short Circuit Strength", initialValue: initValue, fieldFormatter: formatter)
        
        if setSysGVADlog.runModal() == .OK
        {
            self.doSetSystemGVA(gva: setSysGVADlog.numberValue)
        }
    }
    
    
    func doSetSystemGVA(gva:Double)
    {
        guard let txfo = self.currentTxfo else
        {
            return
        }
        
        let newTransformer = txfo.Copy()
        
        newTransformer.systemGVA = gva
        
        self.updateCurrentTransformer(newTransformer: newTransformer, runAndersen: true)
    }
    
    
    @IBAction func handleSetPeakFactor(_ sender: Any) {
        
        guard let txfo = self.currentTxfo else
        {
            return
        }
        
        let pkFact = txfo.scFactor
        
        let pkDlog = PeakFactorDialog(pkFactor: pkFact)
        
        if pkDlog.runModal() == .OK
        {
            self.doSetPeakFactor(newPkFactor: pkDlog.pkFactor)
        }
    }
    
    func doSetPeakFactor(newPkFactor:Double)
    {
        guard let txfo = self.currentTxfo else
        {
            return
        }
        
        let newTransformer = txfo.Copy()
        
        newTransformer.scFactor = newPkFactor
        
        self.updateCurrentTransformer(newTransformer: newTransformer, runAndersen: true)
    }
    
    func askToSaveOutputData() {
        
        if self.outputDataArray.isEmpty
        {
            return
        }
        
        let alert = NSAlert()
        alert.messageText = "Do you wish to save the output data for this session?"
        
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Don't Save")
        
        if alert.runModal() == .alertFirstButtonReturn
        {
            self.handleSaveOutputData(self)
        }
        
        self.outputDataIsDirty = false
    }
    
    
    @IBAction func handleAddTxfoOutput(_ sender: Any) {
        
        guard let txfo = self.currentTxfo, txfo.scResults != nil else
        {
            return
        }
        
        var description = txfo.txfoDesc
        if description.isEmpty
        {
            let descDlog = TransformerDescriptionDialog(description: "")
            
            if descDlog.runModal() == .OK
            {
                description = descDlog.desc
            }
        }
        
        if let outputData = OutputData(txfo: txfo, outputDesc: description)
        {
            self.outputDataArray.append(outputData)
            self.outputDataIsDirty = true
        }
        else
        {
            DLog("Could not produce output data!")
        }
    }
    
    @IBAction func handleEditOutputList(_ sender: Any) {
        
        guard self.outputDataArray.count > 0 else
        {
            return
        }
        
        var outputStrings:[String] = []
        for nextData in self.outputDataArray
        {
            outputStrings.append(nextData.description)
        }
        
        let editDlog = EditOutputDataDialog(outputStrings: outputStrings)
        
        if editDlog.runModal() == .OK
        {
            if editDlog.removedRows.count > 0
            {
                // make sure the array is in reverse order
                let deadRows = editDlog.removedRows.sorted(by: {$0 > $1})
                for nextIndex in deadRows
                {
                    self.outputDataArray.remove(at: nextIndex)
                }
            }
            
            self.outputDataIsDirty = true
        }
    }
    
    @IBAction func handleMoveWindingAxially(_ sender: Any) {
        
        guard self.currentTxfo != nil, let segPath = self.txfoView.currentSegment else
        {
            return
        }
        
        let winding = segPath.segment.inLayer!.parentTerminal.winding!
        
        let moveDlog = MoveWindingDialog(direction: .axially)
        
        if moveDlog.runModal() == .OK
        {
            self.doMoveWindingAxially(winding: winding, deltaZ: moveDlog.delta)
        }
    }
    
    func doMoveWindingAxially(winding:Winding, deltaZ:Double)
    {
        guard let txfo = currentTxfo else
        {
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
        
        newWdg.OffsetWindingAxially(deltaZ: deltaZ)
        
        self.updateCurrentTransformer(newTransformer: newTransformer, runAndersen: true)
    }
    
    @IBAction func handleMoveWindingRadially(_ sender: Any) {
        
        guard self.currentTxfo != nil, let segPath = self.txfoView.currentSegment else
        {
            return
        }
        
        let winding = segPath.segment.inLayer!.parentTerminal.winding!
        
        let moveDlog = MoveWindingDialog(direction: .radially)
        
        if moveDlog.runModal() == .OK
        {
            self.doMoveWindingRadially(winding: winding, deltaR: moveDlog.delta)
        }
    }
    
    func doMoveWindingRadially(winding:Winding, deltaR:Double)
    {
        guard let txfo = currentTxfo else
        {
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
        
        newTransformer.OffsetWindingRadially(winding: newWdg, deltaR: deltaR)
        
        self.updateCurrentTransformer(newTransformer: newTransformer, runAndersen: true)
    }
    
    
    @IBAction func handleSplitSegment(_ sender: Any) {
        
        guard currentTxfo != nil, let segPath = self.txfoView.currentSegment else
        {
            return
        }
        
        let splitDlog = SplitSegmentDialog()
        
        if splitDlog.runModal() == .OK
        {
            if splitDlog.type == .multiple
            {
                let numSegs = Int(splitDlog.number)
                self.doSplitSegment(segment: segPath.segment, splitType: .multiple, numSegs: numSegs)
            }
            else
            {
                self.doSplitSegment(segment: segPath.segment, splitType: .double, numSegs: 2, percentageLower: splitDlog.number)
            }
        }
    }
    
    func doSplitSegment(segment:Segment, splitType:SplitSegmentDialog.SplitType, numSegs:Int, percentageLower:Double = 0.0)
    {
        guard let txfo = currentTxfo, let oldLayer = segment.inLayer else
        {
            return
        }
        
        let newTransformer = txfo.Copy()
        
        var newLayer:Layer? = nil
        for nextWdg in newTransformer.windings
        {
            for nextLayer in nextWdg.layers
            {
                if nextLayer.innerRadius == oldLayer.innerRadius
                {
                    newLayer = nextLayer
                    break
                }
            }
            
            if newLayer != nil
            {
                break
            }
        }
        
        guard let layer = newLayer else
        {
            return
        }
        
        if splitType == .multiple
        {
            layer.SplitSegment(segmentSerialNumber: segment.serialNumber, numSegments: numSegs)
        }
        else
        {
            if percentageLower < 1.0 || percentageLower > 99.0
            {
                return
            }
            
            layer.SplitSegment(segmentSerialNumber: segment.serialNumber, puForLowerSegment: percentageLower / 100.0)
        }
        
        self.updateCurrentTransformer(newTransformer: newTransformer, runAndersen: true)
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
        
        let refTerm = self.currentTxfo!.niRefTerm!
        
        do
        {
            let va = try self.currentTxfo!.TotalVA(terminal: refTerm)
            let currentMVA = va / 1.0E6
            
            let mvaDlog = ModifyReferenceMvaDialog(currentMVA: currentMVA)
            
            if mvaDlog.runModal() == .OK
            {
                doSetReferenceMVA(oldMVA: currentMVA, newMVA: mvaDlog.MVA)
            }
        }
        catch
        {
            let alert = NSAlert(error: error)
            let _ = alert.runModal()
            return
        }
    }
    
    func doSetReferenceMVA(oldMVA:Double, newMVA:Double)
    {
        guard let currTxfo = self.currentTxfo else
        {
            DLog("Current transformer is not defined")
            return
        }
        
        guard let refTerm = currTxfo.niRefTerm else
        {
            return
        }
        
        guard currTxfo.CurrentCarryingTurns(terminal: refTerm) != 0.0 else
        {
            let alert = NSAlert()
            alert.messageText = "Reference Terminal has no effective turns!"
            alert.informativeText = "Add some turns to the reference terminal before trying to change the MVA of the transformer"
            let _ = alert.runModal()
            return
        }
        
        let newTxfo = currTxfo.Copy()
        
        for nextMaybeTerm in newTxfo.wdgTerminals
        {
            if let nextTerm = nextMaybeTerm, nextTerm.andersenNumber == refTerm
            {
                let oldAmps = nextTerm.nominalAmps
                let newAmps = oldAmps * newMVA / oldMVA
                
                nextTerm.SetVoltsAndAmps(amps: newAmps)
            }
        }
            
        self.updateCurrentTransformer(newTransformer: newTxfo)
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
        guard let currTxfo = self.currentTxfo else
        {
            DLog("Current transformer is not defined")
            return
        }
        
        if let oldRefTerm = currTxfo.niRefTerm
        {
            if oldRefTerm == refTerm
            {
                // The same reference terminal is being selected, do nothing
                DLog("Attempt to set the same reference terminal - ignoring")
                return
            }
        }
        
        let newTransformer = currTxfo.Copy()
        newTransformer.niRefTerm = refTerm
        self.updateCurrentTransformer(newTransformer: newTransformer, reinitialize: true)
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
    
    // MARK: Contextual Menus
    
    // MARK: Text File Viewer Functions
    
    @IBAction func handleShowFLD8File(_ sender: Any) {
        
        guard let currTxfo = self.currentTxfo, let results = currTxfo.scResults else
        {
            DLog("FLD8 file not available")
            return
        }
        
        let _ = TextDisplayWindow(windowTitle: "FLD8 File", stringToDisplay: results.fld8File)
        
    }
    
    @IBAction func handleShowFLD12File(_ sender: Any) {
        
        guard let currTxfo = self.currentTxfo, currTxfo.scResults != nil else
        {
            DLog("FLD12 output file not available")
            return
        }
        
        do
        {
            let currDetails = try currTxfo.QuickFLD12transformer()
            
            let fld12File = PCH_FLD12_Library.runFLD12withTxfo(currDetails, outputType: .metric, fluxLineString: nil, fld8String: nil)
            
            let _ = TextDisplayWindow(windowTitle: "FLD12 Output File", stringToDisplay: fld12File)
        }
        catch
        {
            let alert = NSAlert(error: error)
            let _ = alert.runModal()
            return
        }
    }
    
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
    // 1) Shows the main window (if its hidden)
    // 2) Sets the bounds of the transformer view to the window of the transformer (does a "zoom all" using the current transformer core)
    // 3) Calls updateViews() to draw the coil segments
    func initializeViews()
    {
        self.mainWindow.makeKeyAndOrderFront(self)
        
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
        
        if !self.fluxLinesAreHidden
        {
            self.doShowHideFluxLines(hide: false)
        }
        else
        {
            self.txfoView.needsDisplay = true
        }
        
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
                let termVA = try round(txfo.TotalVA(terminal: nextTerm) / 1.0E3) * 1.0E3
                
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
        
        self.termsView.UpdateScData()
        
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
       
        self.dataView.ResetWarnings()
        
        let warnings = txfo.CheckForWarnings()
        
        for nextWarning in warnings
        {
            self.dataView.AddWarning(warning: nextWarning)
        }
        
        self.dataView.UpdateWarningField()
    }
    
    @IBAction func handleBringToFront(_ sender: Any) {
        
        self.mainWindow.makeKeyAndOrderFront(self)
    }
    
    
    @IBAction func handleShowFluxLines(_ sender: Any) {
        
        self.doShowHideFluxLines(hide: !self.fluxLinesAreHidden)
    }
    
    func doShowHideFluxLines(hide:Bool)
    {
        if hide
        {
            DLog("Hiding flux lines")
            self.showFluxLinesMenuItem.title = "Show Flux Lines"
            self.fluxLinesAreHidden = true
            self.txfoView.fluxlines = []
        }
        else
        {
            guard let currTxfo = self.currentTxfo, let results = currTxfo.scResults else
            {
                DLog("Andersen results not available")
                return
            }
            
            var fluxLineArray = results.fluxLines
            
            guard !fluxLineArray.isEmpty else
            {
                DLog("Flux lines not available")
                return
            }
            
            // for now, we don't use the max dims for anything
            let _ = fluxLineArray.removeFirst()
            
            var pathArray:[NSBezierPath] = []
            for nextPath in fluxLineArray
            {
                var gotFirst = false
                let newFluxLine = NSBezierPath()
                for nextPoint in nextPath
                {
                    if !gotFirst
                    {
                        newFluxLine.move(to: nextPoint)
                        gotFirst = true
                    }
                    else
                    {
                        newFluxLine.line(to: nextPoint)
                    }
                }
                
                pathArray.append(newFluxLine)
            }
            
            self.showFluxLinesMenuItem.title = "Hide Flux Lines"
            self.fluxLinesAreHidden = false
            
            self.txfoView.fluxlines = pathArray
        }
        
        self.txfoView.needsDisplay = true
    }
    
    // MARK: Menu validation
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        
        if menuItem == self.saveMenuItem
        {
            return self.lastOpenedTxfoFile != nil && self.currentTxfoIsDirty
        }
        else if menuItem == self.closeTransformerMenuItem || menuItem == self.zoomInMenuItem || menuItem == self.zoomOutMenuItem || menuItem == self.zoomAllMenuItem || menuItem == self.zoomRectMenuItem || menuItem == self.setRefTerminalMenuItem || menuItem == self.setTxfoDescriptionMenuItem || menuItem == self.saveAndOutputMenuItem || menuItem == self.setPeakFactorMenuItem || menuItem == self.setSystemGVAMenuItem || menuItem == self.setImpForForcesMenuItem
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
        else if menuItem == self.activateAllWdgTurnsMenuItem || menuItem == self.changeWdgNameMenuItem || menuItem == self.splitSegmentMenuItem || menuItem == self.moveWdgRadiallyMenuItem
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
        else if menuItem == self.showFld8MenuItem
        {
            guard let txfo = currentTxfo, let scData = txfo.scResults, !scData.fld8File.isEmpty else
            {
                return false
            }
        }
        else if menuItem == self.showFld12MenuItem || menuItem == self.showFluxLinesMenuItem || menuItem == self.addTxfoOutputMenuItem
        {
            guard let txfo = currentTxfo, txfo.scResults != nil else
            {
                return false
            }
        }
        else if menuItem == self.saveOutputDataMenuItem || menuItem == self.editOutputListMenuItem
        {
            return !self.outputDataArray.isEmpty
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
    
    @IBAction func handleSaveOutputData(_ sender: Any) {
        
        if self.outputDataArray.isEmpty
        {
            return
        }
        
        let outputData = self.outputDataArray
        
        var outputString = ""
        
        outputString.append("Description,")
        for nextOutData in outputData
        {
            outputString.append(",\(nextOutData.description)")
        }
        outputString.append("\n\n")
        
        
        
        // It is assumed that all of the saved results have the same terminal numbers
        let availableTerms = outputData[0].AvailableTerms()
        
        for nextTermNum in availableTerms
        {
            outputString.append("Terminal #\(nextTermNum),")
            
            for nextOutData in outputData
            {
                if let nextData = nextOutData.DataForTerm(number: nextTermNum)
                {
                    let formattedMVA = String(format: "%0.3f", nextData.mva)
                    let formattedKV = String(format: "%0.3f", nextData.kv)
                    outputString.append(",MVA: \(formattedMVA) kV: \(formattedKV)")
                }
            }
            
            outputString.append("\n\n")
        }
        
        // Show the positive (transformer) sequence impedances (as percentages) for each option
        outputString.append("Transformer Impedance,")
        for nextOutData in outputData
        {
            let nextImp = String(format: "%0.2f%% @ %0.3f MVA", nextOutData.impedance * 100.0, nextOutData.MVA)
            outputString.append(",\(nextImp)")
        }
        outputString.append("\n")
        
        outputString.append("Force Impedance,")
        for nextOutData in outputData
        {
            let nextImp = String(format: "%0.2f%% @ %0.3f MVA", nextOutData.impedanceForForces * 100.0, nextOutData.MVA)
            outputString.append(",\(nextImp)")
        }
        outputString.append("\n")
        
        outputString.append("Peak Factor,")
        for nextOutData in outputData
        {
            let nextPkFactor = String(format: "%0.3f", nextOutData.pkFactor * sqrt(2.0))
            outputString.append(",\(nextPkFactor)")
        }
        outputString.append("\n")
        
        if outputData[0].z0 != nil
        {
            outputString.append("Zero-sequence impedance,")
            for nextOutData in outputData
            {
                let nextImp = String(format: "%0.2f", nextOutData.z0!)
                outputString.append(",\(nextImp) \u{3A9}/ph")
            }
            outputString.append("\n")
        }
        outputString.append("\n")
        
        outputString.append("Upper Thrust,")
        for nextOutData in outputData
        {
            let newtons = String(format: "%0.1f N", nextOutData.upperThrust)
            let pounds = String(format: "%0.1f lbs", nextOutData.upperThrust * lbsPerNewton)
            
            outputString.append(",\(newtons) (\(pounds))")
        }
        outputString.append("\n")
        
        outputString.append("Lower Thrust,")
        for nextOutData in outputData
        {
            let newtons = String(format: "%0.1f N", nextOutData.lowerThrust)
            let pounds = String(format: "%0.1f lbs", nextOutData.lowerThrust * lbsPerNewton)
            
            outputString.append(",\(newtons) (\(pounds))")
        }
        outputString.append("\n\n")
        
        // Show the per-layer data
        outputString.append("LAYER DATA\n")
        
        for layerIndex in 0..<outputData[0].layers.count
        {
            outputString.append("Layer \(layerIndex + 1),")
            
            outputString.append("Winding:")
            for nextOutData in outputData
            {
                outputString.append(",\(nextOutData.layers[layerIndex].windingDesc)")
            }
            outputString.append("\n ,")
            
            outputString.append("Terminal #")
            for nextOutData in outputData
            {
                outputString.append(",\(nextOutData.layers[layerIndex].parentTerminal)")
            }
            outputString.append("\n ,")
            
            outputString.append("Current direction:")
            for nextOutData in outputData
            {
                outputString.append(",\(nextOutData.layers[layerIndex].currentDirection)")
            }
            outputString.append("\n ,")
            
            outputString.append("ID/OD:")
            for nextOutData in outputData
            {
                let mmDims = String(format: "%0.1fmm/%0.1fmm", nextOutData.layers[layerIndex].ID, nextOutData.layers[layerIndex].OD)
                let inchDims = String(format: "%0.3f\"/%0.3f\"", nextOutData.layers[layerIndex].ID / 25.4, nextOutData.layers[layerIndex].OD / 25.4)
                
                outputString.append(",\(mmDims) (\(inchDims))")
            }
            outputString.append("\n ,")
            
            outputString.append("Min radial supports:")
            for nextOutData in outputData
            {
                let minRadSupts = nextOutData.layers[layerIndex].minimumSpacerBars
                let minRadString = minRadSupts < 0.1 ? "N/A" : String(format: "%0.1f", minRadSupts)
                
                outputString.append(",\(minRadString)")
            }
            outputString.append("\n ,")
            
            outputString.append("Max. Radial Force:")
            for nextOutData in outputData
            {
                let nPerMm2 = String(format: "%0.1f N/mm2", nextOutData.layers[layerIndex].maxRadialForce)
                let psi = String(format: "%0.1f psi", nextOutData.layers[layerIndex].maxRadialForce * psiPerNmm2)
                
                outputString.append(",\(nPerMm2) (\(psi))")
            }
            outputString.append("\n ,")
            
            outputString.append("Max. Spacerblock Force: ")
            for nextOutData in outputData
            {
                let nPerMm2 = String(format: "%0.1f N/mm2", nextOutData.layers[layerIndex].maxSpacerBlockForce)
                let psi = String(format: "%0.1f psi", nextOutData.layers[layerIndex].maxSpacerBlockForce * psiPerNmm2)
                
                outputString.append(",\(nPerMm2) (\(psi))")
            }
            outputString.append("\n ,")
            
            outputString.append("Max. Combined Force:")
            for nextOutData in outputData
            {
                let nPerMm2 = String(format: "%0.1f N/mm2", nextOutData.layers[layerIndex].maxCombinedForce)
                let psi = String(format: "%0.1f psi", nextOutData.layers[layerIndex].maxCombinedForce * psiPerNmm2)
                
                outputString.append(",\(nPerMm2) (\(psi))")
            }
            outputString.append("\n ,")
            
            outputString.append("DC Loss:")
            for nextOutData in outputData
            {
                let dc75 = String(format: "%0.1fW @75C", nextOutData.layers[layerIndex].dcLoss(temp: 75.0))
                let dc85 = String(format: "%0.1fW @85C", nextOutData.layers[layerIndex].dcLoss(temp: 85.0))
                
                outputString.append(",\(dc75) (\(dc85))")
            }
            outputString.append("\n ,")
            
            outputString.append("Average Eddy Loss:")
            for nextOutData in outputData
            {
                let aveEddy75 = String(format: "%0.1f%% @75C", nextOutData.layers[layerIndex].aveEddyPU(temp: 75.0) * 100.0)
                let aveEddy85 = String(format: "%0.1f%% @85C", nextOutData.layers[layerIndex].aveEddyPU(temp: 85.0) * 100.0)
                
                outputString.append(",\(aveEddy75) (\(aveEddy85))")
            }
            outputString.append("\n ,")
            
            outputString.append("Maximum Eddy Loss:")
            for nextOutData in outputData
            {
                let maxEddy75 = String(format: "%0.1f%% @75C", nextOutData.layers[layerIndex].maxEddyPU(temp: 75.0) * 100.0)
                let maxEddy85 = String(format: "%0.1f%% @85C", nextOutData.layers[layerIndex].maxEddyPU(temp: 85.0) * 100.0)
                
                outputString.append(",\(maxEddy75) (\(maxEddy85))")
            }
            outputString.append("\n ,")
            
            outputString.append("Maximum Eddy Rectangle:")
            for nextOutData in outputData
            {
                let rect = nextOutData.layers[layerIndex].maxEddyLossRect
                let rectString = String(format: "X:%0.1f Y:%0.1f W:%0.1f H:%0.1f", rect.origin.x, rect.origin.y, rect.size.width, rect.size.height)
                outputString.append(",\(rectString)")
            }
            
            outputString.append("\n\n")
        }
        
        // Show warnings
        outputString.append("Warnings")
        
        let maxWarningCharsPerLine = 40
        var warningStrings:[[String]] = []
        var maxNumWarnings = 0
        for nextOutData in outputData
        {
            warningStrings.append(nextOutData.warnings)
            
            maxNumWarnings = max(maxNumWarnings, nextOutData.warnings.count)
        }
        
        for warningIndex in 0..<maxNumWarnings
        {
            for nextWarning in warningStrings
            {
                outputString.append(",")
                if warningIndex < nextWarning.count
                {
                    let warningWords = nextWarning[warningIndex].components(separatedBy: .whitespaces)
                }
            }
            
            outputString.append("\n\n")
        }
        
        do
        {
            let savePanel = NSSavePanel()
            savePanel.title = "AndersenFE_2020 Output file"
            savePanel.message = "Save Output File"
            savePanel.allowedFileTypes = ["txt"]
            savePanel.allowsOtherFileTypes = false
            
            if savePanel.runModal() == .OK
            {
                if let fileUrl = savePanel.url
                {
                    try outputString.write(to: fileUrl, atomically: false, encoding: .utf8)
                    self.outputDataIsDirty = false
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
    
    @IBAction func handleSaveAndersenOutputFile(_ sender: Any) {
        
        guard let txfo = currentTxfo else
        {
            return
        }
        
        do
        {
            let txfoDetails = try txfo.QuickFLD12transformer()
            let outputString = PCH_FLD12_Library.runFLD12withTxfo(txfoDetails, outputType: .metric, withFluxLines: false)
            
            if outputString.prefix(5) == "ERROR"
            {
                let alert = NSAlert()
                alert.messageText = "Error running Andersen program!"
                alert.informativeText = outputString
                alert.alertStyle = .critical
                let _ = alert.runModal()
                return
            }
            
            let savePanel = NSSavePanel()
            savePanel.title = "Andersen FLD12 Output file"
            savePanel.message = "Save Andersen FLD12 Output file"
            savePanel.allowedFileTypes = ["out"]
            savePanel.allowsOtherFileTypes = false
            
            if savePanel.runModal() == .OK
            {
                if let fileUrl = savePanel.url
                {
                    try outputString.write(to: fileUrl, atomically: false, encoding: .utf8)
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
        
        if self.outputDataIsDirty
        {
            self.askToSaveOutputData()
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
    
    // MARK: Window Delegate Functions
    
    func windowWillClose(_ notification: Notification) {
        
        let wWindow = notification.object as! NSWindow
        
        if wWindow == self.mainWindow
        {
            if self.outputDataIsDirty
            {
                self.askToSaveOutputData()
            }
        }
    }
}
