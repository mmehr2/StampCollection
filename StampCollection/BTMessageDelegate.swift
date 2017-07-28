//
//  BTMessageDelegate.swift
//  StampCollection
//
//  Created by Michael L Mehr on 4/21/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import WebKit

protocol BTInfoProtocol {
    func messageHandler( _ handler: BTMessageDelegate, receivedDetails data: BTItemDetails, forCategory category: Int)
}

protocol BTMessageProtocol : BTInfoProtocol {
    func messageHandler( _ handler: BTMessageDelegate, willLoadDataForCategory category: Int)
    func messageHandler( _ handler: BTMessageDelegate, didLoadDataForCategory category: Int)
    func messageHandler( _ handler: BTMessageDelegate, receivedCategoryData data: BTCategory, forCategory category: Int)
    func messageHandler( _ handler: BTMessageDelegate, receivedData data: BTDealerItem, forCategory category: Int)
    func messageHandler( _ handler: BTMessageDelegate, receivedUpdate data: BTCategory, forCategory category: Int)
}

let BTCategoryAll = -1
let BTURLPlaceHolder = "http://www.google.com" // can be used to specify a URL when none is actually needed

class BTMessageDelegate: NSObject, WKScriptMessageHandler, WKNavigationDelegate {

    var delegate: BTInfoProtocol?
    
    var categoryNumber = BTCategoryAll // indicates all categories in site, or specific category number being loaded by handler object
    
    fileprivate var internalWebView: WKWebView?
    var url: URL!
    var debug = true // set this to T to print console messages during navigation phases using the navigation delegate
    
    // message names received from JS scripts
    let categoriesMessage = "getCategories"
    fileprivate let itemsMessage = "getItems"
    fileprivate let itemDetailsMessage = "getItemDetails"
    
    func configToLoadCategoriesFromWeb() {
        // NOTE: this must run on the main queue since it manipulates the (hidden) UI in the WKWebView
        url = URL(string:"http://www.bait-tov.com/store/viewcat.php?ID=8")
        categoryNumber = BTCategoryAll
        let config = WKWebViewConfiguration()
        let scriptURL = Bundle.main.path(forResource: "getCategories", ofType: "js")
        let scriptContent = try? String(contentsOfFile:scriptURL!, encoding:String.Encoding.utf8)
        let script = WKUserScript(source: scriptContent!, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        config.userContentController.addUserScript(script)
        config.userContentController.add(self, name: categoriesMessage)
        internalWebView = WKWebView(frame: CGRect.zero, configuration: config)
    }
    
    func configToLoadItemsFromWeb( _ href: String, forCategory category: Int ) {
        // NOTE: this must run on the main queue since it manipulates the (hidden) UI in the WKWebView
        url = URL(string: href)
        categoryNumber = category
        let config = WKWebViewConfiguration()
        let scriptURL = Bundle.main.path(forResource: "getItems", ofType: "js")
        let scriptContent = try? String(contentsOfFile:scriptURL!, encoding:String.Encoding.utf8)
        let script = WKUserScript(source: scriptContent!, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        config.userContentController.addUserScript(script)
        config.userContentController.add(self, name: itemsMessage)
        internalWebView = WKWebView(frame: CGRect.zero, configuration: config)
    }
    
    func run() {
        // NOTE: this does the work and can be run on the background thread
        internalWebView!.load(URLRequest(url: url!))
        if let delegate = delegate as? BTMessageProtocol {
            delegate.messageHandler(self, willLoadDataForCategory: categoryNumber)
        }
        // clear the category array in preparation of reload
        //category.dataItems = []
    }
    
    func configToLoadItemDetailsFromWeb( _ href: String, forCategory category: Int16 ) {
        url = URL(string: href) // of the form: http://www.bait-tov.com/store/pic.php?ID=6110s1006 for item ID 6110s1006
        categoryNumber = Int(category) // TBD - should this be Int16 internally tho?
        let config = WKWebViewConfiguration()
        let scriptURL = Bundle.main.path(forResource: "getItemDetails", ofType: "js")
        let scriptContent = try? String(contentsOfFile:scriptURL!, encoding:String.Encoding.utf8)
        let script = WKUserScript(source: scriptContent!, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        config.userContentController.addUserScript(script)
        config.userContentController.add(self, name: itemDetailsMessage)
        internalWebView = WKWebView(frame: CGRect.zero, configuration: config)
        internalWebView!.uiDelegate = (self as! WKUIDelegate) // for debugging messages
    }
    
    func loadItemDetailsFromWeb( _ href: String, forCategory category: Int16 ) {
        configToLoadItemDetailsFromWeb(href, forCategory: category)
        internalWebView!.load(URLRequest(url: url!))
    }
    
    func runInfo() {
        // NOTE: this does the work and can be run on the background thread
        internalWebView!.load(URLRequest(url: url!))
//        if let delegate = delegate {
//            delegate.messageHandler(self, willLoadDataForCategory: categoryNumber)
//        }
        // clear the category array in preparation of reload
        //category.dataItems = []
    }
    
    // MARK: WKNavigationDelegate
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        if let wiView = self.internalWebView, webView === wiView {
            print("Inside webViewWebContentProcessDidTerminate() for handler \(self)")
        }
    }
    
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        if let wiView = self.internalWebView, webView === wiView {
            print("Inside webView(:didCommit:nav=\(navigation!)) for handler \(self)")
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let wiView = self.internalWebView, webView === wiView {
            print("Inside webView(:didFinish:nav=\(navigation!)) for handler \(self)")
        }
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        if let wiView = self.internalWebView, webView === wiView {
            print("Inside webView(:didStartProvisionalNavigation:nav=\(navigation!)) for handler \(self)")
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        if let wiView = self.internalWebView, webView === wiView {
            print("Inside webView(:didFail:nav=\(navigation!):withError\(error)) for handler \(self)")
        }
    }
    
    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        if let wiView = self.internalWebView, webView === wiView {
            print("Inside webView(:didReceiveServerRedirectForProvisionalNavigation:nav=\(navigation!)) for handler \(self)")
        }
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if let wiView = self.internalWebView, webView === wiView {
            print("Inside webView(:didFailProvisionalNavigation:nav=\(navigation!):withError\(error)) for handler \(self)")
        }
    }
    
    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let wiView = self.internalWebView, webView === wiView {
            print("Inside webView(:didReceive(challenge=\(challenge):completion) for handler \(self)")
        }
    }
    
    // MARK: WKScriptMessageHandler
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if (message.name == categoriesMessage) {
            categoriesMessageHandler(message)
        }
        if (message.name == itemsMessage) {
            itemsMessageHandler(message)
        }
        if (message.name == itemDetailsMessage) {
            itemMessageHandler(message)
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
                            if let delegate = delegate as? BTMessageProtocol {
                                delegate.messageHandler(self, receivedCategoryData: category, forCategory: categoryNumber)
                            }
                            //println("Category \(category.number): \(category.name) - \(category.items) items @ \(category.href)")
                        }
                    }
                    if let delegate = delegate as? BTMessageProtocol {
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
                            if let delegate = delegate as? BTMessageProtocol {
                                delegate.messageHandler(self, receivedData: dealerItem, forCategory: categoryNumber)
                            }
                        }
                    }
                    if let delegate = delegate as? BTMessageProtocol {
                        delegate.messageHandler(self, receivedUpdate: category, forCategory: categoryNumber)
                    }
                    if let delegate = delegate as? BTMessageProtocol {
                        delegate.messageHandler(self, didLoadDataForCategory: categoryNumber)
                    }
                }
            }
        }
    }

    /*
     VARIOUS INSIGHTS (7/2017) from study of picURL data from http://www.bait-tov.com/store/pic.php?ID=6110s1228 and similar:
     0. This level of detail is ONLY in category 2 (sets/S/S/FDC) - therefore the protocol will only get messages if it is passed for category 2 (so far)
     1. Someone has lovingly entered the text of all the leaflets and continues to do so. This is where the big articles come from.
     2. The info is on the 4th line of text, and looks the same in the DOM structure.
     3. The second line of text has the full title, including the "Souvenir Sheet" disclaimer, if any (also "Joint Issue" annotation, sometimes both - see Greenland or Vatican)
     4. Of the fields of the info line, each can include multiples separated by commas, e.g. see Alphabet set (s796) for two sheet formats and two plate numbers (the 'p' is not duplicated, and there are no spaces with the commas)
     5. The HTML shows that proper parsing of the RELATED ITEMS list (when present) should show the ID codes for all related FD cancels (pic IDs), related joint items, special sheets, varieties, the works! This is for extending the referredItems feature
     6. This info can be added to the DealerItem extensions via the transient vars feature and used in other contexts
     7. This can be shown for Full Sheets category 31 since it uses the base set pic URL from category 2 already
     */
    fileprivate func itemMessageHandler( _ message: WKScriptMessage ) {
        //println("Received \(message.name) message")
        if let reply = message.body as? NSDictionary, let text = reply["data"] as? String, let html = reply["dom"] as? String {
            let lines1 = text.components(separatedBy: "\n")
            let result1 = lines1.joined(separator: "\n")
            let lines2 = html.components(separatedBy: "\n")
            let result2 = lines2.joined(separator: "\n")
            let _ = result1 + result2 //print("BT item = {{TEXT:\n\(result1)}}\n{{HTML:\n\(result2)}}")
            if categoryNumber == 2 && lines1.count > 3 {
                let titleLine = lines1[1]
                let infoLine = lines1[3]
                // processing needed to make sure we have all possible lines all the time
                let info = BTItemDetails(titleLine: titleLine, infoLine: infoLine)
                if let delegate = delegate {
                    delegate.messageHandler(self, receivedDetails: info, forCategory: categoryNumber)
                }
            }
        }
    }

}
