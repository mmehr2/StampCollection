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
    var debug = false // set this to T to print console messages during navigation phases using the navigation delegate

    var codeNumber: Int16 {
        if let href = url?.absoluteString {
         let (_, hnum) = splitNumericEndOfString(href)
         if let hh = Int16(hnum), !hnum.isEmpty {
            return hh
            }
        }
        return 0
    }
    
   
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
        internalWebView!.navigationDelegate = (self) // as! WKNavigationDelegate) // for debugging messages
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
            if !debug { return }
            print("Inside webViewWebContentProcessDidTerminate() for handler \(self)")
        }
    }
    
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        if let wiView = self.internalWebView, webView === wiView {
            if !debug { return }
            print("Inside webView(:didCommit:nav=\(navigation!)) for handler \(self)")
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let wiView = self.internalWebView, webView === wiView {
            if !debug { return }
            print("Inside webView(:didFinish:nav=\(navigation!)) for handler \(self)")
        }
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        if let wiView = self.internalWebView, webView === wiView {
            if !debug { return }
            print("Inside webView(:didStartProvisionalNavigation:nav=\(navigation!)) for handler \(self)")
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        if let wiView = self.internalWebView, webView === wiView {
            if !debug { return }
            print("Inside webView(:didFail:nav=\(navigation!):withError\(error)) for handler \(self)")
        }
    }
    
    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        if let wiView = self.internalWebView, webView === wiView {
            if !debug { return }
            print("Inside webView(:didReceiveServerRedirectForProvisionalNavigation:nav=\(navigation!)) for handler \(self)")
        }
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if let wiView = self.internalWebView, webView === wiView {
            if !debug { return }
            print("Inside webView(:didFailProvisionalNavigation:nav=\(navigation!):withError\(error)) for handler \(self)")
        }
    }
    
    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let wiView = self.internalWebView, webView === wiView {
            if !debug { return }
            print("Inside webView(:didReceive(challenge=\(challenge):completion) for handler \(self)")
        }
    }

    typealias SiteMessage = Dictionary<String, Any>
    typealias SiteData = Dictionary<String, String>
    
    // MARK: WKScriptMessageHandler
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        let smsg =  message.body as? SiteMessage
        if (message.name == categoriesMessage) {
            categoriesMessageHandler(smsg)
        }
        if (message.name == itemsMessage) {
            itemsMessageHandler(smsg)
        }
        if (message.name == itemDetailsMessage) {
            itemMessageHandler(smsg)
        }
    }
    
    fileprivate func categoriesMessageHandler( _ message: SiteMessage? ) {
        //println("Received \(message.name) message")
        if let rawCategories = message {
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
            print("Raw categories message received:\(rawCategories)")
            if let trows = rawCategories["tableRows"] as? Array<SiteData>,
                let tcols = rawCategories["tableCols"] as? Array<String> {
                    //print("Headers = [\(col1Header), \(col2Header), \(col3Header)]")
                    // print("There are \(tcols) column names for the table of Categories = \(trows)")
                    let
                    col1Header = tcols[0],
                    col2Header = tcols[1],
                    col3Header = tcols[2]
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
                        if let number = row[col1Header],
                            let name = row[col2Header],
                            let items = row[col3Header],
                            let href = row["href"]
                        {
                            //println("Row = \(row)")
                            let category = BTCategory()
                            category.name = name
                            let href2 = href.replacingOccurrences(of: "Page=1", with: "Page=ALL")
                            category.href = href2
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
    
    fileprivate func itemsMessageHandler( _ message: SiteMessage? ) {
        //println("Received \(message.name) message")
        if let reply = message {
            // Structure of reply - NSDictionary with props:
            //  dataCount - NSNumber carrying an int = -1 if no data tables (main frame msg), or 0-N length of items array
            //  notes - NSString containing list of notes (separated by \n)
            //  headers - NSArray of NSString, each of which is a column header (variable numbers of columns from category to category)
            //  items - NSArray of NSDictionary, each of which has properties equal to the column headers, plus some extra price fields (OldX and BuyX)
            //    NOTE: there is one OldX prop and one BuyX prob for each PriceX prop that is present, e.g., PriceUsed + BuyUsed + OldPriceUsed
            //    X can be "", "FDC", "Used" or "Other"
            print("==@==@==@==@==> Raw category data message received:") // divider for auto-slicing the 28 output messages
            print("\(reply)")
            if let dataCountNS = reply["dataCount"] as? NSNumber {
                let dataCount = dataCountNS.intValue
                if dataCount == -1 {
                    //println("Received null \(message.name) message from main frame")
                } else if let headers = reply["headers"] as? [String],
                    let notesNS = reply["notes"] as? String,
                    let btitems = reply["items"] as? [SiteData]
                {
                    let notes = notesNS as String
                    let category = BTCategory()
                    category.number = categoryNumber
                    //println("Received \(message.name) in cat=\(categoryNumber) with \(dataCount) items with HEADERS \(headers)\n=== NOTES ===\n\(notes)\n============")//\n\(btitems)")
                    category.notes = notes
                    category.headers = headers
                    for item in btitems {
                        let dealerItem = BTDealerItem()
                        for propName in headers {
                            if let value = item[propName] {
                                dealerItem.setValue(value, forKey: BTDealerItem.translatePropertyName(propName))
                            }
                        }
                        // add any fixup of item property fields here
                        dealerItem.fixupBTItem(categoryNumber)
                        if let delegate = delegate as? BTMessageProtocol {
                            delegate.messageHandler(self, receivedData: dealerItem, forCategory: categoryNumber)
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
    fileprivate func itemMessageHandler( _ message: SiteMessage? ) {
        //println("Received \(message.name) message")
        if let reply = message, let text = reply["data"] as? String, let html = reply["dom"] as? String {
            let lines1 = text.components(separatedBy: "\n")
            let result1 = lines1.joined(separator: "\n")
            let lines2 = html.components(separatedBy: "\n")
            let result2 = lines2.joined(separator: "\n")
            let _ = result1 + result2 //print("BT item = {{TEXT:\n\(result1)}}\n{{HTML:\n\(result2)}}")
            if categoryNumber == 2 && lines1.count > 3 {
                let titleLine = lines1[1]
                let infoLine = lines1[3]
                // processing needed to make sure we have all possible lines all the time
                let info = BTItemDetails(titleLine: titleLine, infoLine: infoLine, codeNum: codeNumber)
                if let delegate = delegate {
                    delegate.messageHandler(self, receivedDetails: info, forCategory: categoryNumber)
                }
            }
        }
    }

}
