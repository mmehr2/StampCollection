//
//  JSMessageDelegate.swift
//  StampCollection
//
//  Created by Michael L Mehr on 4/27/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import Foundation
import WebKit

let JSCategoryAll = -2

protocol JSMessageProtocol {
    func messageHandler( handler: JSMessageDelegate, willLoadDataForCategory category: Int)
    func messageHandler( handler: JSMessageDelegate, didLoadDataForCategory category: Int)
    func messageHandler( handler: JSMessageDelegate, receivedData data: BTDealerItem, forCategory category: Int)
    func messageHandler( handler: JSMessageDelegate, receivedUpdate data: BTCategory, forCategory category: Int)
}

class JSMessageDelegate: NSObject, WKScriptMessageHandler {
    
    var delegate: JSMessageProtocol?
    
    private var internalWebView: WKWebView?
    
    private var categoryNumber = JSCategoryAll
    
    private let itemsJSMessage = "getJSItems" // process non-BT site
    
    func loadItemsFromWeb() {
        let url = NSURL(string:"http://www.judaicasales.com/judaica/austrian.asp?on_load=1")
        //    categoryNumber = JSCategory;
        let config = WKWebViewConfiguration()
        let scriptURL = NSBundle.mainBundle().pathForResource("getJSItems", ofType: "js")
        let scriptContent = try? String(contentsOfFile:scriptURL!, encoding:NSUTF8StringEncoding)
        let script = WKUserScript(source: scriptContent!, injectionTime: .AtDocumentEnd, forMainFrameOnly: true)
        config.userContentController.addUserScript(script)
        config.userContentController.addScriptMessageHandler(self, name: itemsJSMessage)
        internalWebView = WKWebView(frame: CGRectZero, configuration: config)
        internalWebView!.loadRequest(NSURLRequest(URL: url!))
        if let delegate = delegate {
            delegate.messageHandler(self, willLoadDataForCategory: categoryNumber)
        }
        // clear the category array in preparation of reload
        //storeModel.categories = []
    }
    
    // MARK: WKScriptMessageHandler
    func userContentController(userContentController: WKUserContentController, didReceiveScriptMessage message: WKScriptMessage) {
        if (message.name == itemsJSMessage) {
            itemsJSMessageHandler(message)
        }
    }
    
    private func itemsJSMessageHandler( message: WKScriptMessage ) {
        //println("Received \(message.name) message")
        if let reply = message.body as? NSDictionary {
            //println("Received \(message.name) message: \(reply)")
            if let dataCountNS = reply["dataCount"] as? NSNumber {
                let dataCount = dataCountNS.integerValue
                if dataCount == -1 {
                    //println("Received null \(message.name) message from main frame")
                } else if let headersNS = reply["headers"] as? NSArray,
                    headers = headersNS as? [String],
                    notesNS = reply["notes"] as? NSString,
                    itemsNS = reply["items"] as? NSArray,
                    jsitems = itemsNS as? [NSDictionary]
                {
                    let notes = notesNS as String
                    if let delegate = delegate {
                        delegate.messageHandler(self, willLoadDataForCategory: categoryNumber)
                    }
                    let category = BTCategory()
                    category.number = categoryNumber
                    //println("Received \(message.name) in cat=\(categoryNumber) with \(dataCount) items with HEADERS \(headers)\n=== NOTES ===\n\(notes)\n============")//\n\(jsitems)")
                    category.notes = notes
                    category.headers = headers
                    for itemX in jsitems {
                        if let item = itemX as? [String: AnyObject] {
                            //println("Item \(item)")
                            let dealerItem = BTDealerItem()
                            for propName in headers {
                                if let value: AnyObject = item[propName] {
                                    dealerItem.setValue(value, forKey: BTDealerItem.translatePropertyNameJS(propName))
                                }
                            }
                            dealerItem.fixupJSItem() // some extra adjustments after properties are loaded
                            if let delegate = delegate {
                                delegate.messageHandler(self, receivedData: dealerItem, forCategory: categoryNumber)
                            }
                            //println("DealerItem \(dealerItem)")
                            //category.dataItems.append(dealerItem)
                        }
                    }
                    if let delegate = delegate {
                        delegate.messageHandler(self, receivedUpdate: category, forCategory: categoryNumber)
                    }
                    if let delegate = delegate {
                        delegate.messageHandler(self, didLoadDataForCategory: categoryNumber)
                    }
                    //updateUI()
                }
            }
        }
    }
    
}
