//
//  BTMessageDelegate.swift
//  StampCollection
//
//  Created by Michael L Mehr on 4/21/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import WebKit

protocol BTMessageProtocol {
    func messageHandler( _ handler: BTMessageDelegate, willLoadDataForCategory category: Int)
    func messageHandler( _ handler: BTMessageDelegate, didLoadDataForCategory category: Int)
    func messageHandler( _ handler: BTMessageDelegate, receivedData data: AnyObject, forCategory category: Int)
    func messageHandler( _ handler: BTMessageDelegate, receivedUpdate data: BTCategory, forCategory category: Int)
}

let BTCategoryAll = -1

class BTMessageDelegate: NSObject, WKScriptMessageHandler {

    var delegate: BTMessageProtocol?
    
    var categoryNumber = BTCategoryAll // indicates all categories in site, or specific category number being loaded by handler object
    
    let categoriesMessage = "getCategories"
    
    fileprivate var internalWebView: WKWebView?
    
    fileprivate let itemsMessage = "getItems"
    
    
    func loadCategoriesFromWeb() {
        let url = URL(string:"http://www.bait-tov.com/store/viewcat.php?ID=8")
        categoryNumber = BTCategoryAll;
        let config = WKWebViewConfiguration()
        let scriptURL = Bundle.main.path(forResource: "getCategories", ofType: "js")
        let scriptContent = try? String(contentsOfFile:scriptURL!, encoding:String.Encoding.utf8)
        let script = WKUserScript(source: scriptContent!, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        config.userContentController.addUserScript(script)
        config.userContentController.add(self, name: categoriesMessage)
        internalWebView = WKWebView(frame: CGRect.zero, configuration: config)
        internalWebView!.load(URLRequest(url: url!))
        if let delegate = delegate {
            delegate.messageHandler(self, willLoadDataForCategory: categoryNumber)
        }
        // clear the category array in preparation of reload
        //storeModel.categories = []
    }
    
    func loadItemsFromWeb( _ href: String, forCategory category: Int ) {
        let url = URL(string: href)
        categoryNumber = category
        let config = WKWebViewConfiguration()
        let scriptURL = Bundle.main.path(forResource: "getItems", ofType: "js")
        let scriptContent = try? String(contentsOfFile:scriptURL!, encoding:String.Encoding.utf8)
        let script = WKUserScript(source: scriptContent!, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        config.userContentController.addUserScript(script)
        config.userContentController.add(self, name: itemsMessage)
        internalWebView = WKWebView(frame: CGRect.zero, configuration: config)
        internalWebView!.load(URLRequest(url: url!))
        if let delegate = delegate {
            delegate.messageHandler(self, willLoadDataForCategory: categoryNumber)
        }
        // clear the category array in preparation of reload
        //category.dataItems = []
    }
    
    // MARK: WKScriptMessageHandler
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if (message.name == categoriesMessage) {
            categoriesMessageHandler(message)
        }
        if (message.name == itemsMessage) {
            itemsMessageHandler(message)
        }
    }
    
    fileprivate func categoriesMessageHandler( _ message: WKScriptMessage ) {
        //println("Received \(message.name) message")
        if let rawCategories = message.body as? NSDictionary {
            // Structure: contains two NSArrays
            // "tableRows" is an array of NSString, each representing a column name (#, Name, Items)
            // "tableCols" is an array of NSDictionary, each representing a category object
            //   each object has proerties equal to the column names, whose value is an NSString
            //      the # is a small integer
            //      the Name really is a string
            //      the Items is a small integer
            //   in addition, each has an href property, an NSString of the form "products.php?SubCat=N&Mark=&Page=1"
            //   in addition, for debugging, each has an NSString property "raw" (innerHTML of the table row)
            //                let tableCols = rawCategories["tableCols"] as! NSArray;
            //                let tableRows = rawCategories["tableRows"] as! NSArray;
            //                println("Category names: \(tableCols) => \(tableRows)")
            if let trows = rawCategories["tableRows"] as? NSArray,
                let tcols = rawCategories["tableCols"] as? NSArray,
                let column1Header = tcols[0] as? NSString,
                let column2Header = tcols[1] as? NSString,
                let column3Header = tcols[2] as? NSString {
                    //println("Headers = [\(col1Header), \(col2Header), \(col3Header)]")
                    // println("There are \(tcols) column names for the table of Categories = \(trows)")
                    let
                    col1Header = column1Header as String,
                    col2Header = column2Header as String,
                    col3Header = column3Header as String
                    for row in trows {
                        /*
                        Typical row:
                        {
                        "#" = 1;
                        Items = 97;
                        Name = "Israel's On Sale";
                        href = "http://www.bait-tov.com/store/products.php?SubCat=868&Mark=&Page=1";
                        },
                        */
                        if let row = row as? NSDictionary,
                            let numberN = row.value(forKey: col1Header) as? NSString,
                            let nameN = row.value(forKey: col2Header) as? NSString,
                            let itemsN = row.value(forKey: col3Header) as? NSString,
                            let hrefN = row.value(forKey: "href") as? NSString
                        {
                            //println("Row = \(row)")
                            let name = nameN as String,
                            number = numberN as String,
                            items = itemsN as String,
                            href = hrefN as String
                            let category = BTCategory()
                            category.name = name as String
                            category.href = href as String
                            category.number = Int(number)!
                            category.items = Int(items)!
                            if let delegate = delegate {
                                delegate.messageHandler(self, receivedData: category, forCategory: categoryNumber)
                            }
                            //println("Category \(category.number): \(category.name) - \(category.items) items @ \(category.href)")
                        }
                    }
                    if let delegate = delegate {
                        delegate.messageHandler(self, didLoadDataForCategory: categoryNumber)
                    }
            }
        }
    }
    
    fileprivate func itemsMessageHandler( _ message: WKScriptMessage ) {
        //println("Received \(message.name) message")
        if let reply = message.body as? NSDictionary {
            // Structure of reply - NSDictionary with props:
            //  dataCount - NSNumber carrying an int = -1 if no data tables (main frame msg), or 0-N length of items array
            //  notes - NSString containing list of notes (separated by \n)
            //  headers - NSArray of NSString, each of which is a column header (variable numbers of columns from category to category)
            //  items - NSArray of NSDictionary, each of which has properties equal to the column headers, plus some extra price fields (OldX and BuyX)
            //    NOTE: there is one OldX prop and one BuyX prob for each PriceX prop that is present, e.g., PriceUsed + BuyUsed + OldPriceUsed
            //    X can be "", "FDC", "Used" or "Other"
            if let dataCountNS = reply["dataCount"] as? NSNumber {
                let dataCount = dataCountNS.intValue
                if dataCount == -1 {
                    //println("Received null \(message.name) message from main frame")
                } else if let headersNS = reply["headers"] as? NSArray,
                    let headers = headersNS as? [String],
                    let notesNS = reply["notes"] as? NSString,
                    let itemsNS = reply["items"] as? NSArray,
                    let btitems = itemsNS as? [NSDictionary]
                {
                    let notes = notesNS as String
                    let category = BTCategory()
                    category.number = categoryNumber
                    //println("Received \(message.name) in cat=\(categoryNumber) with \(dataCount) items with HEADERS \(headers)\n=== NOTES ===\n\(notes)\n============")//\n\(btitems)")
                    category.notes = notes
                    category.headers = headers
                    for itemX in btitems {
                        if let item = itemX as? [String: AnyObject] {
                            let dealerItem = BTDealerItem()
                            for propName in headers {
                                if let value: AnyObject = item[propName] {
                                    dealerItem.setValue(value, forKey: BTDealerItem.translatePropertyName(propName))
                                }
                            }
                            // add any fixup of item property fields here
                            dealerItem.fixupBTItem(categoryNumber)
                            if let delegate = delegate {
                                delegate.messageHandler(self, receivedData: dealerItem, forCategory: categoryNumber)
                            }
                        }
                    }
                    if let delegate = delegate {
                        delegate.messageHandler(self, receivedUpdate: category, forCategory: categoryNumber)
                    }
                    if let delegate = delegate {
                        delegate.messageHandler(self, didLoadDataForCategory: categoryNumber)
                    }
                }
            }
        }
    }
    

}
