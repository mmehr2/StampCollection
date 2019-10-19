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
    func messageHandler( _ handler: JSMessageDelegate, willLoadDataForCategory category: Int)
    func messageHandler( _ handler: JSMessageDelegate, didLoadDataForCategory category: Int)
    func messageHandler( _ handler: JSMessageDelegate, receivedData data: BTDealerItem, forCategory category: Int)
    func messageHandler( _ handler: JSMessageDelegate, receivedUpdate data: BTCategory, forCategory category: Int)
}

fileprivate var useLocalSite = true
var JSBaseURL : String {
    let JSBaseURL0 = "http://www.judaicasales.com"  //original site (non-expandable)
    let JSBaseURL1 = "http://192.168.1.118.xip.io/JudaicaSales/judaicasales.com" //http://judaica.azuresults.com" // in-house site (expandable, not accessible from external locations)
    return useLocalSite ? JSBaseURL1 : JSBaseURL0
}

class JSMessageDelegate: NSObject, WKScriptMessageHandler {
    
    var delegate: JSMessageProtocol?
    
    fileprivate var internalWebView: WKWebView?
    fileprivate var url: URL!
    
    fileprivate var categoryNumber = JSCategoryAll
    
    fileprivate let itemsJSMessage = "getJSItems" // process non-BT site
    
    func configToLoadItemsFromWeb() {
        url = URL(string:JSBaseURL + "/judaica/austrian.asp?on_load=1")
        //    categoryNumber = JSCategory;
        let config = WKWebViewConfiguration()
        let scriptURL = Bundle.main.path(forResource: "getJSItems", ofType: "js")
        let scriptContent = try? String(contentsOfFile:scriptURL!, encoding:String.Encoding.utf8)
        let script = WKUserScript(source: scriptContent!, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        config.userContentController.addUserScript(script)
        config.userContentController.add(self, name: itemsJSMessage)
        internalWebView = WKWebView(frame: CGRect.zero, configuration: config)
    }
    
    func run() {
        internalWebView!.load(URLRequest(url: url!))
        if let delegate = delegate {
            delegate.messageHandler(self, willLoadDataForCategory: categoryNumber)
        }
        // clear the category array in preparation of reload
        //storeModel.categories = []
    }
    
    // MARK: WKScriptMessageHandler
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if (message.name == itemsJSMessage) {
            itemsJSMessageHandler(message)
        }
    }
    
    fileprivate func itemsJSMessageHandler( _ message: WKScriptMessage ) {
        //println("Received \(message.name) message")
        if let reply = message.body as? NSDictionary {
            //println("Received \(message.name) message: \(reply)")
            if let dataCountNS = reply["dataCount"] as? NSNumber {
                let dataCount = dataCountNS.intValue
                if dataCount == -1 {
                    //println("Received null \(message.name) message from main frame")
                } else if let headersNS = reply["headers"] as? NSArray,
                    let headers = headersNS as? [String],
                    let notesNS = reply["notes"] as? NSString,
                    let itemsNS = reply["items"] as? NSArray,
                    let jsitems = itemsNS as? [NSDictionary]
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
