//
//  InfoParserDelegate.swift
//  StampCollection
//
//  Created by Michael L Mehr on 4/9/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import Foundation

protocol InfoParseable {
    func parserDelegate( parserDelegate: CHCSVParserDelegate, foundData data: [String : String])
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
    
    init( namex: String ) {
        name = namex
    }
    
    func parser(parser: CHCSVParser!, didFailWithError error: NSError!) {
        println("Failed parsing \(name) with error \(error)")
    }

    func parserDidBeginDocument(parser: CHCSVParser!) {
        recordCount = 0
        fieldCount = 0
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
            records.append(currentRecord)
            //println("\(name)[\(currentRecordNumber)] = \(currentRecord)")
            if let dataSink = dataSink {
                dataSink.parserDelegate(self, foundData: currentRecord)
            }
            
        }
        ++recordCount
        lastRecordNumber = Int(recordNumber)
    }
    
    func parserDidEndDocument(parser: CHCSVParser!) {
        println("Finished parsing \(name) with \(recordCount) records ending with #\(lastRecordNumber)")
    }
}

