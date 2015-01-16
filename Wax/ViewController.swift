//
//  ViewController.swift
//  Wax
//
//  Created by Michael Oneppo on 1/11/15.
//  Copyright (c) 2015 moneppo. All rights reserved.
//

import UIKit
import WebKit
import PeerKit
import MultipeerConnectivity
import Foundation


enum Event: String {
    case PrivateMessage = "PM",
    BroadcastMessage = "BM",
    Response = "RES",
    Request = "REQ"
}

class ViewController: UIViewController, WKNavigationDelegate {
    
    @IBOutlet var containerView : UIView! = nil
    var webView: WKWebView?
    var uuids = [String: MCPeerID]()
    
    func onEvent(event: Event, run: ObjectBlock?) {
        if let run = run {
            PeerKit.eventBlocks[event.rawValue] = run
        } else {
            PeerKit.eventBlocks.removeValueForKey(event.rawValue)
        }
    }
    
    func onConnect(run: PeerBlock?) {
        PeerKit.onConnect = run
    }
    
    func onDisconnect(run: PeerBlock?) {
        PeerKit.onDisconnect = run
    }
    
    func webView(webView: WKWebView!, didFinishNavigation navigation: WKNavigation!) {
        println("WebView content loaded.")
    }
    
    func webView(webView: WKWebView!, didFailNavigation navigation: WKNavigation!) {
        println("Something failed.")
    }
    
    func webView(webView: WKWebView!, didFailProvisionalNavigation navigation: WKNavigation!) {
        println("Something p failed.")

    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Broken - waiting on fix, workaround below
        //var indexPath = NSBundle.mainBundle().pathForResource("index", ofType: "html", inDirectory: "www")
        
        let path = copyBundleWWWFolder()
        let indexPath = path.stringByAppendingPathComponent("index.html")

        let url = NSURL(fileURLWithPath: indexPath)
        let req = NSURLRequest(URL:url!)
        self.webView!.loadRequest(req)
        
        
        PeerKit.transceive("com-moneppo-Wax")

        setupEventHandlers()
    }
    
    
    func setupEventHandlers() {
        onEvent(.PrivateMessage) { peer, object in
            let message = object as String
            let peerName = peer.displayName!
            let action = "privateMessage"
            let code = "wax.trigger(\(action), {message:'\(message)\', peer:'\(peerName)'});";
            self.webView?.evaluateJavaScript(code) { object, error in
            }
        }
        
        onEvent(.BroadcastMessage) { peer, object in
            let message = object as String
            let peerName = peer.displayName!
            let action = "broadcastMessage"
            let code = "wax.trigger(\(action), {message:'\(message)\', peer:'\(peerName)'});";
            self.webView?.evaluateJavaScript(code) { object, error in
            }
        }
        
        onConnect() { peer in
            let peerName = peer.displayName!
            let action = "connection"
            let uuid = NSUUID().UUIDString
            let code = "wax.trigger(\(action), {name:'\(peerName)', id:'\(uuid)'});";
            self.uuids[uuid] = peer
            self.webView?.evaluateJavaScript(code) { object, error in
            }
        }
        
        // Disconnect is O(n) because iOS likes using object instances as handles...
        onDisconnect() { peer in
            let peerName = peer.displayName!
            for (uuid, possiblePeer) in self.uuids {
                if (peer == possiblePeer) {
                    let action = "disconnect"
                    let peerName = peer.displayName!
                    let code = "wax.trigger(\(action), {name:'\(peerName)', id:'\(uuid)'});";
                    self.uuids[uuid] = nil
                    self.webView?.evaluateJavaScript(code) { object, error in
                    }
                    break
                }
            }
        }
        
        // Thought: make a route message that is broadcast periodically, with just the UUID. When
        // received, simply store the sending MCPeerID and the UUID. Whenever you want to send to
        // that UUID, you send to the MCPeerID you have on file. Receiving, if it isn't your 
        // UUID, you relay to the MCPeerID you have on file. This means you have to flood periodically,
        // but it's a good 2.0. Will want to collect the resulting path - that will be super 
        // interesting for UI etc.
    }
    
    func initConfiguration() -> WKWebViewConfiguration {
        let path = NSBundle.mainBundle().pathForResource("lib", ofType: "js")
        let source = String(contentsOfFile: path!, encoding: NSUTF8StringEncoding, error: nil)
        let userScript = WKUserScript(source: source!, injectionTime: .AtDocumentStart, forMainFrameOnly: true)
        
        class PrivateMessageHandler: NSObject, WKScriptMessageHandler {
            func userContentController(userContentController: WKUserContentController, didReceiveScriptMessage message: WKScriptMessage) {
                PeerKit.sendEvent(Event.PrivateMessage.rawValue, object: message.body)
                NSLog("Message received")
            }
        }
        
        
        class BroadcastMessageHandler: NSObject, WKScriptMessageHandler {
            func userContentController(userContentController: WKUserContentController, didReceiveScriptMessage message: WKScriptMessage) {
                PeerKit.sendEvent(Event.BroadcastMessage.rawValue, object: message.body)
                NSLog("Message received")
            }
        }
        
        class RequestMessageHandler: NSObject, WKScriptMessageHandler {
            func userContentController(userContentController: WKUserContentController, didReceiveScriptMessage message: WKScriptMessage) {
                let url = message.body as String
                // Do nothing for now
                NSLog("Message received")
            }
        }
        
        let userContentController = WKUserContentController()
        let pmHandler = PrivateMessageHandler()
        let bmHandler = BroadcastMessageHandler()
        let reqHandler = RequestMessageHandler()
        userContentController.addScriptMessageHandler(pmHandler, name: "privateMessage")
        userContentController.addScriptMessageHandler(bmHandler, name: "broadcastMessage")
        userContentController.addScriptMessageHandler(reqHandler, name: "request")
        userContentController.addUserScript(userScript)
        
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = userContentController
        return configuration
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func loadView() {
        super.loadView()
        self.webView = WKWebView(frame: self.view.bounds, configuration: initConfiguration())
        self.webView!.navigationDelegate = self
        self.view = self.webView
    }
    
    func copyBundleWWWFolder() -> String {
        let tmpDir = NSURL(fileURLWithPath:NSTemporaryDirectory(), isDirectory:true)
        let id = NSUUID().UUIDString
        let indexPath = NSBundle.mainBundle().pathForResource("index", ofType: "html", inDirectory: "www")
        let path = indexPath!.stringByDeletingLastPathComponent
        let fm = NSFileManager.defaultManager()
        
        let newPath = tmpDir!.path!.stringByAppendingPathComponent(id)
        var error : NSError?
        
        fm.createDirectoryAtPath(newPath, withIntermediateDirectories: true, attributes: nil, error: &error)
        if let actualError = error {
            println("An Error Occurred: \(actualError)")
        }
        
        fm.copyItemAtPath(path, toPath: newPath.stringByAppendingPathComponent("www"),  error: &error)
        if let actualError = error {
            println("An Error Occurred: \(actualError)")
        }
    
        return newPath.stringByAppendingPathComponent("www");
    }
}

