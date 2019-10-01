//
//  BTItemsMessageProcessor.swift
//  StampCollection
//
//  Created by Michael L Mehr on 8/9/17.
//  Copyright © 2017 Michael L. Mehr. All rights reserved.
//

// NOTES FROM getItems.js:
// For parsing any of the 28 Bait-tov.com's Product Details pages
// Basic structure is in nested tables contained within a frame with name = "ProdDetails"
// All tables are contained within a master anonymous table of one row and column
// The MASTER table is further divided into subtables as follows
//   HEADER1,2 (tables with loading warning and banner, for alignment)
//   NOTES (table with images and bulleted list items, including catalog names if catalog fields are present)
//   DATA1 - DATAn (tables of data of fixed length of 20 items (or less on last table), as many as needed)
//   FOOTER (table within table to show page number(s) at bottom)
// This means the page count should be 6 + data table count; the first 3 tables can be ignored, 4 is NOTES, 5 is first data, and N-1 and N are FOOTER tables
//
// The HEADER has images and text of the form "What can be purchased in our store from the category 'X'"
// The NOTES contains one row, with three cells; the first and last cell contain images, but the second contains bulleted list items (LI)
// The first row of the first DATA table contains the column design for the page
// This row has cells that fall into the following categories
//   Item Code (always present) - a short string of the form 6110s254A or similar
//   Description ( "   " ) - a description of possibly several lines, starting with a country flag image (ISRAEL if not Joint Issues)
//   Catalog (0, 1, or 2) - fields that contain catalog descriptors for the item row, if any
//   Price (1, 2, or 4) - fields that contain pricing info for up to 4 varieties of the item
//   Status (always present) - a short string describing item availability
//   Pic (always present) - either blank or an image anchor icon that will click to the picture display page associated with the item
// Then the table rows follow containing data items as described by the above headers (total number of rows should agree with category.items)
// This goes on until the FOOTER tables are encountered.


// SWIFT PORTING NOTES:
/*
 The web page loads inside a frameset of one frame with name "ProdDetails". The document that loads uses "proddet.php" in its src.
 The downloaded HTML text file does NOT seem to contain the details any more. Has the site been redesigned? Or does the frame injection feature of WKWebView save us and we need another mechanism to load this with URLSession?
 Yes, it turns out if we just download the "proddet.php" version directly, we can save the results to files as planned.
 Let the parsing begin!
 We can and should use the select("a > b") syntax to limit the tables list to those directly descended from the body's top table.
 This should work even with tables that contain tables way down (like the cancellations that use tables in the NOTES table).
 That way we can truly access the NOTES table and then the DATA tables properly.
 
 For NOTES scanning, we can directly access the <li> elements inside the table, get their text() directly, and append to a list. Then we can generate the final string by joining the substrings array using "\n".
 For DATA scanning, realize the first row of the data is always the headers row. There is no title row like in the Categories MP. Tables always have 20 rows or less (only the last one may be smaller), and each row contains the data we want. Be sure to pay attention to how getItems.js parses the Price fields (BUY links), including the OldPrice family.
 SPECIAL CASES:
 Category 11 (Forerunners) seems to violate the basic structure, having two empty tables directly attached to the body that contain the NOTES and FOOTER respectively. All other categories have these tables inside a single 1x1 table for alignment.
 */

import Foundation
import SwiftSoup

class BTItemsMessageProcessor: BTMessageProcessor {
    
    private var delegate: BTSiteMessageHandler?
    private var categoryNumber: Int
    private var isFooterRow = false
    
    init(_ del: BTSiteMessageHandler?, forCategory: Int) {
        delegate = del
        categoryNumber = forCategory
    }
    
    func processWebData(_ html: String) {
        // run the simulated Javascript or just SwiftSoup logic here
        guard let doc = try? SwiftSoup.parse(html, BTBaseURL) else {
            print("Unable to parse the received Category Items page HTML string")
            return
        }
        do {
            //print("Parsing Category message:")
            var result: BTSiteMessage = [:]
            var noteStrings : [String] = []
            var headers : [String] = []
            var headersInternal : [String] = []
            var data : [BTSiteData] = []
            if let mainTable = try doc.select("body > table").array().first {
                let tables = try mainTable.select("td > table").array()
                if tables.count > 3 {
                    var isFirst = true
                    // ignore 1st 2 tables (HEADER1,2), process 3rd for NOTES, 4th and beyond for headers (4th only) and data, ignore last (FOOTER)
                    // process the 3rd table for Note strings contained in <li> elements
                    noteStrings = try processNotesTable(tables[2])
                    // process the rest of the tables 3..N for data rows (and headers in the first row of the first table)
                    for (i, table) in tables[3..<tables.count].enumerated() {
                        // at most, one row (1st in 1st table) will contain columns with the header names we want
                        var rows = try table.getElementsByTag("tr").array()
                        if isFirst {
                            headers = try processHeaderRow(rows.first!, withPriceAddedFields: true)
                            headersInternal = try processHeaderRow(rows.first!, withPriceAddedFields: false)
                            isFirst = false
                            rows = Array(rows.dropFirst())
                        }
                        // all the rest, including the rest of the first table, except for the last table, will have rows that contain columns with neither class
                        let dataX = try processDataTableRows(rows, usingHeaders: headersInternal)
                        data += dataX
                        if isFooterRow {
                            print("Category \(categoryNumber) Footer detected in table \(i+4)/\(tables.count)")
                            break
                        }
                    }
                } else {
                    print("Category \(categoryNumber) Page doesn't have at least four tables")
                }
            } else {
                print("Category \(categoryNumber) Page does not have main table")
            }
            // assemble the output message
            result["notes"] = noteStrings.joined(separator: "\n")
            result["headers"] = headers
            result["items"] = data
            result["dataCount"] = data.count as NSNumber
            // send message to delegate if present
            if let delegate = delegate {
//                print("Posted Category \(categoryNumber) parse message with \(data.count) items, \(noteStrings.count) notes, and \(headers.count) headers.")
                delegate.setParseResult(result, forMessage: BTItemsMessage)
            }
        } catch Exception.Error(let type, let message) {
            print("Category \(categoryNumber) Items parsing exception (type \(type)): \(message)")
        } catch {
            print("Unknown Category \(categoryNumber) Items parsing exception")
        }
    }
    
    func processNotesTable(_ table: Element) throws -> [String] {
        var noteStrings : [String] = []
        let items = try table.getElementsByTag("li").array()
        for item in items {
            //process header name column into next element of headers array
            let note = try item.text()
            noteStrings.append(note)
        }
        return noteStrings
    }
    
    func getBuyHeader(_ priceHeader: String) -> String {
        return priceHeader.replacingOccurrences(of: "Price", with: "Buy")
    }
    
    func getOldPriceHeader(_ priceHeader: String) -> String {
        return "Old" + priceHeader
    }
    
    func processHeaderRow(_ row: Element, withPriceAddedFields: Bool) throws -> [String] {
        var headers : [String] = []
        let cols = try row.getElementsByTag("td").array()
        for col in cols {
            //process header name column into next element of headers array
            let hname = try col.text()
            var txname = hname
            var priceAdded = false
            if hname.hasPrefix("Item Code") { txname = "ItemCode" }
            else if hname.hasPrefix("Price (FDC)") { txname = "PriceFDC"; priceAdded = true }
            else if hname.hasPrefix("Price (Used)") { txname = "PriceUsed"; priceAdded = true }
            else if hname.hasPrefix("Price (Other)") { txname = "PriceOther"; priceAdded = true }
            else if hname.hasPrefix("Catalog #1") { txname = "Catalog1" }
            else if hname.hasPrefix("Catalog #2") { txname = "Catalog2" }
            else if hname.hasPrefix("Price") { txname = "Price"; priceAdded = true }
            headers.append(txname)
            if withPriceAddedFields && priceAdded {
                // for every Price field, add a Buy field and an OldPrice field of the same time
                let buyname = getBuyHeader(txname)
                headers.append(buyname)
                let oldname = getOldPriceHeader(txname)
                headers.append(oldname)
            }
        }
        return headers
    }
    
    func parsePriceData(_ col: Element) throws -> (String, String, String) {
        var result = ""
        var buy = ""
        var oldp = ""
        // get anchor href, if any, for buy field
        let anchors = try col.getElementsByTag("a")
        if let anchor = anchors.array().first {
            buy = try anchor.attr("href")
        }
        // get strikeout text, if any, for old price field
        let strikes = try col.getElementsByTag("strike")
        if let strike = strikes.array().first {
            oldp = try strike.text()
        }
        // remove strikeout and anchor from general price field
        try anchors.remove()
        try strikes.remove()
        result = try col.text()
        return (result, buy, oldp)
    }
    
    func parsePicData(_ col: Element) throws -> String {
        var result = ""
    // Typical Pic = "<img src=\"../images/nil.gif\" height=\"1\" width=\"40\"><br><a href=\"#\" onclick=\"PRODPIC = open('pic.php?ID=6110e144B','PRODPIC','resizable=yes,scrollbars=yes,height=400,width=450'); PRODPIC.focus(); return false;\"><img src=\"../images/cam.gif\" border=\"0\"></a>";
        // So, find the <a> element, get its onclick attr(), and process by getting the string starting 'pic and ending with a '
        if let anchor = try col.getElementsByTag("a").array().first {
            let picref = try anchor.attr("onclick")
            if let range = picref.range(of: "\'pic[^\']*\'", options: .regularExpression) {
                let si = picref.index(after: range.lowerBound) // ignore leading quote
                let se = picref.index(before: range.upperBound) // ignore trailing quote
                let picurl = picref[si..<se]
                result = String(picurl)
            }
        }
        return result
    }
    
    func processDataTableRows(_ rows: [Element], usingHeaders headers:[String]) throws -> [BTSiteData] {
        var data : [BTSiteData] = []
        for (_, row) in rows.enumerated() {
            isFooterRow = false
            let cols = try row.getElementsByTag("td").array()
            // process another data row into another Dictionary element of data array
            var dataRow: BTSiteData = [:]
            for (cindex, col) in cols.enumerated() {
                let className = try col.className()
                if className.hasPrefix("Header") {
                    isFooterRow = true
                    // ignore rest of row because class name isn't always directly on column (sometimes on style tag)
                    break
                }
                let key = headers[cindex]
                var value = try col.text()
                // do any special processing of the column Element
                switch(key) {
                case "Pic":
                    // this needs to have special parsing to get the pic ID
                    value = try parsePicData(col);
                    break
                case "Price", "PriceFDC",
                 "PriceUsed", "PriceOther":
                    // need to parse out any <STRIKE> item price and <A> buy anchor, remember what's left
                    let (price, buyref, oldprice) = try parsePriceData(col);
                    let buykey = getBuyHeader(key)
                    dataRow[buykey] = buyref
                    let oldpricekey = getOldPriceHeader(key)
                    dataRow[oldpricekey] = oldprice
                    value = price
                    break
                default:
                    break
                }
                dataRow[key] = value
            }
            if isFooterRow {
                break // don't save this row or later in table if it's a footer
            }
            data.append(dataRow)
            //print("Categories message - found data row: \(dataRow)")
        }
        return data
    }
    
}
