//
//  EmailAttachmentImporter.swift
//  StampCollection
//
//  Created by Michael L Mehr on 4/28/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import UIKit

// this class will import a single file that contains the contents of all three needed files:
//  CATEGORY.CSV
//  INFO.CSV
//  INVENTORY.CSV

// The file format is only documented here. It should consist of 

class EmailAttachmentImporter {
    //var controller: UIViewController!
    
    //var errFunc : ((NSError) -> Void)?
    
    //init( forController vc: UIViewController, errorHandler: ((NSError) -> Void)? = nil ) {
    //    //super.init()
    //    controller = vc
    //    errFunc = errorHandler
    //}
    
    static func receiveFiles(_ zipFileurl: URL) -> Bool {
        print("Application invoked to open SCZP file at URL = \(zipFileurl)")

        let ad = UIApplication.shared.delegate! as! AppDelegate
        let dest = ad.applicationDocumentsDirectory
        
        let file1 = "category.csv"
        let file2 = "info.csv"
        let file3 = "inventory.csv"
        let file1url = ad.applicationDocumentsDirectory.appendingPathComponent(file1)
        let file2url = ad.applicationDocumentsDirectory.appendingPathComponent(file2)
        let file3url = ad.applicationDocumentsDirectory.appendingPathComponent(file3)
        
        print("Will unzip to \(dest)")
        let unzipArchiveOK = SSZipArchive.unzipFile(atPath: zipFileurl.path, toDestination:dest.path)
        if !unzipArchiveOK {
            print("Unable to unzip file to dest.")
            return false
        }
        
        print("Successful unzip to component files.")
        // check file existence first, to make sure we can send
        // fail if we can't send them all
        let fileManager = FileManager.default
        let file1exists = fileManager.fileExists(atPath: file1url.path)
        let file2exists = fileManager.fileExists(atPath: file2url.path)
        let file3exists = fileManager.fileExists(atPath: file3url.path)
        if !(file1exists && file2exists && file3exists) {
            if !file1exists { print("Error preparing for email import: \(file1url.path) doesn't exist.") }
            if !file2exists { print("Error preparing for email import: \(file2url.path) doesn't exist.") }
            if !file3exists { print("Error preparing for email import: \(file3url.path) doesn't exist.") }
            return false
        }
        
        print("Ready to start import process - should we allow cancellation? Sure, why not.")
        return true
    }
   
}
