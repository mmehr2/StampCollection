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
                        // Due to library parsing, the first line of body text mashes together the header, title, and info lines, as well as all subsequent text (including the contents of the info folder)
                        let elements = try body.text().components(separatedBy: "\n")
                        if let elmtx1 = elements.first {
                            // find the title as a literal regex pattern (escape all special regex characters in the input like '-' and '()')
                            let litTitle = escapeAllRegexCharacters(title)
                            let matches1 = matches(for: litTitle, in: elmtx1)
                            if matches1.count > 0 {
                                let rr = matches1[0]
                                // start after that, skipping a space, and run to the end, minus any final space and '\r' CR chars
                                let startField = elmtx1.index(after: rr.upperBound)
                                var endField = elmtx1.endIndex
                                let substr2 = String(elmtx1[startField...])
                                let matches2 = matches(for: "[A-Z][A-Z][A-Z]", in: substr2)
                                if matches2.count > 0 {
                                    // possibly terminate string with 3 UC characters, if found AFTER the initial startField position
                                    let rr2 = matches2[0]
                                    endField = elmtx1.index(startField, offsetBy: substr2.distance(from: substr2.startIndex, to: substr2.index(before: rr2.lowerBound)))
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
