//
//  AlbumSection+Ex.swift
//  StampCollection
//
//  Created by Michael L Mehr on 5/15/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import Foundation
import CoreData

private let entityName = "AlbumSection"

extension AlbumSection {
    
    static func makeObjectWithName( name: String, forParent parent: AlbumRef ) -> Bool {
        if let context = parent.managedObjectContext {
            if var newObject = NSEntityDescription.insertNewObjectForEntityForName(entityName, inManagedObjectContext: context) as? AlbumSection {
                newObject.code = name
                newObject.ordinal = 0 // could assign these on creation order, but needs to be editable or at least renumberable at runtime
                newObject.descriptionX = ""
                newObject.ref = parent
                return true
            }
        }
        return false
    }
    
    // MARK: find-or-create pattern implementation
    func getMemberObject( name: String, createIfNeeded: Bool = false) -> AlbumPage? {
        // Will return the object of the given name (page number code), if any, that is a member of this section object's .pages list
        // If no object exists, and createIfNeeded is true, it will create the object of the given name with the proper relationships (to self)
        // If no object exists, and createIfNeeded is false, it will return nil
        for obj in pages {
            if let thisPage = obj as? AlbumPage where thisPage.code == name {
                return thisPage
            }
        }
        if createIfNeeded {
            if AlbumPage.makeObjectWithName(name, forParent: self) {
                return getMemberObject(name, createIfNeeded: false)
            }
        }
        return nil
    }
    
    static func getObjectInImportData( data: [String:String], fromContext moc: NSManagedObjectContext? = nil ) -> AlbumSection? {
        // will do all of the following to make sure a valid page object exists, and if so, return it (if not, returns nil)
        // 1. gets code for the desired section from data field "AlbumSection"
        // 2. calls AlbumRef.getObjectInImportData() to get the proper album object, creating it if needed
        // 3. calls that object's getMemberObject() to get the appropriate section object for the given code in step 1, creating it if needed
        // 4. returns the object, or nil if anything goes wrong
        if let datacode = data[entityName],
            album = AlbumRef.getObjectInImportData(data, fromContext: moc) {
                return album.getMemberObject(datacode, createIfNeeded: true)
        }
        return nil
    }
    
}