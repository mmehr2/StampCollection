//
//  BTItemDetailsMessageProcessor.swift
//  StampCollection
//
//  Created by Michael L Mehr on 8/12/17.
//  Copyright © 2017 Michael L. Mehr. All rights reserved.
//

import Foundation
import SwiftSoup

class BTItemDetailsMessageProcessor: BTMessageProcessor {
    
    private var delegate: BTSiteMessageHandler?
    
    init(_ del: BTSiteMessageHandler?) {
        delegate = del
    }
    
    func processWebData(_ html: String) {
        // run the simulated Javascript or just SwiftSoup logic here
        var result: BTSiteMessage = [:]
        var title = ""
        var info = ""
        if let doc = try? SwiftSoup.parse(html, BTBaseURL) {
            do {
                //print("Parsing Category message:")
                if let body = doc.body()  {
                    //                let text = try body.text()
                    //                print("Body text is:\(text)")
                    let children = body.children().array()
                    if children.count <= 4 {
                        print("Item Details Message body has less than 5 elements to parse.")
                    } else {
                        // title extraction
                        let elmt1 = try body.select("td").array().first
                        let elmt2 = children[1]
                        let title1 = try elmt1?.text()
                        let title2 = try elmt2.text()
                        title = title1 ?? title2
                        // info extraction
                        // Due to library parsing, the first line of body text mashes together the header, title, and info lines
                        let elements = try body.text().components(separatedBy: "\n")
                        if let elmtx1 = elements.first {
                            // find the title
                            if let rr = elmtx1.range(of: title) {
                                // start after that, skipping a space, and run to the end, minus any final space and '\r' CR chars
                                let startField = elmtx1.index(after: rr.upperBound)
                                var endField = elmtx1.endIndex
                                if let rr2 = elmtx1.range(of: "RELATED ITEMS") {
                                    // possibly terminate string with RELATED ITEMS section, if included
                                    endField = elmtx1.index(before: rr2.lowerBound)
                                    info = String(elmtx1[startField..<endField])
                                } else {
                                    info = elmtx1[startField..<endField].trimmingCharacters(in: CharacterSet(charactersIn: " \r"))
                                }
                            }
                        }
                    }
                }
            } catch Exception.Error(let type, let message) {
                print("Item Details parsing exception (type \(type)): \(message)")
            } catch {
                print("Unknown Item Details parsing exception")
            }
        } else {
            print("Unable to parse the received Item Details page HTML string")
        }
        // assemble the output message
        result["title"] = title
        result["info"] = info
        // send message to delegate if present
        if let delegate = delegate {
            //                print("Posted Category \(categoryNumber) parse message with \(data.count) items, \(noteStrings.count) notes, and \(headers.count) headers.")
            delegate.setParseResult(result, forMessage: BTItemDetailsMessage)
        }
    }

}
