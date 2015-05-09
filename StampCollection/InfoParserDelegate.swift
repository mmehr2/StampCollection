//
//  InfoParserDelegate.swift
//  StampCollection
//
//  Created by Michael L Mehr on 4/9/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import Foundation


protocol InfoParseable {
    // parser (via its delegate) will call this once for every data item (CSV data line) that has completed parsing
    func parserDelegate( parserDelegate: CHCSVParserDelegate,
        foundData data: [String : String],
        inContext token: CollectionStore.ContextToken)
    
    // parser (via its delegate) will call this once at startup to determine if adding sequence info is needed
    // if so, return true and set the inout properties to reflect the starting count and property name to add to each data record
    // the automatically advancing sequence number will be added to each object dictionary returned using the property name provided, starting at the provided count
    func parserDelegate( parserDelegate: CHCSVParserDelegate,
        inout shouldAddSequenceData seqname: String,
        inout fromCount start: Int,
        inContext token: CollectionStore.ContextToken) -> Bool
}


class InfoParserDelegate: NSObject, CHCSVParserDelegate {
    let name : String
    var recordCount = 0
    var lastRecordNumber = -1
    private var currentRecordNumber = -1
    var fieldCount = 0
    var headers : [String] = []
    //typealias RecordType = [String:String]
    private var currentRecord : [String:String] = [:]
    var records : [[String:String]] = []
    var dataSink : InfoParseable?
    var contextToken: CollectionStore.ContextToken = 0 // must be set before usage!
    var sequencePropertyName : String?
    var sequenceCounter = 0
    
    init(name namex: String) {
        name = namex
    }
    
    func parser(parser: CHCSVParser!, didFailWithError error: NSError!) {
        println("Failed parsing \(name) with error \(error)")
    }

    func parserDidBeginDocument(parser: CHCSVParser!) {
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

    func parser(parser: CHCSVParser!, didBeginLine recordNumber: UInt) {
        currentRecordNumber = Int(recordNumber)
        currentRecord = [:]
    }
    
    func parser(parser: CHCSVParser!, didReadField field: String!, atIndex fieldIndex: Int) {
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
    
    func parser(parser: CHCSVParser!, didEndLine recordNumber: UInt) {
        if currentRecordNumber == 1 {
            println("\(name) Headers: \(headers)")
        } else if !currentRecord.isEmpty {
            // add extra (non-input) field for sequence data, if enabled
            if let propertyName = sequencePropertyName {
                currentRecord[propertyName] = "\(sequenceCounter++)"
            }
            //records.append(currentRecord) // not needed in CoreData version, I believe
            //println("\(name)[\(currentRecordNumber)] = \(currentRecord)")
            if let dataSink = dataSink {
                dataSink.parserDelegate(self, foundData: currentRecord, inContext: contextToken)
            }
            
        }
        ++recordCount
        lastRecordNumber = Int(recordNumber)
    }
    
    func parserDidEndDocument(parser: CHCSVParser!) {
        println("Finished parsing \(name) with \(recordCount) records ending with #\(lastRecordNumber)")
    }
}

