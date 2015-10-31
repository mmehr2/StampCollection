//
//  BTImportExport.swift
//  StampCollection
//
//  Created by Michael L Mehr on 5/21/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import Foundation
import UIKit

private let nameOfCategoryFile = "BTCATS.CSV"
private let nameOfInfoFile = "BTINFO.CSV"

private func getFile(name: String) -> NSURL {
    let ad = UIApplication.sharedApplication().delegate! as! AppDelegate
    return ad.applicationDocumentsDirectory.URLByAppendingPathComponent(name)
}

// MARK: data import
class BTImporter: CSVDataSink {
    
    lazy private var infoParser: InfoParserDelegate = InfoParserDelegate(name: "BTINFO")
    
    lazy private var categoryParser: InfoParserDelegate = InfoParserDelegate(name: "BTCATS")
    
    
    private var categories: [Int:BTCategory] = [:]
    
    // MARK: data access
    
    func getJSCategory() -> BTCategory? {
        return categories[JSCategoryAll]
    }
    
    func getBTCategories() -> [BTCategory] {
        return Array(categories.values).filter{ $0.number != JSCategoryAll }.sort{
            $0.number < $1.number
        }
    }
   
    // MARK: - CSVDataSink protocol implementation
    func parserDelegate(parserDelegate: CHCSVParserDelegate, foundData data: [String : String], inContext token: CollectionStore.ContextToken) {
        if parserDelegate === self.categoryParser {
            // we have a new category object's basic data
            let newObject = BTCategory()
            newObject.importFromData(data)
            // place the item in the collection we are assembling
            let catnum = newObject.number
            categories[catnum] = newObject
        }
        else if parserDelegate === self.infoParser {
            // we have a new dealer item object's data
            let newObject = BTDealerItem()
            let catnum = newObject.importFromData(data)
            // add it to the appropriate category
            if let cat = categories[catnum] {
                cat.dataItems.append(newObject)
            }
        }
    }
    
    func parserDelegate( parserDelegate: CHCSVParserDelegate, inout shouldAddSequenceData seqname: String, inout fromCount start: Int, inContext token: CollectionStore.ContextToken) -> Bool {
        let result = false
        return result
    }

    // MARK: main functionality
    private func loadData( parserDelegate: InfoParserDelegate, fromFile file: NSURL, withContext token: CollectionStore.ContextToken ) {
        // this does blocking (synchronous) parsing of the files
        if let basicParser = CHCSVParser(contentsOfCSVURL: file) {
            parserDelegate.contextToken = token
            parserDelegate.dataSink = self
            basicParser.sanitizesFields = true
            basicParser.delegate = parserDelegate
            basicParser.parse()
            print("Completed parsing \(file.lastPathComponent!)")
        }
    }
    
    func importData( completion: (() -> Void)? )
    {
        // do this on a background thread
        NSOperationQueue().addOperationWithBlock({
            // this does blocking (synchronous) parsing of the files
            let fileCats = getFile(nameOfCategoryFile)
            let fileInfo = getFile(nameOfInfoFile)
            // set the context token for this thread
            let token = 0 // we only get it back, we don't care to use it until we use CoreData
            // load the data using our saved value of the token
            self.categories = [:]
            self.loadData(self.categoryParser, fromFile: fileCats, withContext: token)
            self.loadData(self.infoParser, fromFile: fileInfo, withContext: token)
            // finalize the data for this context token
            //CollectionStore.sharedInstance.finalizeStorageContext(token) // removed - not using CoreData
            // run the completion block, if any, on the main queue
            if let completion = completion {
                NSOperationQueue.mainQueue().addOperationWithBlock(completion)
            }
        })
        
    }
    
}

// MARK: data export
class BTExporter {
    
    private func exportCatalogData(data: [BTCategory], toFile file: NSURL) {
        // 1. determine file name and path
        // 2. get the header list for the category file
        // 3. for each category
        // 4. output its base data
        if let basicWriter = CHCSVWriter(forWritingToCSVFile: file.path) {
            let headers = BTCategory.getExportNameList()
            basicWriter.writeLineOfFields(headers)
            for item in data {
                let dictObject = item.getExportData()
                var fields: [String] = []
                for header in headers {
                    if let field = dictObject[header] {
                        fields.append(field)
                    }
                }
                basicWriter.writeLineOfFields(fields)
            }
        }
    }
    
    private func exportItemData(data: [BTCategory], toFile file: NSURL) {
        // 1. determine file name and path
        // 2. get the header list for the item file
        // 3. for each category (incl.JS category)
        // 4. output its item data in a loop, passing the category number
        if let basicWriter = CHCSVWriter(forWritingToCSVFile: file.path) {
            let headers = BTDealerItem.getExportNameList()
            basicWriter.writeLineOfFields(headers)
            for cat in data {
                let catnum = cat.number
                let items = cat.dataItems
                for item in items {
                    let dictObject = item.getExportData(catnum)
                    var fields: [String] = []
                    for header in headers {
                        if let field = dictObject[header] {
                            fields.append(field)
                        }
                    }
                    basicWriter.writeLineOfFields(fields)
                }
            }
        }
    }
    
    func exportData(data: [BTCategory], completion: (() -> Void)? ) {
        let fileCats = getFile(nameOfCategoryFile)
        let fileInfo = getFile(nameOfInfoFile)
        let tempfileCats = getFile(nameOfCategoryFile + ".tmp")
        let tempfileInfo = getFile(nameOfInfoFile + ".tmp")
       // do this on a background thread
        // NOTE: data source can manage memory footprint by only doing batches of INFO and INVENTORY at a time
        NSOperationQueue().addOperationWithBlock({
            print("Exporting BT category and info files to path: \(fileCats.path!)")
            self.exportCatalogData(data, toFile: tempfileCats)
            self.exportItemData(data, toFile: tempfileInfo)
            // delete the original files and rename the temp files to be the original files (with error handling - atomic somehow?)
            let fileManager = NSFileManager.defaultManager()
            var error : NSError?
            do {
                try fileManager.removeItemAtURL(fileCats)
            } catch let error1 as NSError {
                error = error1
            } catch {
                fatalError("Swift 2 error - \(__FILE__):\(__LINE__) removeItemAtURL#1")
            }
            if error != nil {
                print("Unable to remove CATEGORY original: \(error!.localizedDescription).")
            }
            do {
                try fileManager.moveItemAtURL(tempfileCats, toURL: fileCats)
            } catch let error1 as NSError {
                error = error1
            } catch {
                fatalError("Swift 2 error - \(__FILE__):\(__LINE__) moveItemAtURL#1")
            }
            if error != nil {
                print("Unable to rename CATEGORY temp copy to original: \(error!.localizedDescription).")
            }
            do {
                try fileManager.removeItemAtURL(fileInfo)
            } catch let error1 as NSError {
                error = error1
            } catch {
                fatalError("Swift 2 error - \(__FILE__):\(__LINE__) removeItemAtURL#2")
            }
            if error != nil {
                print("Unable to remove INFO original: \(error!.localizedDescription).")
            }
            do {
                try fileManager.moveItemAtURL(tempfileInfo, toURL: fileInfo)
            } catch let error1 as NSError {
                error = error1
            } catch {
                fatalError("Swift 2 error - \(__FILE__):\(__LINE__) moveItemAtURL#2")
            }
            if error != nil {
                print("Unable to rename INFO temp copy to original: \(error!.localizedDescription).")
            }
            // run the completion block, if any, on the main queue
            if let completion = completion {
                NSOperationQueue.mainQueue().addOperationWithBlock(completion)
            }
        })
    }
}