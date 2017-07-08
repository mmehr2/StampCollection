//
//  BTMessageDelegate.swift
//  StampCollection
//
//  Created by Michael L Mehr on 4/21/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import WebKit

protocol BTInfoProtocol {
    func messageHandler( _ handler: BTMessageDelegate, receivedData data: AnyObject, forCategory category: Int)
}

protocol BTMessageProtocol : BTInfoProtocol {
    func messageHandler( _ handler: BTMessageDelegate, willLoadDataForCategory category: Int)
    func messageHandler( _ handler: BTMessageDelegate, didLoadDataForCategory category: Int)
    //func messageHandler( _ handler: BTMessageDelegate, receivedData data: AnyObject, forCategory category: Int)
    func messageHandler( _ handler: BTMessageDelegate, receivedUpdate data: BTCategory, forCategory category: Int)
}

let BTCategoryAll = -1

class BTMessageDelegate: NSObject, WKScriptMessageHandler {

    var delegate: BTInfoProtocol?
    
    var categoryNumber = BTCategoryAll // indicates all categories in site, or specific category number being loaded by handler object
    
    fileprivate var internalWebView: WKWebView?
    
    // message names received from JS scripts
    let categoriesMessage = "getCategories"
    fileprivate let itemsMessage = "getItems"
    fileprivate let itemDetailsMessage = "getItemDetails"
    
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
        if let delegate = delegate as? BTMessageProtocol {
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
        if let delegate = delegate as? BTMessageProtocol {
            delegate.messageHandler(self, willLoadDataForCategory: categoryNumber)
        }
        // clear the category array in preparation of reload
        //category.dataItems = []
    }
    
    func loadItemDetailsFromWeb( _ href: String, forCategory category: Int16 ) {
        let url = URL(string: href) // of the form: http://www.bait-tov.com/store/pic.php?ID=6110s1006 for item ID 6110s1006
        categoryNumber = Int(category) // TBD - should this be Int16 internally tho?
        let config = WKWebViewConfiguration()
        let scriptURL = Bundle.main.path(forResource: "getItemDetails", ofType: "js")
        let scriptContent = try? String(contentsOfFile:scriptURL!, encoding:String.Encoding.utf8)
        let script = WKUserScript(source: scriptContent!, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        config.userContentController.addUserScript(script)
        config.userContentController.add(self, name: itemDetailsMessage)
        internalWebView = WKWebView(frame: CGRect.zero, configuration: config)
        internalWebView!.load(URLRequest(url: url!))
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
                            if let delegate = delegate {
                                delegate.messageHandler(self, receivedData: category, forCategory: categoryNumber)
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
                            if let delegate = delegate {
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

    /* FOR STUDY: (both innerText and innerHTML, split by lines, between "{{" and "}}"):
     NEW!!!!  *&^*&^*&^ Attempting to load details for http://www.bait-tov.com/store/pic.php?ID=6110s1228
     BT item = {{TEXT:
           In Stock 2.15 US $
     2014 Hospitallers - Malta Joint Issue
     
     28.1.2014/Ronen Goldberg/p933/15s 5t/leaflet 938/
     
     RELATED ITEMS
     First Day Cancel: Israel-Malta@Acre
     Joint Issue: Malta Stamp
     
     THE HALLS OF THE KNIGHTS HOSPITALLERS IN ACRE,ISRAEL AND VALLETTA, MALTA - Joint Issue Israel-Malta
     
     The year 2014 marks 50 years of diplomatic relations between Israel and Malta. Israel, which was still a young country when relations were established in 1964, shared the knowledge and experience it accrued during its 16 years of independence with Malta.
     
     The relationship between these two peoples is ancient and special: friendly and cooperative relations between the Jewish people and the Phoenicians, the ancient inhabitants of Malta, were mentioned in the Bible - the Book of Books, which is extremely significant to both peoples.
     
     There was apparently already a Jewish community in Malta before the Christian era and during the Middle Ages it is estimated that Jews made up approximately one third of the population of Mdina, which was the island's capital at that time.
     
     The heroic efforts by Malta's residents in resisting the Nazi enemy and their proud stance in face of heavy bombings and siege were warmly appreciated by the Jewish Yishuv in Eretz Israel, many of whom took part in the fight against the Nazis who annihilated one third of the Jewish people during the Holocaust.
     
     The two countries share a commitment to democracy and democratic values, as well as the same parliamentary system and they are also similar culturally, geographically and linguistically.
     
     Relations between the two countries and their peoples continue to flourish in the areas of trade, technology, science, energy, culture and tourism.
     
     
     The Order of the Knights Hospitaller, also known as the Order of the Hospitallers of St. John of Jerusalem, developed in Jerusalem in the early 12th century around the church hospital building located south of the Church of the Holy Sepulchre. Members of the Order swore to dedicate their lives to helping Christian pilgrims who came to Jerusalem during the Crusader period, to provide them with medical care and to protect them from bandits and attackers along their route. In 1187, following the Crusader defeat in the Battle of Hattin, the Hospitaller's were forced to leave Jerusalem and moved to Acre.
     
     The city of Acre served as the capital of the Crusader kingdom from 1191-1291. The city was divided into quarters which were inhabited by the military Orders (the Hospitallers, the Templers and the Teutonics) and the Italian commercial communes. Each of these groups built grand buildings within its own area, reflecting Acre's status as one of the most important cities in the world at the time. The Knights' Halls built by the Hospitallers in Acre were unearthed in archeological excavations and have become a popular tourist site.
     
     The most impressive building in the complex is the Order of the Knights Hospitallers' dining room (the refectory). Its domes and arches intersect in the gothic style that developed in France and Italy in the 12th century and also appeared in Acre during that period.
     
     In 1291, Acre was conquered by the Mamluks, led by Kalavun, and completely destroyed. The Hospitallers resided in Cyprus for some 20 years until they conquered the island of Rhodes from pirates in 1310, and there established their center. They fortified the island, defending it against Muslim attacks, and lived there for some 200 years until they were forced out by the Turks.
     
     In 1530 the Hospitallers were granted control of the island of Malta by Roman Emperor Charles V and founded a sovereign state. The members of the Order, led by Jean Parisot de Valette, were widely praised when they successfully prevented Malta from being conquered and withstood the lengthy siege the Turks imposed upon the island.
     
     After driving out the Turks, the Hospitallers founded a new city called Valletta, in honor of their leader, where they constructed a series of magnificent buildings. On the edge of the city, overlooking the Port of Valletta, they built a sophisticated hospital where dedicated members of the order treated hundreds of wounded and ill. Today the building serves as the Mediterranean Conference Centre, which can accommodate 1400 visitors in modern halls that preserve a sense of the past.
     
     Description of the Stamp and the First Day Cover
     
     The stamp: on the right - the Hospitallers' refectory in Acre (photograph: www.goisrael.com); on the left - one of the halls in the Hospitaller Hospital in Valletta.
     The first day cover: on the right - a section of the sea wall in Acre (Photograph: www.shutterstock.com) ; on the left: a section of the port fortifications in Valletta.
     
     
     
     This item appears in the following topics:
       Philately and Post\Joint Issues
       Flags
       Israel Settlements\Acre
     }}
     {{HTML:
     
     <div dir="LTR">
     <a href="pic.php?ID=6110s1225"><img src="../images/previous.gif" alt="Previous" title="Previous"></a>
     <a href="pic.php?ID=6110s1229"><img src="../images/next.gif" alt="Next" title="Next" hspace="8"></a>
     &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="javascript:history.go(-1)"><img src="../images/back.gif" alt="Back" title="Back" hspace="8"></a>
     <font color="GREEN">In Stock</font>
     2.15 US $ <a href="cart2.php?Action=Add&amp;Prod=6110s1228&amp;Which=Price"><img src="../images/cart1.gif" border="1" align="bottom" hspace="8" alt="Add to cart" title="Add to cart"></a> <a href="../atlas/atlas.php?Code=6110" target="Main"><img src="../atlas/flags/f6110.gif" border="0" align="BOTTOM" height="28"></a>
     </div>
     <table cellspacing="0" cellpadding="0" border="0">
     
     <tbody><tr><td class="DatE" align="CENTER"><b>2014 Hospitallers - <font color="purple">Malta Joint Issue</font></b></td></tr>
     
     <tr><td><img src="products/6110s1228.jpg"></td></tr>
     
     </tbody></table>
     
     28.1.2014/Ronen Goldberg/p933/15s 5t/leaflet 938/<br>
     <br>
     RELATED ITEMS<br>
     <li>First Day Cancel: <a href="pic.php?ID=ec14005">Israel-Malta@Acre</a><br>
     </li><li>Joint Issue: <a href="pic.php?ID=6110j1228">Malta Stamp</a><br>
     <br>
     <u>THE HALLS OF THE KNIGHTS HOSPITALLERS IN ACRE,ISRAEL AND VALLETTA, MALTA</u> - Joint Issue Israel-Malta<br>
     <br>
     The year 2014 marks 50 years of diplomatic relations between Israel and Malta. Israel, which was still a young country when relations were established in 1964, shared the knowledge and experience it accrued during its 16 years of independence with Malta. <br>
     <br>
     The relationship between these two peoples is ancient and special: friendly and cooperative relations between the Jewish people and the Phoenicians, the ancient inhabitants of Malta, were mentioned in the Bible - the Book of Books, which is extremely significant to both peoples. <br>
     <br>
     There was apparently already a Jewish community in Malta before the Christian era and during the Middle Ages it is estimated that Jews made up approximately one third of the population of Mdina, which was the island's capital at that time. <br>
     <br>
     The heroic efforts by Malta's residents in resisting the Nazi enemy and their proud stance in face of heavy bombings and siege were warmly appreciated by the Jewish Yishuv in Eretz Israel, many of whom took part in the fight against the Nazis who annihilated one third of the Jewish people during the Holocaust. <br>
     <br>
     The two countries share a commitment to democracy and democratic values, as well as the same parliamentary system and they are also similar culturally, geographically and linguistically. <br>
     <br>
     Relations between the two countries and their peoples continue to flourish in the areas of trade, technology, science, energy, culture and tourism.<br>
     <br>
     <br>
     <b>The Order of the Knights Hospitaller</b>, also known as the Order of the Hospitallers of St. John of Jerusalem, developed in Jerusalem in the early 12th century around the church hospital building located south of the Church of the Holy Sepulchre. Members of the Order swore to dedicate their lives to helping Christian pilgrims who came to Jerusalem during the Crusader period, to provide them with medical care and to protect them from bandits and attackers along their route. In 1187, following the Crusader defeat in the Battle of Hattin, the Hospitaller's were forced to leave Jerusalem and moved to Acre.<br>
     <br>
     The city of Acre served as the capital of the Crusader kingdom from 1191-1291. The city was divided into quarters which were inhabited by the military Orders (the Hospitallers, the Templers and the Teutonics) and the Italian commercial communes. Each of these groups built grand buildings within its own area, reflecting Acre's status as one of the most important cities in the world at the time. The Knights' Halls built by the Hospitallers in Acre were unearthed in archeological excavations and have become a popular tourist site.<br>
     <br>
     The most impressive building in the complex is the Order of the Knights Hospitallers' dining room (the refectory). Its domes and arches intersect in the gothic style that developed in France and Italy in the 12th century and also appeared in Acre during that period.<br>
     <br>
     In 1291, Acre was conquered by the Mamluks, led by Kalavun, and completely destroyed. The Hospitallers resided in Cyprus for some 20 years until they conquered the island of Rhodes from pirates in 1310, and there established their center. They fortified the island, defending it against Muslim attacks, and lived there for some 200 years until they were forced out by the Turks. <br>
     <br>
     In 1530 the Hospitallers were granted control of the island of Malta by Roman Emperor Charles V and founded a sovereign state. The members of the Order, led by Jean Parisot de Valette, were widely praised when they successfully prevented Malta from being conquered and withstood the lengthy siege the Turks imposed upon the island.<br>
     <br>
     After driving out the Turks, the Hospitallers founded a new city called Valletta, in honor of their leader, where they constructed a series of magnificent buildings.  On the edge of the city, overlooking the Port of Valletta, they built a sophisticated hospital where dedicated members of the order treated hundreds of wounded and ill. Today the building serves as the Mediterranean Conference Centre, which can accommodate 1400 visitors in modern halls that preserve a sense of the past.<br>
     <br>
     <b>Description of the Stamp and the First Day Cover<br>
     <br>
     The stamp:</b> on the right - the Hospitallers' refectory in Acre (photograph: www.goisrael.com); on the left - one of the halls in the Hospitaller Hospital in Valletta. <br>
     <b>The first day cover:</b> on the right - a section of the sea wall in Acre (Photograph: www.shutterstock.com) ; on the left: a section of the port fortifications in Valletta. <br>
     <br>
     
     
     <br><br><div style="direction:ltr;text-align:left"><span style="color:green">This item appears in the following topics: </span><br>&nbsp;&nbsp;<font color="black">Philately and Post</font>\Joint Issues<br>&nbsp;&nbsp;Flags <br>&nbsp;&nbsp;Israel Settlements\Acre<br></div>
     
     
     
     
     
     </li>}}
     */
    /*
     VARIOUS INSIGHTS (7/2017):
     0. This level of detail is ONLY in category 2 (sets/S/S/FDC) - therefore the protocol will only get messages if it is passed for category 2 (so far)
     1. Someone has lovingly entered the text of all the leaflets and continues to do so. This is where the big articles come from.
     2. The info is on the 4th line of text, and looks the same in the DOM structure.
     3. The second line of text has the full title, including the "Souvenir Sheet" disclaimer, if any (also "Joint Issue" annotation, sometimes both - see Greenland or Vatican)
     4. Of the fields of the info line, each can include multiples separated by commas, e.g. see Alphabet set (s796) for two sheet formats and two plate numbers (the 'p' is not duplicated, and there are no spaces with the commas)
     5. The HTML shows that proper parsing of the RELATED ITEMS list (when present) should show the ID codes for all related FD cancels (pic IDs), related joint items, special sheets, varieties, the works!
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
                let infoData = infoLine.components(separatedBy: "/")
                // processing needed to make sure we have all possible lines all the time
                // typically, bulletin and/or leaflet line will be missing - will all dates be there? who knows?
                // if we're a Souvenir Sheet (see lines[1]), the plate number line is replaced by a size line in cm (HxW, floating point with 1 decimal optional) (so far, no S/S has a plate number...)
                // create a dictionary using the following headers (all data are strings):
                //  "ssCount" = 0/1/2/3/+? (souvenir sheet count) -- sometimes it says "N Souvenir Sheets" for N==3 or ...
                //  "jointWith" = XXX (joint issue partner, or blank if none)
                //  "plateNumbers" = NNN (CSV plate number list*) - always pure numbers with a 'p' at the front, no spaces (EXCEPT Stand-by issues have no p# but are listed as 'p--'; this is flagged in the title as "Stand-By"
                //  "bulletins" = BBB (CSV bulletin number list*) - bulletins as marked so some can have a suffix like 259a for s255 (25th Independence); these went away after the early '80s so the field is optional, empty if not present
                //  "leaflets" = LLL (CSV leaflet number list*) - these weren't available in the early years, so field is optional and empty if not present, but see s88 (leaflet (0)) or s91 "leaflet none" (and "bulletin ??")
                //  "ssWidth" = WW.W (souv.sheet width dimension in cm)
                //  "ssHeight" = HH.H (souv.sheet height dimension in cm)
                //  "designers" = DDDDD (designer name(s))
                //  "issueDates" = DD.MM.YYYY (date of issue, I think) - this is sometimes a date range separated by '-' (see for example Landscapes I and II (s234) or Coins Mered (s23)
                // NOTE: sheet format variation on s738-9 Flag 1st SA - uses 40s (4t) 
                //  "numStamps" = NN (sheet format, number of stamps per sheet, except in case of "3 Souvenir Sheets" like Jerusalem '73 where it's still 3 in the set, but for 3 sheets, it's like 10s 5t, the single sheet format (!)
                //  "numTabs" = TT (sheet format, number of tabs)
                //  "setCardinality" = N for purposes of splitting, how many things are in this set? diff.#s needed for set, FDC, and sheet, but we can't really tell here, so just one guess (or can we?)
                //     for now, I would define it as the number of plate numbers present, and if no P# line, then the # of S/S
                // * These CSV lists should be normalized to include all values, separated by commas, instead of the shorthand method used by the website; parse something like "255-7,263,279-81" into "255,256,257,263,279,280,281"
                //    NOTE: remember bulletins can have non-numeric suffixes too, and maybe the early leaflets too; see Morgenstein for the excruciating details!
                if let delegate = delegate {
                    let info = [ "xtitle": titleLine, "info": infoData.joined(separator: "||") ] // temporary placeholder version
                    delegate.messageHandler(self, receivedData: info as AnyObject, forCategory: categoryNumber)
                }
            }
        }
    }

}
