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
// NOTE: Sample files are included with the bundle (collection as of late 2014), but this should probably become able to take an arbitrary file triplet, such as from email attachments or AirDrop.
// Persistence is provided by CoreData when variable persistentStoreCoordinator is set (this is set by the AppDelegate if no errors occurred)
//
// The files are kept in the user's Documents directory. They are:
//   CATEGORIES.CSV - the CSV version of my PHP project's tab-separated category summary
//   INFO.CSV - the backing catalog info for the collection (converted from dealer data in most cases)
//   INVENTORY.CSV - the collection actual inventory, including wantlist items; these refer to the info but provide (intended) location and condition notes
//
// TBD: In actual practice, the description field of INV has also accumulated much info about sheets that truly belongs in the catalog. Plus the INFO has cached category names that should probably be left out of the object model schema. Etc. This is a rough first pass effort.

/*
NOTE: The files as imported from the PHP processing website have an anomaly or two (not sure why).
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
*/

protocol ExportDataSource {
    func prepareStorageContext(forExport exp: Bool) -> CollectionStore.ContextToken
    func numberOfItemsOfDataType( dataType: CollectionStore.DataType,
        withContext token: CollectionStore.ContextToken ) -> Int
    func headersForItemsOfDataType( dataType: CollectionStore.DataType,
        withContext token: CollectionStore.ContextToken )  -> [String]
    func dataType(dataType: CollectionStore.DataType, dataItemAtIndex index: Int,
        withContext token: CollectionStore.ContextToken ) -> [String:String]
    func finalizeStorageContext(token: CollectionStore.ContextToken, forExport: Bool)
}

class ImportExport: InfoParseable {
    enum Source {
        case Bundle
        // other cases may be added, such as:
        //case AirDrop
        //case EmailAttachment
    }
    
    var dataSource: ExportDataSource?
        
    private var bundleURL: NSURL { return NSBundle.mainBundle().bundleURL }

    private var bundleInfoURL: NSURL { return bundleURL.URLByAppendingPathComponent("info.csv") }

    private var bundleInventoryURL: NSURL { return bundleURL.URLByAppendingPathComponent("inventory.csv") }

    private var bundleCategoryURL: NSURL { return  bundleURL.URLByAppendingPathComponent("baitcfg.csv") }
    
    lazy private var infoParser = InfoParserDelegate(name: "INFO")
    
    lazy private var categoryParser = InfoParserDelegate(name: "CATEGORY")
    
    lazy private var inventoryParser = InfoParserDelegate(name: "INVENTORY")
    
    private var infoURL : NSURL {
        let ad = UIApplication.sharedApplication().delegate! as! AppDelegate
        return ad.applicationDocumentsDirectory.URLByAppendingPathComponent("info.csv")
    }
    
    private var inventoryURL : NSURL {
        let ad = UIApplication.sharedApplication().delegate! as! AppDelegate
        return ad.applicationDocumentsDirectory.URLByAppendingPathComponent("inventory.csv")
    }
    
    private var categoryURL : NSURL {
        let ad = UIApplication.sharedApplication().delegate! as! AppDelegate
        return ad.applicationDocumentsDirectory.URLByAppendingPathComponent("category.csv")
    }

    // MARK: - InfoParseable protocol implementation
    internal func parserDelegate(parserDelegate: CHCSVParserDelegate, foundData data: [String : String], inContext token: CollectionStore.ContextToken) {
        // OPTIONAL: create persistent data objects for the parsed info
        if parserDelegate === categoryParser {
            CollectionStore.sharedInstance.addObjectType(.Categories, withData: data, toContext: token)
        }
        else if parserDelegate === infoParser {
            CollectionStore.sharedInstance.addObjectType(.Info, withData: data, toContext: token)
        }
        else if parserDelegate === inventoryParser {
            CollectionStore.sharedInstance.addObjectType(.Inventory, withData: data, toContext: token)
        }
    }

    internal func parserDelegate( parserDelegate: CHCSVParserDelegate, inout shouldAddSequenceData seqname: String, inout fromCount start: Int, inContext token: CollectionStore.ContextToken) -> Bool {
        var result = false
        if parserDelegate === categoryParser {
            seqname = "exOrder"
            start = CollectionStore.sharedInstance.getCountForType(.Categories, fromCategory: CollectionStore.CategoryAll, inContext: token)
            result = true
        }
        else if parserDelegate === infoParser {
            seqname = "exOrder"
            start = CollectionStore.sharedInstance.getCountForType(.Info, fromCategory: CollectionStore.CategoryAll, inContext: token)
            result = true
        }
        else if parserDelegate === inventoryParser {
            seqname = "exOrder"
            start = CollectionStore.sharedInstance.getCountForType(.Inventory, fromCategory: CollectionStore.CategoryAll, inContext: token)
            result = true
        }
        return result
    }

    // MARK: - file import front-end
    private func prepareImportFromSource( source: Source ) -> Bool {
        switch source {
        case .Bundle:
            return prepareImportFromBundle()
//        case .AirDrop:
//            return prepareImportFromAirDrop()
//        case .EmailAttachment:
//            return prepareImportFromEmailAttachment()
        default: break
        }
    }

    // MARK: - bundle file import front-end
    // NOTE: copies files from bundle to user's Documents folder
    private func prepareImportFromBundle() -> Bool {
        // this does blocking (synchronous) parsing of the files
        // copy the default data files into the documents dirctory
        let fileManager = NSFileManager.defaultManager()
        var error : NSError?
        let categoryRemovedSuccessfully = fileManager.removeItemAtURL(categoryURL, error: &error)
        if !categoryRemovedSuccessfully {
            println("Unable to remove CATEGORY from app Documents dir due to error \(error!).")
        }
        let categoryCopiedSuccessfully = fileManager.copyItemAtURL(bundleCategoryURL, toURL: categoryURL, error: &error)
        if !categoryCopiedSuccessfully {
            println("Unable to copy CATEGORY from app bundle due to error \(error!).")
        }
        let infoRemovedSuccessfully = fileManager.removeItemAtURL(infoURL, error: &error)
        if !infoRemovedSuccessfully {
            println("Unable to remove INFO from app Documents dir due to error \(error!).")
        }
        let infoCopiedSuccessfully = fileManager.copyItemAtURL(bundleInfoURL, toURL: infoURL, error: &error)
        if !infoCopiedSuccessfully {
            println("Unable to copy INFO from app bundle due to error \(error!).")
        }
        let inventoryRemovedSuccessfully = fileManager.removeItemAtURL(inventoryURL, error: &error)
        if !inventoryRemovedSuccessfully {
            println("Unable to remove INVENTORY from app Documents dir due to error \(error!).")
        }
        let inventoryCopiedSuccessfully = fileManager.copyItemAtURL(bundleInventoryURL, toURL: inventoryURL, error: &error)
        if !inventoryCopiedSuccessfully {
            println("Unable to copy INVENTORY from app bundle due to error \(error!).")
        }
        return categoryCopiedSuccessfully && infoCopiedSuccessfully && inventoryCopiedSuccessfully
    }

    // MARK: - email attachment file import front-end (TBD)
    
    // MARK: - AirDrop file import front-end (TBD)
    
    // MARK: - data import
    // NOTE: imports from CSV files in user's Documents folder
    private func loadData( parserDelegate: InfoParserDelegate, fromFile file: NSURL, withContext token: CollectionStore.ContextToken ) {
        // this does blocking (synchronous) parsing of the files
        if let basicParser = CHCSVParser(contentsOfCSVURL: file) {
            parserDelegate.contextToken = token
            parserDelegate.dataSink = self
            basicParser.sanitizesFields = true
            basicParser.delegate = parserDelegate
            basicParser.parse()
            println("Completed parsing \(file.lastPathComponent!)")
        }
    }
    
    func importData( sourceType: Source,
        completion: (() -> Void)? )
    {
        // do this on a background thread
        NSOperationQueue().addOperationWithBlock({
            // this does blocking (synchronous) parsing of the files
            if self.prepareImportFromSource(sourceType) {
                // set the context token for this thread
                let token = CollectionStore.sharedInstance.prepareStorageContext()
                // load the data using our saved value of the token
                self.loadData(self.categoryParser, fromFile: self.categoryURL, withContext: token)
                self.loadData(self.infoParser, fromFile: self.infoURL, withContext: token)
                self.loadData(self.inventoryParser, fromFile: self.inventoryURL, withContext: token)
                // finalize the data for this context token
                CollectionStore.sharedInstance.finalizeStorageContext(token)
            }
            // run the completion block, if any, on the main queue
            if let completion = completion {
                NSOperationQueue.mainQueue().addOperationWithBlock(completion)
            }
        })
        
    }

    // MARK: - data export
    
    // NOTE: exports to CSV files in user's Documents folder
    private func writeDataOfType( dataType: CollectionStore.DataType, toCSVFile file: NSURL,
        withContext token: CollectionStore.ContextToken )
    {
        if let basicWriter = CHCSVWriter(forWritingToCSVFile: file.path),
            dataSource = dataSource {
            let headers = dataSource.headersForItemsOfDataType(dataType, withContext: token)
            basicWriter.writeLineOfFields(headers)
            let itemCount = dataSource.numberOfItemsOfDataType(dataType, withContext: token)
            for index in 0..<itemCount {
                let dictObject = dataSource.dataType(dataType, dataItemAtIndex: index, withContext: token)
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
    
    func exportData( compare: Bool = false,
        completion: (() -> Void)? )
    {
        // do this on a background thread
        // NOTE: data source can manage memory footprint by only doing batches of INFO and INVENTORY at a time
        NSOperationQueue().addOperationWithBlock({
            // this does blocking (synchronous) writing of the files
            var categoryFileTmp = self.categoryURL.URLByAppendingPathExtension("tmp")
            var infoFileTmp = self.infoURL.URLByAppendingPathExtension("tmp")
            var inventoryFileTmp = self.inventoryURL.URLByAppendingPathExtension("tmp")
            if let dataSource = self.dataSource {
                // set the context token for this thread
                let token = dataSource.prepareStorageContext(forExport: true)
                println("Exporting files to \(self.categoryURL.path!)")
                self.writeDataOfType(.Categories, toCSVFile: categoryFileTmp, withContext: token)
                println("Completed writing \(categoryFileTmp.lastPathComponent!)")
                self.writeDataOfType(.Info, toCSVFile: infoFileTmp, withContext: token)
                println("Completed writing \(infoFileTmp.lastPathComponent!)")
                self.writeDataOfType(.Inventory, toCSVFile: inventoryFileTmp, withContext: token)
                println("Completed writing \(inventoryFileTmp.lastPathComponent!)")
                // finalize the data for this context token
                dataSource.finalizeStorageContext(token, forExport: true)
            }
            // compare files to originals, if needed
            if compare {
                // compare the temp files to the originals
                let fileManager = NSFileManager.defaultManager()
                let categoryOK = fileManager.contentsEqualAtPath(categoryFileTmp.path!, andPath: self.categoryURL.path!)
                if !categoryOK {
                    println("Unable to compare CATEGORY temp copy \(categoryFileTmp.path!) to original.")
                }
                let infoOK = fileManager.contentsEqualAtPath(infoFileTmp.path!, andPath: self.infoURL.path!)
                if !infoOK {
                    println("Unable to compare INFO temp copy \(infoFileTmp.path!) to original.")
                }
                let inventoryOK = fileManager.contentsEqualAtPath(inventoryFileTmp.path!, andPath: self.inventoryURL.path!)
                if !inventoryOK {
                    println("Unable to compare INVENTORY temp copy \(inventoryFileTmp.path!) to original.")
                }
            }
            // delete the original files and rename the temp files to be the original files (with error handling - atomic somehow?)
            let fileManager = NSFileManager.defaultManager()
            var error : NSError?
            fileManager.removeItemAtURL(self.categoryURL, error: &error)
            if error != nil {
                println("Unable to remove CATEGORY original: \(error!.localizedDescription).")
            }
            fileManager.moveItemAtURL(categoryFileTmp, toURL: self.categoryURL, error: &error)
            if error != nil {
                println("Unable to rename CATEGORY temp copy to original: \(error!.localizedDescription).")
            }
            fileManager.removeItemAtURL(self.infoURL, error: &error)
            if error != nil {
                println("Unable to remove INFO original: \(error!.localizedDescription).")
            }
            fileManager.moveItemAtURL(infoFileTmp, toURL: self.infoURL, error: &error)
            if error != nil {
                println("Unable to rename INFO temp copy to original: \(error!.localizedDescription).")
            }
            fileManager.removeItemAtURL(self.inventoryURL, error: &error)
            if error != nil {
                println("Unable to remove INVENTORY original: \(error!.localizedDescription).")
            }
            fileManager.moveItemAtURL(inventoryFileTmp, toURL: self.inventoryURL, error: &error)
            if error != nil {
                println("Unable to rename INVENTORY temp copy to original: \(error!.localizedDescription).")
            }
            // run the completion block, if any, on the main queue
            if let completion = completion {
                NSOperationQueue.mainQueue().addOperationWithBlock(completion)
            }
        })
    }
    
}