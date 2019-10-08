//
//  BTMessageDelegate.swift
//  StampCollection
//
//  Created by Michael L Mehr on 4/21/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import WebKit

/*
 BTMessageProtocol
 This is used to communicate data loading events as the BT site web pages are scanned.
 The BT site has one main page of interest, listing the categories, and 28 pages that list the content of each category.
 A complete reload/update of the website involves the following events, and 29 BTMessageDelegate objects:
 -- primary BTMessageDelegate (main page loader) -->
 1. Before the main page is loaded, willLoadDataForCategory is sent with category number -1
 2. After the HTML is loaded and processed, one receivedCategoryData is sent for each category found (data: BTCategory)
 3. At the end of the category page load cycle, didLoadDataForCategory(-1) is sent
 -- each secondary BTMessageDelegate (category data page loader) -->
 4i. Before the data page starts to load, willLoadDataForCategory is sent with a category number i>1
 5i. After the HTML is loaded and processed, one receivedData is sent for each item found (data: BTDealerItem)
 6i. After all the data items are sent, a single receivedUpdate is sent for the category for notes, etc. (data: BTCategory)
 7i. At the end of the data page load cyc;e. didLoadDataForCategory(i) is sent
 
 BTInfoProtocol
 In the special case of Category 2 (Sets,S/S,FDC), there are detail web pages that have additional info that is useful.
 Currently there are 1124 of these pages, and a batch load is required. The mechanism involves the BTItemDetailsLoader class (check there for details). It sends the receivedDetails:forCategory(2) message when one of these web pages has been loaded and processed (data: BTItemDetails). The BTMessageDelegate object is only used as an intermediary to hold the URL and forward this message to the delegate object.
 */
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

protocol BTMessageProcessor {
    func processWebData(_ html:String)
}

let BTCategoryAll = -1
let BTURLPlaceHolder = "http://www.google.com" // can be used to specify a URL when none is actually needed

fileprivate var useLocalSite = false
var BTBaseURL : String {
    let BTBaseURL0 = "http://www.bait-tov.com/store/" //original site (non-expandable)
    let BTBaseURL1 = "http://192.168.1.118.xip.io/BaitTov/bait-tov.com/store/" //= "http://isrstamps.azuresults.com/store/" // in-house site (expandable, not accessible from external locations)
    return useLocalSite ? BTBaseURL1 : BTBaseURL0
}

class BTMessageDelegate: NSObject {
    
    private static let session = URLSession(configuration: .default)
    private static var activeTasks: [String:URLSessionDataTask] = [:] // hashed by internal code number
    private static var cancelling = false

    var delegate: BTInfoProtocol? // also does BTMessageProtocol duties if setup
    var htmlHandler: BTMessageProcessor?
    
    var categoryNumber = BTCategoryAll // indicates all categories in site, or specific category number being loaded by handler object
    
    var url: URL!
    var debug = true // set this to T to enable debug output behavior (saves HTML to files)
    var debugInput = false // set this to T to enable debug input behavior (reads from HTML files instead of loading sites)
    
    private var details = false
    private var allowDebugInput: Bool {
        return !details && debugInput
    }
    private var allowDebugOutput: Bool {
        return !details && debug
    }
    
    fileprivate var debugFileName: String {
        // what file name to use? based on category number (ALL for -1)
        var name = (categoryNumber == BTCategoryAll) ? "BTCatsHtml.txt": "BTCat\(categoryNumber)Html.txt"
        if details {
            let codeName = String(format: "%04d", codeNumber)
            name = "BTD\(codeName)Html.txt"
        }
        return name
    }
    
    fileprivate var debugFile: URL {
        let name = debugFileName
        let ad = UIApplication.shared.delegate! as! AppDelegate
        let fileurl = ad.applicationDocumentsDirectory.appendingPathComponent(name)
        return fileurl
    }

    var codeNumber: Int16 {
        if let href = url?.absoluteString {
         let (_, hnum) = splitNumericEndOfString(href)
         if let hh = Int16(hnum), !hnum.isEmpty {
            return hh
            }
        }
        return 0
    }
    
    func configToLoadCategoriesFromWeb() {
        url = URL(string:BTBaseURL + "viewcat.php?ID=8")
        categoryNumber = BTCategoryAll
        // set up to deal with the main Categories page load
        htmlHandler = BTCategoryMessageProcessor(self)
    }
    
    func configToLoadItemsFromWeb( _ href: String, forCategory category: Int ) {
        url = URL(string: href)
        categoryNumber = category
        // set up to deal with an individual data page load
        htmlHandler = BTItemsMessageProcessor(self, forCategory: category)
        // limit size of operation queue to 1 to save timeout errors
        BTMessageDelegate.session.delegateQueue.maxConcurrentOperationCount = 1
        BTMessageDelegate.session.delegateQueue.qualityOfService = .userInitiated
    }
    
    func configToLoadItemDetailsFromWeb( _ href: String, forCategory category: Int16 ) {
        // NOTE: this is NOT used by the BTItemDetailsLoader, JUST by the WebItem VC
        url = URL(string: href) // of the form: http://www.bait-tov.com/store/pic.php?ID=6110s1006 for item ID 6110s1006
        categoryNumber = Int(category) // TBD - should this be Int16 internally tho?
        // set up to deal with an individual data details page load
        htmlHandler = BTItemDetailsMessageProcessor(self)
        details = true
    }
    
    func run() {
        // setup and run a data task to load the URL
        runInfo()
        // and also send the willLoadData message for our category
        if let delegate = delegate as? BTMessageProtocol {
            delegate.messageHandler(self, willLoadDataForCategory: categoryNumber)
        }
    }
    
    func runInfo() {
        // DEBUG FEATURE: load input directly from file
        if allowDebugInput {
            BTMessageDelegate.session.delegateQueue.addOperation {
                let inputFile = self.debugFile
                do {
                    let html = try String(contentsOf: inputFile, encoding: .utf8)
                    // send html data to parser object
                    if let htmlHandler = self.htmlHandler {
                        htmlHandler.processWebData(html)
                    }
                } catch {
                    print("Unable to read debug HTML from file \(self.debugFileName): \(error.localizedDescription)")
                }
           }
            return
        }
        // setup and run a data task to load the URL
        // create a data task
        let dataTask = BTMessageDelegate.session.dataTask(with: url) { data, response, error in
            // this closure will run when a response is received by the task
            let urlString = self.url.absoluteString
            if let error = error {
                // accumulate error message
                print("DataTask for \(urlString) got client-side error: \(error.localizedDescription)\n")
            } else if let data = data,
                let response = response as? HTTPURLResponse,
                response.statusCode == 200 {
                // parse the response HTML that is in the data buffer
                if let html = String(data: data, encoding: .ascii) {
                    // DEBUG: save the HTML in a data file
                    if self.allowDebugOutput {
                        self.processWebData(html)
                    }
                    // send html data to parser object
                    if let htmlHandler = self.htmlHandler {
                        htmlHandler.processWebData(html)
                    }
                }
            } else {
                print("DataTask for \(self.url.absoluteString) received null data or response, or code other than 200.")
            }
            // in all cases, remove the saved task from the reference list
            BTMessageDelegate.activeTasks[urlString] = nil
            if BTMessageDelegate.cancelling {
                // during cancellation, we just let the tasks delete themselves
                // when the active task map is empty, we are done cancelling
                if BTMessageDelegate.activeTasks.isEmpty {
                    // okay to finally finish the cancellation process and run the UI completion handler
                    BTMessageDelegate.cancelling = false
                   // now it's okay to allow the user to call run() again to "resume" where we left off
                    print("Cancellation of active BT site loader tasks complete.")
                }
            } else {
                // increment to next thing to do?
            }
        }
        // save the data task object ref so it won't crash while loading
        BTMessageDelegate.activeTasks[url.absoluteString] = dataTask
        // resume the data task so it will run
        dataTask.resume()
    }

    // this is a convenience function for the use of the WebItem VC
    func loadItemDetailsFromWeb( _ href: String, forCategory category: Int16 ) {
        configToLoadItemDetailsFromWeb(href, forCategory: category)
        runInfo()
    }
}

// MARK: BTSiteMessageHandler
typealias BTSiteMessage = Dictionary<String, Any>
typealias BTSiteData = Dictionary<String, String>

// message names received from HTML parser
let BTCategoriesMessage = "getCategories"
let BTItemsMessage = "getItems"
let BTItemDetailsMessage = "getItemDetails"

protocol BTSiteMessageHandler {
    // HTML parser will send this to specify the parsed results for each type of web page load
    func setParseResult(_ message: BTSiteMessage, forMessage name:String)
}

extension BTMessageDelegate: BTSiteMessageHandler {

    func setParseResult(_ message: BTSiteMessage, forMessage name:String) {
        if (name == BTCategoriesMessage) {
            categoriesMessageHandler(message)
        }
        if (name == BTItemsMessage) {
            itemsMessageHandler(message)
        }
        if (name == BTItemDetailsMessage) {
            itemMessageHandler(message)
        }
    }
    
    fileprivate func categoriesMessageHandler( _ message: BTSiteMessage? ) {
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
            //print("Raw categories message received:\(rawCategories)")
            if let trows = rawCategories["tableRows"] as? Array<BTSiteData>,
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
                            let href3 = href2.replacingOccurrences(of: "products.php", with: "proddet.php")
                            category.href = href3
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
    
    fileprivate func itemsMessageHandler( _ message: BTSiteMessage? ) {
        //println("Received \(message.name) message")
        if let reply = message {
            // Structure of reply - NSDictionary with props:
            //  dataCount - NSNumber carrying an int = -1 if no data tables (main frame msg), or 0-N length of items array
            //  notes - NSString containing list of notes (separated by \n)
            //  headers - NSArray of NSString, each of which is a column header (variable numbers of columns from category to category)
            //  items - NSArray of NSDictionary, each of which has properties equal to the column headers, plus some extra price fields (OldX and BuyX)
            //    NOTE: there is one OldX prop and one BuyX prob for each PriceX prop that is present, e.g., PriceUsed + BuyUsed + OldPriceUsed
            //    X can be "", "FDC", "Used" or "Other"
            //print("==@==@==@==@==> Raw category data message received:") // divider for auto-slicing the 28 output messages
            //print("\(reply)")
            if let dataCountNS = reply["dataCount"] as? NSNumber {
                let dataCount = dataCountNS.intValue
                if dataCount == -1 {
                    //println("Received null \(message.name) message from main frame")
                } else if let headers = reply["headers"] as? [String],
                    let notes = reply["notes"] as? String,
                    let btitems = reply["items"] as? [BTSiteData]
                {
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
    fileprivate func itemMessageHandler( _ message: BTSiteMessage? ) {
        //println("Received \(message.name) message")
        if let reply = message, let titleLine = reply["title"] as? String, let infoLine = reply["info"] as? String {
            // processing needed to make sure we have all possible lines all the time
            let info = BTItemDetails(titleLine: titleLine, infoLine: infoLine, codeNum: codeNumber)
            if let delegate = delegate {
                delegate.messageHandler(self, receivedDetails: info, forCategory: categoryNumber)
            }
        }
    }

}

// MARK: BTMessageProcessor
extension BTMessageDelegate: BTMessageProcessor {
    // provide default behavior: save the HTML in a file
    func processWebData(_ html: String) {
        let fileurl = debugFile
        print("Saving raw HTML to file \(fileurl.absoluteString)")
        do {
            try html.write(to: fileurl, atomically: false, encoding: .utf8)
        } catch let error {
            print("Unable to write HTML to file \(debugFileName): \(error.localizedDescription)")
        }
    }
}
