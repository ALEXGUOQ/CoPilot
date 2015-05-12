//
//  CoPilotPlugin.swift
//
//  Created by Sven Schmidt on 11/04/2015.
//  Copyright (c) 2015 feinstruktur. All rights reserved.
//

import AppKit
import Cocoa


func publishMenuTitle(doc: NSDocument? = nil) -> String {
    if let title = doc?.displayName {
        return "CoPilot Publish \(title)"
    } else {
        return "CoPilot Publish"
    }
}


var sharedPlugin: CoPilotPlugin?

class CoPilotPlugin: NSObject {
    var bundle: NSBundle! = nil
    var mainController: MainController?
    var observers = [NSObjectProtocol]()
    var publishMenuItem: NSMenuItem! = nil
    var browseMenuItem: NSMenuItem! = nil
    var publishedConnection: ConnectedEditor?

    class func pluginDidLoad(bundle: NSBundle) {
        let appName = NSBundle.mainBundle().infoDictionary?["CFBundleName"] as? NSString
        if appName == "Xcode" {
            sharedPlugin = CoPilotPlugin(bundle: bundle)
        }
    }

    init(bundle: NSBundle) {
        super.init()

        self.bundle = bundle
        self.publishMenuItem = self.menuItem(publishMenuTitle(), action:"publish", key:"p")
        self.browseMenuItem = self.menuItem("CoPilot Browse", action:"browse", key:"x")

        observers.append(
            observe("NSApplicationDidFinishLaunchingNotification", object: nil) { _ in
                self.addMenuItems()
            }
        )
        observers.append(
            observe("NSTextViewDidChangeSelectionNotification", object: nil) { _ in
                self.publishMenuItem.title = publishMenuTitle(doc: XcodeUtils.activeEditor?.document)
            }
        )
    }

    deinit {
        for o in self.observers {
            NSNotificationCenter.defaultCenter().removeObserver(o)
        }
    }
    
    override func validateMenuItem(menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case Selector("publish"):
            return self.hasDoc
        case Selector("browse"):
            return true
        default:
            return NSApplication.sharedApplication().nextResponder?.validateMenuItem(menuItem) ?? false
        }
    }

}


// MARK: - Helpers
extension CoPilotPlugin {
    
    func addMenuItems() {
        var item = NSApp.mainMenu!!.itemWithTitle("Edit")
        if item != nil {
            item!.submenu!.addItem(NSMenuItem.separatorItem())
            item!.submenu!.addItem(self.publishMenuItem)
            item!.submenu!.addItem(self.browseMenuItem)
        }
    }

    
    func menuItem(title: String, action: Selector, key: String) -> NSMenuItem {
        let m = NSMenuItem(title: title, action: action, keyEquivalent: key)
        m.keyEquivalentModifierMask = Int((NSEventModifierFlags.ControlKeyMask | NSEventModifierFlags.CommandKeyMask).rawValue)
        m.target = self
        return m
    }
    
    
    var hasDoc: Bool {
        get {
            return XcodeUtils.activeEditor != nil
        }
    }

}


// MARK: - Actions
extension CoPilotPlugin {
    
    func publish() {
        // TODO: only allow publishing of one editor for now but there's no reason there couldn't be more
        // TODO: also, we need to send over changes - subscribe to NSTextViewWillChangeNotifyingTextViewNotification on textStorage here
        if self.publishedConnection == nil {
            let editor = XcodeUtils.activeEditor!
            self.publishedConnection = publishEditor(editor)
        }

    }

    func browse() {
        if let ed = XcodeUtils.activeEditor {
            if self.mainController == nil {
                self.mainController = MainController(windowNibName: "MainController")
            }
            self.mainController!.activeEditor = ed
            let sheetWindow = self.mainController!.window!
            let doc = ed.document
            doc.windowForSheet!.beginSheet(sheetWindow) { response in
                println("response: \(response)")
            }
        }
    }
    
}

