//
//  AlbumFamily+Ex.swift
//  StampCollection
//
//  Created by Michael L Mehr on 5/15/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import Foundation
import CoreData

private let entityName = "AlbumFamily"

extension AlbumFamily {
    
    private static func makeObjectWithName( name: String, inContext moc: NSManagedObjectContext? = nil, withRelationships relations: [String:NSManagedObject] = [:] ) -> Bool {
        if let context = moc {
            if let newObject = NSEntityDescription.insertNewObjectForEntityForName(entityName, inManagedObjectContext: context) as? AlbumFamily {
                newObject.code = name
                newObject.nextRef = 0 // needs to be maintained dynamically (call setMaxRef() as new refs are added for this family
                newObject.descriptionX = ""
                if let obj = relations["type"] as? AlbumType {
                    newObject.type = obj
                }
                return true
            }
        }
        return false
    }
    
    private static func getObjectWithName( name: String, fromContext moc: NSManagedObjectContext? = nil ) -> AlbumFamily? {
        if let context = moc {
            let rule = NSPredicate(format: "%K == %@", "code", name)
            return fetch(entityName, inContext: context, withFilter: rule).first as? AlbumFamily
        }
        return nil
    }
    
    // MARK: find-or-create pattern implementation
    private static func getUniqueObject( name: String, fromContext moc: NSManagedObjectContext? = nil, createIfNeeded: Bool = false, withRelationships relations: [String:NSManagedObject] = [:]) -> AlbumFamily? {
        // Will return the object of the given name
        // Fetch predicate: SELF.code == 'name'
        // Relationship objects required for creation:
        //   type: AlbumType - the type of album family being created
        // If no object exists, and createIfNeeded is true, it will create the object of the given name with the proper relationships
        // If no object exists, and createIfNeeded is false, it will return nil
        if let obj = getObjectWithName(name, fromContext: moc) {
            return obj
        } else if createIfNeeded {
            if makeObjectWithName(name, inContext: moc, withRelationships: relations) {
                return getUniqueObject(name, fromContext: moc, createIfNeeded: false)
            }
        }
        return nil
    }
    
    static func getObjectInImportData( data: [String:String], fromContext moc: NSManagedObjectContext? = nil ) -> AlbumFamily? {
        // will do all of the following to make sure a valid object exists, and if so, return it (if not, returns nil)
        // 1. gets code of desired family from data field "AlbumRef" (strips off integer at end, if any)
        // 2. calls AlbumType.getObjectInImportData() to get the proper relationship object
        // 3. calls getUniqueObject above to get the family object, creating it if needed using the object from step 2
        // 4. returns the object, or nil if anything goes wrong
        if let (datacode, _) = AlbumRef.getRefNameAndNumberFromData(data),
            parent = AlbumType.getObjectInImportData(data, fromContext: moc) {
                return getUniqueObject(datacode, fromContext: moc, createIfNeeded: true, withRelationships: ["type": parent])
        }
        return nil
    }
    
    
    // MARK: member functions
    func setMaxRef( refCandidate: Int16 ) {
        if refCandidate > self.nextRef {
            self.nextRef = refCandidate
        }
    }
    
    var theRefs: [AlbumRef] {
        return Array(refs) as! [AlbumRef]
    }
}
