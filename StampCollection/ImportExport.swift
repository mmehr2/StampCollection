//
//  ImportExport.swift
//  StampCollection
//
//  Created by Michael L Mehr on 4/13/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import UIKit
//import CoreData

// This class manages the Import/Export process for data using CSV files from the PHP project.
// NOTE: Sample files are included with the bundle, but this object is now able to take an arbitrary file triplet, such as from email attachments or AirDrop.
// Persistence is provided by CoreData when variable persistentStoreCoordinator is set (this is set by the AppDelegate if no errors occurred)
//
// The files are kept in the user's Documents directory. They are:
//   CATEGORIES.CSV - the CSV version of my PHP project's tab-separated category summary
//   INFO.CSV - the backing catalog info for the collection (converted from dealer data in most cases)
//   INVENTORY.CSV - the collection actual inventory, including wantlist items; these refer to the info but provide (intended) location and condition notes
//
// TBD: In actual practice, the description field of INV has also accumulated much info about sheets that truly belongs in the catalog. Plus the INFO has cached category names that should probably be left out of the object model schema. Etc. This is a rough first pass effort.

/*
NOTE (but see UPDATE 2019 below): The files as imported from the PHP processing website have an anomaly or two (not sure why).
All the line endings in the INFO and INVENTORY files are composed of double newlines ("\n\n")
I used the following bash commands to prep the files for inclusion here:
    cat info.csv | tr -s "\n" "\n" > info2.csv
This basically uses the "squeeze" command of tr(1) to compress the newlines after translating them to themselves (string1 and string2 identical).
I should probably implement a file processor to do this simple substitution as a prep phase before CSV parsing, since copying the files back from the website again will redo the problem.
Perhaps there's a way to invoke the command shell to do this? Nah, easier to just scan the file with a global regex replace.

Then we have the BAITCFG.CSV file. It is BAITCFG.TXT on the original, but its format is tab-separated instead of CSV. And it's much harder to setup the parser to deal with the TSV format, SO I just manually converted the file by replacing tabs with commas, and then manually editing to enforce the rule that fields with spaces in them are surrounded with double quotes.

I also had to modify the source code of the 3rd party CHCSVWriter in CHCSVParser.m to add space as an _illegalCharacters member so that this would happen automatically on the export write.

There was still a single instance of double-newline at the end of the file that I had to correct in XCODE with manual editing in Hex mode (right click file name on left and Open As -> Hex).

All this should be handled automatically when processing the local website files in the future, OR I could improve things on the website to use these new/better files.

UPDATE NOTE (2019): Historical file anomalies of the CSV files have been removed by the simple procedure of only bundling output of the Email Export process. As long as the
 CHCSVParser is bidirectional and my methods calling it work symmetrically, we should be fine.
 It should be mentioned that BAITCFG.CSV is really CATEGORIES.CSV in actual runtime usage. The name is historical, and remains in the bundle.
*/

/// protocol for any import/export usage
protocol ImportExportable {
    func prepareStorageContext(forExport exp: Bool) -> CollectionStore.ContextToken
    func finalizeStorageContext(_ token: CollectionStore.ContextToken, forExport: Bool)
    // operational requirements for persistence
    func addOperationToContext(_ token: CollectionStore.ContextToken, withBlock handler: @escaping () -> Void ) // to do the actual import job (handler runs on private queue)
    func addCompletionOperationWithBlock( _ handler: @escaping () -> Void ) // to notify when finished (handler runs on main queue)
}

/// protocol for sending data from a store to a csv file (exporting from store to csv file)
protocol ExportDataSource: ImportExportable {
    func numberOfItemsOfDataType( _ dataType: CollectionStore.DataType,
        withContext token: CollectionStore.ContextToken ) -> Int
    func headersForItemsOfDataType( _ dataType: CollectionStore.DataType,
        withContext token: CollectionStore.ContextToken )  -> [String]
    func dataType(_ dataType: CollectionStore.DataType, dataItemAtIndex index: Int,
        withContext token: CollectionStore.ContextToken ) -> [String:String]
}

/// protocol for sending incoming csv data to a store (importing from csv file to store)
protocol ImportDataSink: ImportExportable {
    func addObjectType(_ type: CollectionStore.DataType, withData: [String:String], toContext: CollectionStore.ContextToken)
    func getCountForType(_ type: CollectionStore.DataType, fromCategory: Int16, inContext: CollectionStore.ContextToken) -> Int
}

class ImportExport: CSVDataSink {
    enum Source {
        case documents
        case bundle
        // other cases may be added, such as:
        //case AirDrop
        case emailAttachment(url: URL)
    }
    
    fileprivate var dataModel: ImportDataSink? // where this object will send import data coming from the csv files
    
    fileprivate var dataSource: ExportDataSource? // where this object will get export data going to the csv files
        
    fileprivate var bundleURL: URL { return Bundle.main.bundleURL }

    fileprivate var bundleInfoURL: URL { return bundleURL.appendingPathComponent("info.csv") }

    fileprivate var bundleInventoryURL: URL { return bundleURL.appendingPathComponent("inventory.csv") }

    fileprivate var bundleCategoryURL: URL { return  bundleURL.appendingPathComponent("baitcfg.csv") }
    
    // to prevent warnings from the MainThreadChecker, put the use of the AppDelegate into a function that should be called from the main UI thread
    // prepAppDocsFolderPath() will set this as needed when starting any import/export app
    // NOTE: this is sort of a manual lazy-load mechanism
    fileprivate var appDocsDirectory: URL?
    
    fileprivate func prepAppDocsFolderPath() {
        if !Thread.isMainThread {
            // how to tell whether the current dispatch queue is the main one? well, see if we are on the main thread...
            print("ERROR_ USE OF APP DELEGATE ON BACKGROUND QUEUE!!!\n")
        }
        let ad = UIApplication.shared.delegate! as! AppDelegate
        appDocsDirectory = ad.applicationDocumentsDirectory
    }
    
    fileprivate var infoURL : URL {
        let ADD = appDocsDirectory ?? bundleURL
        return ADD.appendingPathComponent("info.csv")
    }
    
    fileprivate var inventoryURL : URL {
        let ADD = appDocsDirectory ?? bundleURL
        return ADD.appendingPathComponent("inventory.csv")
    }
    
    fileprivate var categoryURL : URL {
        let ADD = appDocsDirectory ?? bundleURL
        return ADD.appendingPathComponent("category.csv")
    }

    // MARK: - CSVDataSink protocol implementation (internal link to 3rd party CSV file parser)
    internal func parserDelegate(_ parserDelegate: CHCSVParserDelegate, foundData data: [String : String], inContext token: CollectionStore.ContextToken) {
        // OPTIONAL: create persistent data objects for the parsed info
        guard let parserDelegate = parserDelegate as? InfoParserDelegate else { return }
        if parserDelegate.name == "CATEGORY" {
            dataModel?.addObjectType(.categories, withData: data, toContext: token)
        }
        else if parserDelegate.name == "INFO" {
            dataModel?.addObjectType(.info, withData: data, toContext: token)
        }
        else if parserDelegate.name == "INVENTORY" {
            dataModel?.addObjectType(.inventory, withData: data, toContext: token)
        }
    }

    internal func parserDelegate( _ parserDelegate: CHCSVParserDelegate, shouldAddSequenceData seqname: inout String, fromCount start: inout Int, inContext token: CollectionStore.ContextToken) -> Bool {
        var result = false
        guard let parserDelegate = parserDelegate as? InfoParserDelegate else { return result }
        if parserDelegate.name == "CATEGORY" {
            seqname = "exOrder"
            start = dataModel?.getCountForType(.categories, fromCategory: CollectionStore.CategoryAll, inContext: token) ?? 0
            result = true
        }
        else if parserDelegate.name == "INFO" {
            seqname = "exOrder"
            start = dataModel?.getCountForType(.info, fromCategory: CollectionStore.CategoryAll, inContext: token) ?? 0
            result = true
        }
        else if parserDelegate.name == "INVENTORY" {
            seqname = "exOrder"
            start = dataModel?.getCountForType(.inventory, fromCategory: CollectionStore.CategoryAll, inContext: token) ?? 0
            result = true
        }
        return result
    }

    // MARK: - file import front-end
    // NOTE: responsible for getting the persistent CSV files into the user's Documents folder for importData() back-end stage
    fileprivate func prepareImportFromSource( _ source: Source ) -> Bool {
        switch source {
        case .bundle:
            return prepareImportFromBundle()
//        case .AirDrop:
//            return prepareImportFromAirDrop()
        case let .emailAttachment(url):
            return prepareImportFromEmailAttachment(url)
        default: break
        }
        return false
    }

    // MARK: - bundle file import front-end
    // NOTE: copies files from bundle to user's Documents folder
    fileprivate func prepareImportFromBundle() -> Bool {
        // this does blocking (synchronous) parsing of the files
        // copy the default data files into the documents dirctory
        let fileManager = FileManager.default
        var error : NSError?
        let categoryRemovedSuccessfully: Bool
        do {
            try fileManager.removeItem(at: categoryURL)
            categoryRemovedSuccessfully = true
        } catch let error1 as NSError {
            error = error1
            categoryRemovedSuccessfully = false
        }
        if !categoryRemovedSuccessfully {
            print("Unable to remove CATEGORY from app Documents dir due to error \(error!).")
        }
        let categoryCopiedSuccessfully: Bool
        do {
            try fileManager.copyItem(at: bundleCategoryURL, to: categoryURL)
            categoryCopiedSuccessfully = true
        } catch let error1 as NSError {
            error = error1
            categoryCopiedSuccessfully = false
        }
        if !categoryCopiedSuccessfully {
            print("Unable to copy CATEGORY from app bundle due to error \(error!).")
        }
        let infoRemovedSuccessfully: Bool
        do {
            try fileManager.removeItem(at: infoURL)
            infoRemovedSuccessfully = true
        } catch let error1 as NSError {
            error = error1
            infoRemovedSuccessfully = false
        }
        if !infoRemovedSuccessfully {
            print("Unable to remove INFO from app Documents dir due to error \(error!).")
        }
        let infoCopiedSuccessfully: Bool
        do {
            try fileManager.copyItem(at: bundleInfoURL, to: infoURL)
            infoCopiedSuccessfully = true
        } catch let error1 as NSError {
            error = error1
            infoCopiedSuccessfully = false
        }
        if !infoCopiedSuccessfully {
            print("Unable to copy INFO from app bundle due to error \(error!).")
        }
        let inventoryRemovedSuccessfully: Bool
        do {
            try fileManager.removeItem(at: inventoryURL)
            inventoryRemovedSuccessfully = true
        } catch let error1 as NSError {
            error = error1
            inventoryRemovedSuccessfully = false
        }
        if !inventoryRemovedSuccessfully {
            print("Unable to remove INVENTORY from app Documents dir due to error \(error!).")
        }
        let inventoryCopiedSuccessfully: Bool
        do {
            try fileManager.copyItem(at: bundleInventoryURL, to: inventoryURL)
            inventoryCopiedSuccessfully = true
        } catch let error1 as NSError {
            error = error1
            inventoryCopiedSuccessfully = false
        }
        if !inventoryCopiedSuccessfully {
            print("Unable to copy INVENTORY from app bundle due to error \(error!).")
        }
        return categoryCopiedSuccessfully && infoCopiedSuccessfully && inventoryCopiedSuccessfully
    }

    // MARK: - email attachment file import front-end
    // NOTE: copies files from given SCZP file url to user's Documents folder
    fileprivate func prepareImportFromEmailAttachment(_ url: URL) -> Bool {
        // this does blocking (synchronous) parsing of the files
        // copy the default data files into the documents dirctory using the email attachment importer method
        return EmailAttachmentImporter.receiveFiles(url)
    }
    
    // MARK: - AirDrop file import front-end (TBD)
    
    // MARK: - data import
    // NOTE: imports from CSV files in user's Documents folder
    fileprivate func loadData( _ parserDelegate: InfoParserDelegate, fromFile file: URL, withContext token: CollectionStore.ContextToken ) {
        // this does blocking (synchronous) parsing of the files
        if let basicParser = CHCSVParser(contentsOfCSVURL: file) {
            // link the InfoParserDelegate to the collection store
            parserDelegate.contextToken = token
            parserDelegate.dataSink = self
            // set up the CHCSVParser
            basicParser.sanitizesFields = true
            basicParser.delegate = parserDelegate
            basicParser.parse()
            print("Completed parsing \(file.lastPathComponent)")
        }
    }

    /// Import the data (back-end) from CSV files in the user's Documents folder
    func importData( _ sourceType: Source,
        toModel dataModel: ImportDataSink,
        completion: (() -> Void)? ) -> Progress
    {
        let progress = Progress() // create a progress object to report progress
        if true { //let dataModel = self.dataModel {
            self.dataModel = dataModel // save this for use by protocol functions
            prepAppDocsFolderPath() // prepare file URLs for lazy use (must be called on UI thread, uses AppDelegate)
            // set the context token for this thread
            let token = dataModel.prepareStorageContext(forExport: false)
            let catPD = InfoParserDelegate(name: "CATEGORY", progress: progress)
            let infoPD = InfoParserDelegate(name: "INFO", progress: progress)
            let invPD = InfoParserDelegate(name: "INVENTORY", progress: progress)
            let catRecs = countLinesInFile(categoryURL.path)
            let infoRecs = countLinesInFile(infoURL.path)
            let invRecs = countLinesInFile(inventoryURL.path)
            print("Reading \(catRecs) categories, \(infoRecs) info items, and \(invRecs) inventory items...")
            progress.totalUnitCount += Int64(catRecs)
            progress.totalUnitCount += Int64(infoRecs)
            progress.totalUnitCount += Int64(invRecs)
            // do this on the background thread provided by the data model
            dataModel.addOperationToContext(token) {
                // this does blocking (synchronous) parsing of the files
                if self.prepareImportFromSource(sourceType) {
                    // load the data using our saved value of the token
                    self.loadData(catPD, fromFile: self.categoryURL, withContext: token)
                    self.loadData(infoPD, fromFile: self.infoURL, withContext: token)
                    self.loadData(invPD, fromFile: self.inventoryURL, withContext: token)
                    // finalize the data for this context token (perform save, release context)
                    dataModel.finalizeStorageContext(token, forExport: false)
                }
                // run the completion block, if any, on the main queue
                if let completion = completion {
                    dataModel.addCompletionOperationWithBlock(completion)
                }
            }
        }
        return progress
    }

    // MARK: - data export
    
    // NOTE: exports to CSV files in user's Documents folder
    fileprivate func writeDataOfType( _ dataType: CollectionStore.DataType, toCSVFile file: URL,
                                      withContext token: CollectionStore.ContextToken,
                                      viaProgress progress: Progress )
    {
        if let dataSource = dataSource, let basicWriter = CHCSVWriter(forWritingToCSVFile: file.path) {
            let headers = dataSource.headersForItemsOfDataType(dataType, withContext: token)
            basicWriter.writeLine(ofFields: headers as NSFastEnumeration?)
            let itemCount = dataSource.numberOfItemsOfDataType(dataType, withContext: token)
            for index in 0..<itemCount {
                let dictObject = dataSource.dataType(dataType, dataItemAtIndex: index, withContext: token)
                // limit the data columns to only header names that are used in the data itself
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
    
    func exportData( _ compare: Bool = false,
        fromModel dataSource: ExportDataSource,
        completion: (() -> Void)? ) -> Progress
    {
        // create a Progress object for data counting
        let progress = Progress()
        if true { //let dataSource = self.dataSource {
            self.dataSource = dataSource // save the data object for use by protocols
            prepAppDocsFolderPath() // prepare file URLs for lazy use (must be called on UI thread, uses AppDelegate)
            // set the context token for this thread
            let token = dataSource.prepareStorageContext(forExport: true)
            progress.totalUnitCount += Int64(dataSource.numberOfItemsOfDataType(.categories, withContext: token))
            progress.totalUnitCount += Int64(dataSource.numberOfItemsOfDataType(.info, withContext: token))
            progress.totalUnitCount += Int64(dataSource.numberOfItemsOfDataType(.inventory, withContext: token))
            // do this on a background thread
            // NOTE: data source can manage memory footprint by only doing batches of INFO and INVENTORY at a time
            dataSource.addOperationToContext(token) {
                // this does blocking (synchronous) writing of the files
                let categoryFileTmp = self.categoryURL.appendingPathExtension("tmp")
                let infoFileTmp = self.infoURL.appendingPathExtension("tmp")
                let inventoryFileTmp = self.inventoryURL.appendingPathExtension("tmp")
                print("Exporting files to \(self.categoryURL.path)")
                self.writeDataOfType(.categories, toCSVFile: categoryFileTmp, withContext: token, viaProgress: progress)
                print("Completed writing \(categoryFileTmp.lastPathComponent)")
                self.writeDataOfType(.info, toCSVFile: infoFileTmp, withContext: token, viaProgress: progress)
                print("Completed writing \(infoFileTmp.lastPathComponent)")
                self.writeDataOfType(.inventory, toCSVFile: inventoryFileTmp, withContext: token, viaProgress: progress)
                print("Completed writing \(inventoryFileTmp.lastPathComponent)")
                // finalize the data for this context token
                dataSource.finalizeStorageContext(token, forExport: true)
                // compare files to originals, if needed
                if compare {
                    // compare the temp files to the originals
                    let fileManager = FileManager.default
                    let categoryOK = fileManager.contentsEqual(atPath: categoryFileTmp.path, andPath: self.categoryURL.path)
                    if !categoryOK {
                        print("Unable to compare CATEGORY temp copy \(categoryFileTmp.path) to original.")
                    }
                    let infoOK = fileManager.contentsEqual(atPath: infoFileTmp.path, andPath: self.infoURL.path)
                    if !infoOK {
                        print("Unable to compare INFO temp copy \(infoFileTmp.path) to original.")
                    }
                    let inventoryOK = fileManager.contentsEqual(atPath: inventoryFileTmp.path, andPath: self.inventoryURL.path)
                    if !inventoryOK {
                        print("Unable to compare INVENTORY temp copy \(inventoryFileTmp.path) to original.")
                    }
                }
                // delete the original files and rename the temp files to be the original files (with error handling - atomic somehow?)
                self.finalizeFiles(categoryFileTmp, infoFileTmp, inventoryFileTmp)
                // run the completion block, if any, on the main queue
                if let completion = completion {
                    dataSource.addCompletionOperationWithBlock(completion)
                }
            } // end of operation block
        }
        return progress
    }
    
    fileprivate func finalizeFiles(_ categoryFileTmp: URL, _ infoFileTmp: URL, _ inventoryFileTmp: URL) {
        let fileManager = FileManager.default
        var error : NSError?
        do {
            try fileManager.removeItem(at: self.categoryURL)
        } catch let error1 as NSError {
            error = error1
        } catch {
            fatalError("Swift 2 error - \(#file):\(#line) removeItemAtURL#1")
        }
        if error != nil {
            print("Unable to remove CATEGORY original: \(error!.localizedDescription).")
        }
        do {
            try fileManager.moveItem(at: categoryFileTmp, to: self.categoryURL)
        } catch let error1 as NSError {
            error = error1
        } catch {
            fatalError("Swift 2 error - \(#file):\(#line) moveItemAtURL#1")
        }
        if error != nil {
            print("Unable to rename CATEGORY temp copy to original: \(error!.localizedDescription).")
        }
        do {
            try fileManager.removeItem(at: self.infoURL)
        } catch let error1 as NSError {
            error = error1
        } catch {
            fatalError("Swift 2 error - \(#file):\(#line) removeItemAtURL#2")
        }
        if error != nil {
            print("Unable to remove INFO original: \(error!.localizedDescription).")
        }
        do {
            try fileManager.moveItem(at: infoFileTmp, to: self.infoURL)
        } catch let error1 as NSError {
            error = error1
        } catch {
            fatalError("Swift 2 error - \(#file):\(#line) moveItemAtURL#2")
        }
        if error != nil {
            print("Unable to rename INFO temp copy to original: \(error!.localizedDescription).")
        }
        do {
            try fileManager.removeItem(at: self.inventoryURL)
        } catch let error1 as NSError {
            error = error1
        } catch {
            fatalError("Swift 2 error - \(#file):\(#line) removeItemAtURL#3")
        }
        if error != nil {
            print("Unable to remove INVENTORY original: \(error!.localizedDescription).")
        }
        do {
            try fileManager.moveItem(at: inventoryFileTmp, to: self.inventoryURL)
        } catch let error1 as NSError {
            error = error1
        } catch {
            fatalError("Swift 2 error - \(#file):\(#line) moveItemAtURL#3")
        }
        if error != nil {
            print("Unable to rename INVENTORY temp copy to original: \(error!.localizedDescription).")
        } else {
            let catRecs = countLinesInFile(categoryURL.path)
            let infoRecs = countLinesInFile(infoURL.path)
            let invRecs = countLinesInFile(inventoryURL.path)
            print("Wrote total \(catRecs) categories, \(infoRecs) info items, and \(invRecs) inventory items (from line count).")
        }
    }
    
}
