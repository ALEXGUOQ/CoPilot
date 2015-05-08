//
//  MainController.swift
//  CoPilotPlugin
//
//  Created by Sven Schmidt on 21/04/2015.
//  Copyright (c) 2015 feinstruktur. All rights reserved.
//

import Cocoa
import FeinstrukturUtils


func observe(name: String?, object: AnyObject? = nil, block: (NSNotification!) -> Void) -> NSObjectProtocol {
    let nc = NSNotificationCenter.defaultCenter()
    let queue = NSOperationQueue.mainQueue()
    return nc.addObserverForName(name, object: object, queue: queue, usingBlock: block)
}


class MainController: NSWindowController {

    @IBOutlet weak var publishButton: NSButton!
    @IBOutlet weak var subscribeButton: NSButton!
    @IBOutlet weak var documentsPopupButton: NSPopUpButton!
    @IBOutlet weak var servicesTableView: NSTableView!
    var browser: Browser!
    var publishedService: NSNetService?
    var lastSelectedDoc: NSDocument?
    var docServer: DocServer?
    var docClient: DocClient?
    var observers = [NSObjectProtocol]()
    
    override func windowDidLoad() {
        super.windowDidLoad()
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.window?.delegate = self
        self.browser = Browser(service: CoPilotService) { _ in
            self.servicesTableView.reloadData()
        }
        self.browser.onRemove = { _ in
            self.servicesTableView.reloadData()
        }
        self.observers.append(
            observe("NSTextViewDidChangeSelectionNotification") { _ in
                if let doc = DTXcodeUtils.currentSourceCodeDocument() {
                    self.lastSelectedDoc = doc
                    self.updateUI()
                }
            }
        )
        self.servicesTableView.doubleAction = Selector("rowDoubleClicked:")
        self.updateUI()
        // FIXME: hidden while using hacky version
        self.documentsPopupButton.hidden = true
    }
    
}


// MARK: - Actions
extension MainController {
    
    @IBAction func publishPressed(sender: AnyObject) {
        // FIXME: test hack
        let path = "/tmp/server.txt"
        let name = "server.txt @ \(NSHost.currentHost().localizedName!)"
        let docProvider = documentProvider(path)
        self.docServer = DocServer(name: name, document: docProvider())
        self.docServer?.onUpdate = { doc in
            let res = try({ error in
                doc.text.writeToFile(path, atomically: true, encoding: NSUTF8StringEncoding, error: error)
            })
            if res.failed {
                let reason = "could not create file: \(res.error!.localizedDescription)"
                NSException(name: "MainController", reason: reason, userInfo: nil).raise()
            }
        }
        self.docServer?.poll(docProvider: docProvider)
        return
        
        if let doc = self.lastSelectedDoc {
            let name = "\(doc.displayName) @ \(NSHost.currentHost().localizedName!)"
            self.publishedService = publish(service: CoPilotService, name: name)
        }
    }
    
    @IBAction func subscribePressed(sender: AnyObject) {
        let index = self.servicesTableView.selectedRow
        if index != -1 {
            let service = self.browser[index]
            self.subscribe(service)
        }
    }
    
    
    func rowDoubleClicked(sender: AnyObject) {
        let index = self.servicesTableView.clickedRow
        let service = self.browser[index]
        self.subscribe(service)
    }
    
    
    func subscribe(service: NSNetService) {
        println("subscribing to \(service)")
        
        let editors = DTXcodeUtils.ideEditors()
        // FIXME: we need to make sure to warn against overwrite here
        if let ts = DTXcodeUtils.textStorageForEditor(editors[0]) {
            self.observers.append(
                observe("NSTextStorageDidProcessEditingNotification", object: ts) { _ in
                    println("#### client updated!")
                    self.docClient?.document = Document(ts.string)
                }
            )
            
            self.docClient = {
                let doc = Document(ts.string)
                let client = DocClient(service: service, document: doc)
                client.onInitialize = { doc in
                    //    if source doc not empty, show alert before overwriting
                    //    set source text to doc.text
                    let range = NSRange(location: 0, length: ts.length)
                    println("range: \(range)")
                    ts.replaceCharactersInRange(range, withAttributedString: NSAttributedString(string: doc.text))
                }
                client.onUpdate = client.onInitialize
                return client
            }()
        }
    }
    
}
    
    
// MARK: - Helpers
extension MainController {
    
    func updateUI() {
        let docs = DTXcodeUtils.sourceCodeDocuments()
        let titles = docs.map { $0.displayName!! }
        self.documentsPopupButton.removeAllItems()
        self.documentsPopupButton.addItemsWithTitles(titles)

        if let doc = self.lastSelectedDoc {
            self.publishButton.enabled = true
            self.subscribeButton.enabled = true
            self.documentsPopupButton.enabled = true
            self.documentsPopupButton.selectItemWithTitle(doc.displayName)
        } else {
            self.publishButton.enabled = false
            self.subscribeButton.enabled = false
            self.documentsPopupButton.enabled = false
            self.documentsPopupButton.selectItem(nil)
        }
    }
    
}


// MARK: - NSTableViewDataSource
extension MainController: NSTableViewDataSource {
    
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return self.browser?.count ?? 0
    }
    
}


extension CGRect {
    public func withWidth(width: CGFloat) -> CGRect {
        let size = CGSize(width: width, height: self.size.height)
        return CGRect(origin: self.origin, size: size)
    }
}


// MARK: - NSTableViewDelegate
extension MainController: NSTableViewDelegate {
    
    func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeViewWithIdentifier("MyCell", owner: self) as? NSTableCellView
        if row < self.browser.count { // guarding against race condition
            let item = self.browser[row]
            cell?.textField?.stringValue = item.name
        }
        return cell
    }
    
    func tableViewSelectionDidChange(notification: NSNotification) {
        self.subscribeButton.enabled = (self.servicesTableView.selectedRow != -1)
    }
    
}


// MARK: - NSWindowDelegate
extension MainController: NSWindowDelegate {
    
    func windowDidBecomeKey(notification: NSNotification) {
        let docs = DTXcodeUtils.sourceCodeDocuments()
        if docs.count > 0 && self.lastSelectedDoc == nil {
            self.lastSelectedDoc = docs[0] as? NSDocument
            self.updateUI()
        }
    }
    
    func windowWillClose(notification: NSNotification) {
        for o in self.observers {
            NSNotificationCenter.defaultCenter().removeObserver(o)
        }
    }
    
}

