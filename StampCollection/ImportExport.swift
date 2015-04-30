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

class ImportExport: InfoParseable {
    enum Source {
        case Bundle
        // other cases may be added, such as:
        //case AirDrop
        //case EmailAttachment
    }
    
//    private var persistentStoreCoordinator: NSPersistentStoreCoordinator? {
//        let ad = UIApplication.sharedApplication().delegate! as! AppDelegate
//        return ad.persistentStoreCoordinator
//    }
    
    private var bundleURL: NSURL { return NSBundle.mainBundle().bundleURL }

    private var bundleInfoURL: NSURL { return bundleURL.URLByAppendingPathComponent("info.csv") }

    private var bundleInventoryURL: NSURL { return bundleURL.URLByAppendingPathComponent("inventory.csv") }

    private var bundleCategoryURL: NSURL { return  bundleURL.URLByAppendingPathComponent("baitcfg.csv") }
    
    lazy private var infoParser = InfoParserDelegate(namex: "INFO")
    
    lazy private var categoryParser = InfoParserDelegate(namex: "CATEGORY")
    
    lazy private var inventoryParser = InfoParserDelegate(namex: "INVENTORY")
    
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
    internal func parserDelegate(parserDelegate: CHCSVParserDelegate, foundData data: [String : String]) {
        // OPTIONAL: create persistent data objects for the parsed info
        if parserDelegate === categoryParser {
            CollectionStore.sharedInstance.addObject(Category.makeObjectFromData(data))
        }
        else if parserDelegate === infoParser {
            CollectionStore.sharedInstance.addObject(DealerItem.makeObjectFromData(data))
        }
        else if parserDelegate === inventoryParser {
            CollectionStore.sharedInstance.addObject(InventoryItem.makeObjectFromData(data))
        }
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
    private func loadData( parserDelegate: InfoParserDelegate, fromFile file: NSURL ) {
        // this does blocking (synchronous) parsing of the files
        if let basicParser = CHCSVParser(contentsOfCSVURL: file) {
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
                self.loadData(self.categoryParser, fromFile: self.categoryURL)
                self.loadData(self.infoParser, fromFile: self.infoURL)
                self.loadData(self.inventoryParser, fromFile: self.inventoryURL)
                // save the data in CoreData too, if needed
            }
            // run the completion block, if any, on the main queue
            if let completion = completion {
                NSOperationQueue.mainQueue().addOperationWithBlock(completion)
            }
        })
        
    }

    // MARK: - data export
    // NOTE: exmports to CSV files in user's Documents folder
    private func writeData( data: [[String:String]], toCSVFile file: NSURL,
        withHeaders headers: [String] )
    {
        if let basicWriter = CHCSVWriter(forWritingToCSVFile: file.path) {
            basicWriter.writeLineOfFields(headers)
            for dictObject in data {
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
    
    func exportData( compare: Bool,
        completion: (() -> Void)? )
    {
        // do this on a background thread
        NSOperationQueue().addOperationWithBlock({
            // this does blocking (synchronous) writing of the files
            var categoryFileTmp = self.categoryURL.URLByAppendingPathExtension("tmp")
            var infoFileTmp = self.infoURL.URLByAppendingPathExtension("tmp")
            var inventoryFileTmp = self.inventoryURL.URLByAppendingPathExtension("tmp")
            self.writeData(self.categoryParser.records, toCSVFile: categoryFileTmp, withHeaders: self.categoryParser.headers)
            println("Completed writing \(categoryFileTmp.lastPathComponent!)")
            self.writeData(self.infoParser.records, toCSVFile: infoFileTmp, withHeaders: self.infoParser.headers)
            println("Completed writing \(infoFileTmp.lastPathComponent!)")
            self.writeData(self.inventoryParser.records, toCSVFile: inventoryFileTmp, withHeaders: self.inventoryParser.headers)
            println("Completed writing \(inventoryFileTmp.lastPathComponent!)")
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
            fileManager.removeItemAtURL(self.categoryURL, error: nil)
            fileManager.moveItemAtURL(categoryFileTmp, toURL: self.categoryURL, error: nil)
            fileManager.removeItemAtURL(self.infoURL, error: nil)
            fileManager.moveItemAtURL(infoFileTmp, toURL: self.infoURL, error: nil)
            fileManager.removeItemAtURL(self.inventoryURL, error: nil)
            fileManager.moveItemAtURL(inventoryFileTmp, toURL: self.inventoryURL, error: nil)
            // run the completion block, if any, on the main queue
            if let completion = completion {
                NSOperationQueue.mainQueue().addOperationWithBlock(completion)
            }
        })
    }
    
}