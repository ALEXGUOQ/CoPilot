//
//  DocClient.swift
//  CoPilotPlugin
//
//  Created by Sven Schmidt on 06/05/2015.
//  Copyright (c) 2015 feinstruktur. All rights reserved.
//

import Foundation
import FeinstrukturUtils


struct SimpleConnection: Connection {
    let displayName: String
}




class DocClient: DocNode {

    private var socket: WebSocket?
    private var resolver: Resolver?
    private var connection: Connection?


    init(name: String = "DocClient", service: NSNetService, document: Document) {
        self.resolver = Resolver(service: service, timeout: 5)

        super.init(name: name, document: document)

        self.resolver!.onResolve = { websocket in
            self.connection = SimpleConnection(displayName: service.name)
            self.socket = websocket
            websocket.onConnect = {
                self.socket?.send(Command(name: self.name))
            }
            websocket.onReceive = self.onReceive
        }
    }


    func onReceive(msg: Message) {
        let cmd = Command(data: msg.data!)
        // println("#### client cmd: \(cmd)")
        switch cmd {
        case .Doc(let doc):
            self.commit(doc)
        case .Update(let changes):
            let res = apply(self._document, changes)
            if res.succeeded {
                self.commit(res.value!)
            } else {
                // attempt merge
                if let ancestor = self.revisions.objectForKey(changes.baseRev) as? String {
                    let mine = self._document.text
                    let res = apply(ancestor, changes.patches)
                    if let yours = res.value,
                       let merged = merge(mine, ancestor, yours) {
                        self.commit(Document(merged))
                    } else {
                        // request original document in order to re-sync
                        self.socket?.send(Command.GetDoc)
                    }
                } else {
                    println("#### client: applying patch failed: \(res.error!.localizedDescription)")
                    // request original document in order to re-sync
                    self.socket?.send(Command.GetDoc)
                }
            }
        case .GetDoc:
            self.socket?.send(Command(document: self._document))
        default:
            println("messageHandler: ignoring command: \(cmd)")
        }
    }

}


extension DocClient: ConnectedDocument {

    var onUpdate: UpdateHandler? {
        get { return self._onUpdate }
        set { self._onUpdate = newValue }
    }
    
    
    func update(newDocument: Document) {
        if let changes = Changeset(source: self._document, target: newDocument) {
            self._document = newDocument
            self.sendThrottle.execute {
                self.socket?.send(Command(update: changes))
            }
        }
    }
    
    
    func disconnect() {
        self.socket?.close()
    }
 
    
    var connections: [Connection] {
        if let c = self.connection {
            return [c]
        } else {
            return [Connection]()
        }
    }
    
}

