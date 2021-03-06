//
//  BTImportExport.swift
//  StampCollection
//
//  Created by Michael L Mehr on 5/21/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import Foundation
import UIKit

private let infoName = "BTINFO"
private let categoryName = "BTCATS"
private let nameOfCategoryFile = "\(categoryName).CSV"
private let nameOfInfoFile = "\(infoName).CSV"

private var bundleURL: URL { return Bundle.main.bundleURL }

// to prevent warnings from the MainThreadChecker, put the use of the AppDelegate into a function that should be called from the main UI thread
// prepAppDocsFolderPath() will set this as needed when starting any import/export app
// NOTE: this is sort of a manual lazy-load mechanism
private var appDocsDirectory: URL?

private func prepAppDocsFolderPath() {
    if !Thread.isMainThread {
        // how to tell whether the current dispatch queue is the main one? well, see if we are on the main thread...
        print("ERROR_ USE OF APP DELEGATE ON BACKGROUND QUEUE!!!\n")
    }
    let ad = UIApplication.shared.delegate! as! AppDelegate
    appDocsDirectory = ad.applicationDocumentsDirectory
}

private func getFile(_ name: String) -> URL {
    let addir = appDocsDirectory ?? bundleURL
    return addir.appendingPathComponent(name)
}

private func getBundleFile(_ name: String) -> URL {
    return bundleURL.appendingPathComponent(name)
}

// MARK: data import
class BTImporter: CSVDataSink {
    
    let infoParserName = infoName
    let categoryParserName = categoryName
    
    
    fileprivate var categories: [Int:BTCategory] = [:]
    
    // MARK: data access
    
    func getJSCategory() -> BTCategory? {
        return categories[JSCategoryAll]
    }
    
    func getBTCategories() -> [BTCategory] {
        return Array(categories.values).filter{ $0.number != JSCategoryAll }.sorted{
            $0.number < $1.number
        }
    }
   
    // MARK: - CSVDataSink protocol implementation
    func parserDelegate(_ parserDelegate: CHCSVParserDelegate, foundData data: [String : String], inContext token: CollectionStore.ContextToken) {
        guard let parserDelegate = parserDelegate as? InfoParserDelegate else { return }
        if parserDelegate.name == categoryParserName {
            // we have a new category object's basic data
            let newObject = BTCategory()
            newObject.importFromData(data)
            // place the item in the collection we are assembling
            let catnum = newObject.number
            categories[catnum] = newObject
        }
        else if parserDelegate.name == infoParserName {
            // we have a new dealer item object's data
            let newObject = BTDealerItem()
            let catnum = newObject.importFromData(data)
            // add it to the appropriate category
            if let cat = categories[catnum] {
                cat.addDataItem(newObject)   //dataItems.append(newObject)
            }
        }
    }
    
    func parserDelegate( _ parserDelegate: CHCSVParserDelegate, shouldAddSequenceData seqname: inout String, fromCount start: inout Int, inContext token: CollectionStore.ContextToken) -> Bool {
        let result = false
        return result
    }

    // MARK: main functionality
    fileprivate func loadData( _ parserDelegate: InfoParserDelegate, fromFile file: URL, withContext token: CollectionStore.ContextToken ) {
        // this does blocking (synchronous) parsing of the files
        if let basicParser = CHCSVParser(contentsOfCSVURL: file) {
            parserDelegate.contextToken = token
            parserDelegate.dataSink = self
            basicParser.sanitizesFields = true
            basicParser.delegate = parserDelegate
            basicParser.parse()
            print("Completed parsing \(file.lastPathComponent)")
        }
    }
    
    func importData( _ completion: (() -> Void)? ) -> Progress
    {
        // do this on a background thread
        let progress = Progress()
        //prepAppDocsFolderPath() // prepare file URLs for lazy use (must be called on UI thread, uses AppDelegate)
        // NOTE> by not calling this here and only on Export, we import first from the bundled files, allowing default store values to be set
        let catsPD = InfoParserDelegate(name: categoryParserName, progress: progress)
        let infoPD = InfoParserDelegate(name: infoParserName, progress: progress)
        OperationQueue().addOperation({
            // this does blocking (synchronous) parsing of the files
            let fileCats = getFile(nameOfCategoryFile)
            let fileInfo = getFile(nameOfInfoFile)
            let catRecs = countLinesInFile(fileCats.path)
            let infoRecs = countLinesInFile(fileInfo.path)
            print("Reading \(catRecs) BT categories and \(infoRecs) BT info items...")
            progress.totalUnitCount += Int64(catRecs)
            progress.totalUnitCount += Int64(infoRecs)
            // set the context token for this thread
            let token = 0 // we only get it back, we don't care to use it until we use CoreData
            // load the data using our saved value of the token
            self.categories = [:]
            self.loadData(catsPD, fromFile: fileCats, withContext: token)
            self.loadData(infoPD, fromFile: fileInfo, withContext: token)
            // finalize the data for this context token
            //CollectionStore.sharedInstance.finalizeStorageContext(token) // removed - not using CoreData
            // run the completion block, if any, on the main queue
            if let completion = completion {
                OperationQueue.main.addOperation(completion)
            }
        })
        return progress
    }
    
}

// MARK: data export
class BTExporter {
    
    fileprivate func exportCatalogData(_ data: [BTCategory], toFile file: URL, usingProgress progress: Progress) {
        // 1. determine file name and path
        // 2. get the header list for the category file
        // 3. for each category
        // 4. output its base data
        if let basicWriter = CHCSVWriter(forWritingToCSVFile: file.path) {
            let headers = BTCategory.getExportNameList()
            basicWriter.writeLine(ofFields: headers as NSFastEnumeration?)
            for item in data {
                let dictObject = item.getExportData()
                var fields: [String] = []
                for header in headers {
                    if let field = dictObject[header] {
                        fields.append(field)
                    }
                }
                basicWriter.writeLine(ofFields: fields as NSFastEnumeration?)
                progress.completedUnitCount += 1
            }
        }
    }
    
    fileprivate func exportItemData(_ data: [BTCategory], toFile file: URL, usingProgress progress: Progress) {
        // 1. determine file name and path
        // 2. get the header list for the item file
        // 3. for each category (incl.JS category)
        // 4. output its item data in a loop, passing the category number
        if let basicWriter = CHCSVWriter(forWritingToCSVFile: file.path) {
            let headers = BTDealerItem.getExportNameList()
            basicWriter.writeLine(ofFields: headers as NSFastEnumeration?)
            for cat in data {
                let catnum = cat.number
                let items = cat.getAllDataItems()
                for item in items {
                    let dictObject = item.getExportData(catnum)
                    var fields: [String] = []
                    for header in headers {
                        if let field = dictObject[header] {
                            fields.append(field)
                        }
                    }
                    basicWriter.writeLine(ofFields: fields as NSFastEnumeration?)
                    progress.completedUnitCount += 1
                }
            }
        }
    }
    
    func exportData(_ data: [BTCategory], completion: (() -> Void)? ) -> Progress {
        let progress = Progress()
        progress.totalUnitCount += data.reduce(0) { total, item in return total + 1 }
        progress.totalUnitCount += data.reduce(0) { total, item in return total + Int64(item.dataItemCount) }
        prepAppDocsFolderPath() // prepare file URLs for lazy use (must be called on UI thread, uses AppDelegate)
        let fileCats = getFile(nameOfCategoryFile)
        let fileInfo = getFile(nameOfInfoFile)
        let tempfileCats = getFile(nameOfCategoryFile + ".tmp")
        let tempfileInfo = getFile(nameOfInfoFile + ".tmp")
       // do this on a background thread
        // NOTE: data source can manage memory footprint by only doing batches of INFO and INVENTORY at a time
        OperationQueue().addOperation({
            print("Exporting BT category and info files to path: \(fileCats.path)")
            self.exportCatalogData(data, toFile: tempfileCats, usingProgress: progress)
            self.exportItemData(data, toFile: tempfileInfo, usingProgress: progress)
            // delete the original files and rename the temp files to be the original files (with error handling - atomic somehow?)
            let fileManager = FileManager.default
            var error : NSError?
            do {
                try fileManager.removeItem(at: fileCats)
            } catch let error1 as NSError {
                error = error1
            } catch {
                fatalError("Swift 2 error - \(#file):\(#line) removeItemAtURL#1")
            }
            if error != nil {
                print("Unable to remove CATEGORY original: \(error!.localizedDescription).")
            }
            do {
                try fileManager.moveItem(at: tempfileCats, to: fileCats)
            } catch let error1 as NSError {
                error = error1
            } catch {
                fatalError("Swift 2 error - \(#file):\(#line) moveItemAtURL#1")
            }
            if error != nil {
                print("Unable to rename CATEGORY temp copy to original: \(error!.localizedDescription).")
            }
            do {
                try fileManager.removeItem(at: fileInfo)
            } catch let error1 as NSError {
                error = error1
            } catch {
                fatalError("Swift 2 error - \(#file):\(#line) removeItemAtURL#2")
            }
            if error != nil {
                print("Unable to remove INFO original: \(error!.localizedDescription).")
            }
            do {
                try fileManager.moveItem(at: tempfileInfo, to: fileInfo)
            } catch let error1 as NSError {
                error = error1
            } catch {
                fatalError("Swift 2 error - \(#file):\(#line) moveItemAtURL#2")
            }
            if error != nil {
                print("Unable to rename INFO temp copy to original: \(error!.localizedDescription).")
            }
            // run the completion block, if any, on the main queue
            if let completion = completion {
                OperationQueue.main.addOperation(completion)
            }
        })
        return progress
    }
}
