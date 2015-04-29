//
//  MainController.swift
//  CoPilotPlugin
//
//  Created by Sven Schmidt on 21/04/2015.
//  Copyright (c) 2015 feinstruktur. All rights reserved.
//

import Cocoa


func observe(name: String?, object: AnyObject? = nil, block: (NSNotification!) -> Void) -> NSObjectProtocol {
    let nc = NSNotificationCenter.defaultCenter()
    let queue = NSOperationQueue.mainQueue()
    return nc.addObserverForName(name, object: object, queue: queue, usingBlock: block)
}


class MainController: NSWindowController {

    @IBOutlet weak var publishButton: NSButton!
    @IBOutlet weak var documentsPopupButton: NSPopUpButton!
    @IBOutlet weak var servicesTableView: NSTableView!
    var browser: Browser!
    var publishedService: NSNetService?
    var lastSelectedDoc: NSDocument?
    
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
        observe("NSTextViewDidChangeSelectionNotification") { _ in
            self.updateUI()
            if let doc = DTXcodeUtils.currentSourceCodeDocument() {
                self.documentsPopupButton.selectItemWithTitle(doc.displayName)
                self.lastSelectedDoc = doc
            }
        }
    }
    
}


// MARK: - Actions
extension MainController {
    
    @IBAction func publishPressed(sender: AnyObject) {
        if let doc = self.lastSelectedDoc {
            let name = "\(doc.displayName)@\(NSHost.currentHost().localizedName)"
            self.publishedService = publish(service: CoPilotService, name: name)
        }
    }
    
    @IBAction func subscribePressed(sender: AnyObject) {
    }
    
}
    
    
// MARK: - Helpers
extension MainController {
    
    func updateUI() {
        let docs = DTXcodeUtils.sourceCodeDocuments()
        self.publishButton.enabled = (docs.count > 0)
        let titles = docs.map { $0.displayName!! }
        self.documentsPopupButton.removeAllItems()
        self.documentsPopupButton.addItemsWithTitles(titles)
    }
    
}


// MARK: - NSTableViewDataSource
extension MainController: NSTableViewDataSource {
    
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return 3 //self.browser?.services.count ?? 0
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
        println(tableColumn?.width)
        let cell = tableView.makeViewWithIdentifier("MyCell", owner: self) as? NSTableCellView
//        if row < self.browser.services.count { // guarding against race condition
//            let item = self.browser.services[row] as! NSNetService
            cell?.textField?.stringValue = "guarding against race condition guarding against race condition " //item.name
//        }
        return cell
    }
    
}


// MARK: - NSWindowDelegate
extension MainController: NSWindowDelegate {
    
    func windowDidBecomeKey(notification: NSNotification) {
        self.updateUI()
    }
    
}

