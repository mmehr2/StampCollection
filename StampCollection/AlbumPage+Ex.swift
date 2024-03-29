//
//  AlbumPage+Ex.swift
//  StampCollection
//
//  Created by Michael L Mehr on 5/15/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import Foundation
import CoreData

private let entityName = "AlbumPage"

extension AlbumPage {
    
    static func makeObjectWithName( _ name: String, forParent parent: AlbumSection ) -> Bool {
        if let context = parent.managedObjectContext {
            if let newObject = NSEntityDescription.insertNewObject(forEntityName: entityName, into: context) as? AlbumPage {
                newObject.code = name
                newObject.number = name.toFloat()! // page must be a valid number "10.1" or "23" in this implementation; allow suffixes later on perhaps?
                //newObject.descriptionX = ""
                newObject.section = parent
                return true
            }
        }
        return false
    }
    
    // MARK: find-or-create pattern implementation
    static func getObjectInImportData( _ data: [String:String], fromContext moc: NSManagedObjectContext? = nil ) -> AlbumPage? {
        // will do all of the following to make sure a valid page object exists, and if so, return it (if not, returns nil)
        // 1. gets code for the desired page from data field "AlbumPage"
        // 2. calls AlbumSection.getObjectInImportData() to get the section object that is the parent of this page, creating it if needed
        // 3. calls that object's getMemberObject() with the code from step 1 to get the desired page object, creating it if needed
        // 4. returns the object, or nil if anything goes wrong
        if let datacode = data[entityName],
            let obj = AlbumSection.getObjectInImportData(data, fromContext: moc) {
                return obj.getMemberObject(datacode, createIfNeeded: true)
        }
        return nil
    }
    
    var theItems: [InventoryItem] {
        guard let items = self.items else {
            return []
        }
        return Array(items) as! [InventoryItem]
    }
    
    var theTotalPrice: String {
        // will return the total price of theItems array which meet certain conditions
        // !wanted means they are in the existing inventory
        // canShowPrice is designed to only show the first price of a partial set, or an entire set
        let total = theItems.compactMap({
            !$0.wanted && $0.canShowPrice ? $0 : nil
        }).reduce(0.0, {
            $0 + ($1.itemPrice.toDouble() ?? 0.0)
        })
        return String(format: "%.2f", total)
    }
}
