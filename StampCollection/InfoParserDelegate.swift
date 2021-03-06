//
//  InfoParserDelegate.swift
//  StampCollection
//
//  Created by Michael L Mehr on 4/9/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import Foundation


protocol CSVDataSink {
    // parser (via its delegate) will call this once for every data item (CSV data line) that has completed parsing
    func parserDelegate( _ parserDelegate: CHCSVParserDelegate,
        foundData data: [String : String],
        inContext token: CollectionStore.ContextToken)
    
    // parser (via its delegate) will call this once at startup to determine if adding sequence info is needed
    // if so, return true and set the inout properties to reflect the starting count and property name to add to each data record
    // the automatically advancing sequence number will be added to each object dictionary returned using the property name provided, starting at the provided count
    func parserDelegate( _ parserDelegate: CHCSVParserDelegate,
        shouldAddSequenceData seqname: inout String,
        fromCount start: inout Int,
        inContext token: CollectionStore.ContextToken) -> Bool
}


class InfoParserDelegate: NSObject, CHCSVParserDelegate {
    let name : String
    let progress : Progress
    var recordCount = 0
    var lastRecordNumber = -1
    fileprivate var currentRecordNumber = -1
    var fieldCount = 0
    var headers : [String] = []
    //typealias RecordType = [String:String]
    fileprivate var currentRecord : [String:String] = [:]
    var records : [[String:String]] = []
    var dataSink : CSVDataSink?
    var contextToken: CollectionStore.ContextToken = 0 // must be set before usage!
    var sequencePropertyName : String?
    var sequenceCounter = 0
    
    init(name name_: String, progress progress_: Progress) {
        // NOTE: for the reasoning about the bug in Swift 2/XCode 7 regarding errors in calling this, see here: http://stackoverflow.com/questions/32658812/string-literals-in-lazy-vars-in-swift-2-xcode-7-cannot-convert-value-of-type
        name = name_
        progress = progress_
        super.init()
    }
    
    @nonobjc func parser(_ parser: CHCSVParser!, didFailWithError error: NSError!) {
        let errDesc = error?.localizedDescription ?? "?unknown parser error?"
        print("Failed parsing \(name) with error \(errDesc)")
    }

    func parserDidBeginDocument(_ parser: CHCSVParser!) {
        recordCount = 0
        fieldCount = 0
        // set up automatic data sequencing feature if told to
        if let dataSink = dataSink {
            var propertyName = ""
            var seqCountStart = 0
            let should = dataSink.parserDelegate(self, shouldAddSequenceData: &propertyName, fromCount: &seqCountStart, inContext: contextToken)
            if should {
                sequenceCounter = seqCountStart
                sequencePropertyName = propertyName
            } else {
                sequencePropertyName = nil
            }
        }
    }

    func parser(_ parser: CHCSVParser!, didBeginLine recordNumber: UInt) {
        currentRecordNumber = Int(recordNumber)
        currentRecord = [:]
    }
    
    func parser(_ parser: CHCSVParser!, didReadField field: String!, at fieldIndex: Int) {
        if currentRecordNumber == 1 {
            // each field is a new header name
            headers.append(field)
        } else {
            // create the data object (dictionary) one field at a time
            let hname = headers[fieldIndex]
            //println("\(name)[\(currentRecordNumber)].\(hname) <= \(field)")
            currentRecord[hname] = field
            currentRecord.updateValue(field, forKey: hname)
        }
    }
    
    func parser(_ parser: CHCSVParser!, didEndLine recordNumber: UInt) {
        if currentRecordNumber == 1 {
            print("\(name) Headers: \(headers)")
        } else if !currentRecord.isEmpty {
            // add extra (non-input) field for sequence data, if enabled
            if let propertyName = sequencePropertyName {
                currentRecord[propertyName] = "\(sequenceCounter)"
                sequenceCounter += 1
            }
            //records.append(currentRecord) // not needed in CoreData version, I believe
            //println("\(name)[\(currentRecordNumber)] = \(currentRecord)")
            if let dataSink = dataSink {
                dataSink.parserDelegate(self, foundData: currentRecord, inContext: contextToken)
            }
            progress.completedUnitCount += 1 // don't count the header line
        }
        recordCount += 1
        lastRecordNumber = Int(recordNumber)
    }
    
    func parserDidEndDocument(_ parser: CHCSVParser!) {
        print("Finished parsing \(name) with \(recordCount) records ending with #\(lastRecordNumber)")
    }
}

