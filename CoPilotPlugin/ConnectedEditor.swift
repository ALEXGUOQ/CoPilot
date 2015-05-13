//
//  DocumentManager.swift
//  CoPilotPlugin
//
//  Created by Sven Schmidt on 12/05/2015.
//  Copyright (c) 2015 feinstruktur. All rights reserved.
//

import Cocoa
import FeinstrukturUtils


typealias UpdateHandler = (Document -> Void)


protocol ConnectedDocument {
    var onUpdate: UpdateHandler? { get set }
    func update(newDocument: Document)
    func disconnect()
}


struct Editor {
    let controller: NSViewController
    let window: NSWindow
    let textStorage: NSTextStorage
    let document: NSDocument
    
    init?(controller: NSViewController?, window: NSWindow?) {
        if  let controller = controller,
            let window = window,
            let ts = XcodeUtils.textStorage(controller),
            let doc = XcodeUtils.sourceCodeDocument(controller) {
                self.controller = controller
                self.window = window
                self.textStorage = ts
                self.document = doc
        } else {
            return nil
        }
    }
}


extension Editor: Equatable { }

func ==(lhs: Editor, rhs: Editor) -> Bool {
    return lhs.controller == rhs.controller
        && lhs.window == rhs.window
}


class ConnectedEditor {
    let editor: Editor
    var document: ConnectedDocument
    var observer: NSObjectProtocol! = nil
    var sendThrottle = Throttle(bufferTime: 0.5)
    
    init(editor: Editor, document: ConnectedDocument) {
        self.editor = editor
        self.document = document
        self.startObserving()
        self.setOnUpdate()
    }
    
    // NB: inlining this crashes the compiler (Version 6.3.1 (6D1002))
    private func startObserving() {
        self.observer = observe("NSTextStorageDidProcessEditingNotification", object: editor.textStorage) { _ in
            self.sendThrottle.execute {
                println("#### doc updated")
                self.document.update(Document(self.editor.textStorage.string))
            }
        }
    }
    
    // NB: inlining this crashes the compiler (Version 6.3.1 (6D1002))
    private func setOnUpdate() {
        // TODO: refine this by only replacing the changed text or at least keeping the caret in place
        self.document.onUpdate = { doc in
            if let tv = XcodeUtils.sourceTextView(self.editor.controller) {
                let selected = tv.selectedRange
                self.editor.textStorage.replaceAll(doc.text)
                if selected.location + selected.length < count(doc.text) {
                    tv.setSelectedRange(selected)
                }
            }
        }
    }
    
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self.observer)
    }
}

