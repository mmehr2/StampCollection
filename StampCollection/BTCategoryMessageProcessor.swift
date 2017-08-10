//
//  BTCategoryMessageProcessor.swift
//  StampCollection
//
//  Created by Michael L Mehr on 8/9/17.
//  Copyright © 2017 Michael L. Mehr. All rights reserved.
//

// NOTES FROM getCategories.js:
// For parsing Bait-tov.com's SubCategories page
// There are two TR elements that should be ignored (1st two), followed by the header row, and then the actual categories
// The 1st is the "Browsing Category" line (with total item count - useful?
// The 2nd is the "Sub Categories" title line
// The 3rd (parseable) should show three headers, "#", "Name" and "Items" (2015 March)
// The 4th - Nth are the actual lines, with a category number, name, and item count
// Current structure tho is the # is the innerHTML of the 1st TD
//   The Name TD contains an A element with an HREF property that has the SubCat=# (important) and
//     its innerHTML has a <font> element whose innerHTML is the actual name
//   The Items value is the innerHTML of the 3rd TD

// SWIFT PORTING NOTES:
/*
 The JS file would be injected and run on all frames of the webpage. But here we don't need to parse the frame we want.
    The current page is loaded without a frame.
 Its body contains two tables: the first contains just the first row with "Browsing Category: 'Israel Stamps'   Total 17936 Items"
 We want the second table, which has two header rows (one with just the words "Sub Categories"), we want the second with 3 names.
 These two rows are followed by all (currently 28) data rows, with the #, Name, and Items count for each.
 The Name column is an anchor field, and we want the text as well as the href.
 These need to be constructed into a Dictionary with two entries:
    tableCols - an Array<String> with the header names
    tableRows - an Array of Dictionary; each dictionary contains one row's contents; the keys are the header names (plus "href")
 */

import Foundation
import SwiftSoup

fileprivate let BTBaseURL = "http://www.bait-tov.com/store/"

class BTCategoryMessageProcessor: BTMessageProcessor {
    
    var delegate: BTSiteMessageHandler?
    
    init(_ del: BTSiteMessageHandler?) {
        delegate = del
    }
    
    func processWebData(_ html: String) {
        // run the simulated Javascript or just SwiftSoup logic here
        guard let doc = try? SwiftSoup.parse(html, BTBaseURL) else {
            print("Unable to parse the received Categories page HTML string")
            return
        }
        do {
            //print("Parsing Category message:")
            var result: BTSiteMessage = [:]
            var headers : [String] = []
            var data : [BTSiteData] = []
            let tables = try doc.select("table").array()
            guard tables.count > 1 else {print("Page doesn't have at least two tables"); return}
            let rows = try tables[1].getElementsByTag("tr").array()
            guard rows.count > 2 else {print("Second table has only \(rows.count) < 3 rows - no data"); return}
            for (rindex, row) in rows.enumerated() {
                // skip row 0 entirely, it just says "Sub Categories"
                if rindex == 0 {
                    continue
                }
                let cols = try row.getElementsByTag("td").array()
                if rindex == 1 {
                    for col in cols {
                        //process header name column into next element of headers array
                        let hname = try col.text()
                        headers.append(hname)
                    }
                    //print("Categories message - found header row: \(headers)")
                } else if rindex > 1 {
                    // process another data row into another Dictionary element of data array
                    var dataRow: BTSiteData = [:]
                    var href = ""
                    for (cindex, col) in cols.enumerated() {
                        let key = headers[cindex]
                        let value = try col.text()
                        if cindex == 1 {
                            // the Name field contains an anchor element with the href we want
                            if let anchor = try col.select("a").array().first {
                                let hrefText = try anchor.attr("href")
                                href = BTBaseURL + hrefText
                            } else {
                                print("Category data row \(rindex+1) contained no href field.")
                            }
                        }
                         dataRow[key] = value
                    }
                    dataRow["href"] = href
                    data.append(dataRow)
                    //print("Categories message - found data row: \(dataRow)")
                }
            }
            // assemble the output message
            result["tableCols"] = headers
            result["tableRows"] = data
            // send message to delegate if present
            if let delegate = delegate {
                delegate.setParseResult(result, forMessage: BTCategoriesMessage)
            }
        } catch Exception.Error(let type, let message) {
            print("Category parsing exception (type \(type)): \(message)")
        } catch {
            print("Unknown Category parsing exception")
        }
    }
}
