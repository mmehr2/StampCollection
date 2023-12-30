//
//  AlbumType+Ex.swift
//  StampCollection
//
//  Created by Michael L Mehr on 5/15/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import Foundation
import CoreData

// NOTE: cannot use static let here in Swift 1.2,3.x ("both final and dynamic" error): see http://stackoverflow.com/questions/29814706/a-declaration-cannot-be-both-final-and-dynamic-error-in-swift-1-2
// HOW TO GET SWIFT CLASS NAMES: http://stackoverflow.com/questions/24006165/how-do-i-print-the-type-or-class-of-a-variable-in-swift

private let entityName = "AlbumType"

extension AlbumType {
    
    @nonobjc private static var theObjects: [AlbumType] = []
    
    private static func seenObject(_ obj: AlbumType) -> Bool {
        for objx in theObjects {
            if let id = objx.code, id == obj.code! {
                return true
            }
        }
        return false
    }
    
    static func setObjects(_ fetchedObjects: [AlbumType]) {
        // func to set this when needed if it is empty by calling CollectionStore.fetch("AlbumSection",...)
        theObjects = fetchedObjects
    }
    
    static var allTheNames: [String] {
        var result: [String] = []
        for obj in theObjects {
            let c = obj.code!
            if !result.contains(c) {
                result.append(c)
            }
        }
        return result
    }
    
    fileprivate static func makeObjectWithName( _ name: String, inContext moc: NSManagedObjectContext? = nil ) -> Bool {
        if let context = moc {
            if let newObject = NSEntityDescription.insertNewObject(forEntityName: entityName, into: context) as? AlbumType {
                newObject.code = name
                newObject.ordinal = 0
                newObject.descriptionX = ""
                if !seenObject(newObject) {
                    theObjects.append( newObject )
                }
                return true
            }
        }
        return false
    }
    
    fileprivate static func getObjectWithName( _ name: String, fromContext moc: NSManagedObjectContext? = nil ) -> AlbumType? {
        if let context = moc {
            let rule = NSPredicate(format: "%K == %@", "code", name)
            return fetch(entityName, inContext: context, withFilter: rule).first as? AlbumType
        }
        return nil
    }
    
    fileprivate static func getUniqueObject( _ name: String, fromContext moc: NSManagedObjectContext? = nil, createIfNeeded: Bool = false) -> AlbumType? {
        // Will return the object of the given name
        // Relationship objects required for creation: None.
        // If no object exists, and createIfNeeded is true, it will create the object of the given name
        // If no object exists, and createIfNeeded is false, it will return nil
        if let obj = getObjectWithName(name, fromContext: moc) {
            return obj
        } else if createIfNeeded {
            if makeObjectWithName(name, inContext: moc) {
                return getUniqueObject(name, fromContext: moc, createIfNeeded: false)
            }
        }
        return nil
    }
    
    static func getObjectInImportData( _ data: [String:String], fromContext moc: NSManagedObjectContext? = nil ) -> AlbumType? {
        // will do all of the following to make sure a valid type object exists, and if so, return it (if not, returns nil)
        // 1. gets code of desired ref from data field "AlbumType"
        // 2. calls getUniqueObject() above to make sure proper object exists, and if not, creates it
        // 3. returns the object, or nil if anything goes wrong
        if let datacode = data[entityName] {
            return getUniqueObject(datacode, fromContext: moc, createIfNeeded: true)
        }
        return nil
    }
    
    var theFamilies: [AlbumFamily] {
        guard let families = self.families else {
            return []
        }
        return Array(families) as! [AlbumFamily]
    }
    
    var theTotalPrice: String {
        // will return the total price of theRefs array
        let total = theFamilies.reduce(0.0, {
            $0 + ($1.theTotalPrice.toDouble() ?? 0.0)
        })
        return String(format: "%.2f", total)
    }
}

