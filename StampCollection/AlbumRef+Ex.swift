//
//  AlbumRef+Ex.swift
//  StampCollection
//
//  Created by Michael L Mehr on 5/15/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import Foundation
import CoreData

private let entityName = "AlbumRef"

extension AlbumRef {
    
    static func makeCode(fromFamily fam: String, andNumber idx: Int) -> String {
        var retval = fam
        if idx < 10 {
            retval += "0"
        }
        retval += "\(idx)"
        return retval
    }
    
    static func getFamily(fromRef rcode: String) -> String {
        let (fam,_) = splitNumericEndOfString(rcode)
        return fam
    }
    
    static func getIndex(fromRef rcode: String) -> String {
        let (_,idx) = splitNumericEndOfString(rcode)
        return idx
    }
    
    var displayIndex: String {
        let idx = AlbumRef.getIndex(fromRef: code!)
        // get number of albums in family
        let albumCount = family!.theRefs.count
        // if there is only one album in the family, return ""
        if albumCount == 1 {
            return ""
        }
        // if there are <10, return index of code as single digit
        else if albumCount < 10 {
            return String(idx.last!)
        }
        // else return as index of code
        return idx
    }
    
    var displayName: String {
        var idx = AlbumRef.getFamily(fromRef: code!)
        idx += displayIndex
        return idx
    }
    
    fileprivate static func makeObjectWithName( _ name: String, inContext moc: NSManagedObjectContext? = nil, withRelationships relations: [String:NSManagedObject] = [:] ) -> Bool {
        if let context = moc {
            if let newObject = NSEntityDescription.insertNewObject(forEntityName: entityName, into: context) as? AlbumRef {
                newObject.code = name
                let numstr = getIndex(fromRef: name)
                newObject.number = Int16(Int(numstr) ?? 0)
                newObject.descriptionX = ""
                if let obj = relations["family"] as? AlbumFamily {
                    newObject.family = obj
                    // also update the ref value of the parent
                    obj.setMaxRef(newObject.number)
                }
                return true
            }
        }
        return false
    }
    
    fileprivate static func getObjectWithName( _ name: String, fromContext moc: NSManagedObjectContext? = nil ) -> AlbumRef? {
        if let context = moc {
            let rule = NSPredicate(format: "%K == %@", "code", name)
            return fetch(entityName, inContext: context, withFilter: rule).first as? AlbumRef
        }
        return nil
    }
    
    // get the Album family:String and ref:String (of a number) from the data's AlbumRef property
    static func getRefNameAndNumberFromData( _ data: [String:String] ) -> (String, String)? {
        // finds the data for "AlbumRef" and strips off the number at the end, if any
        if let name = data[entityName] , name.count > 2 {
            return (getFamily(fromRef: name), getIndex(fromRef: name))
        }
        return nil
    }
    
    // MARK: find-or-create pattern implementation
    static func getUniqueObject( _ name: String, fromContext moc: NSManagedObjectContext? = nil, createIfNeeded: Bool = false, withRelationships relations: [String:NSManagedObject] = [:]) -> AlbumRef? {
        // Will return the object of the given name
        // Relationship objects required for creation:
        //   family: AlbumFamily - the family to which this object belongs (and gets its number from)
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
    
    func getMemberObject( _ name: String, createIfNeeded: Bool = false) -> AlbumSection? {
        // Will return the AlbumSection object of the given name, if any, that is a member of this object's .sections list
        // If no object exists, and createIfNeeded is true, it will create the object of the given name with the proper relationships (to self)
        // If no object exists, and createIfNeeded is false, it will return nil
        for section in sections {
            if let thisSection = section as? AlbumSection , thisSection.code == name {
                return thisSection
            }
        }
        if createIfNeeded {
            if AlbumSection.makeObjectWithName(name, forParent: self) {
                return getMemberObject(name, createIfNeeded: false)
            }
        }
        return nil
    }
    
    static func getObjectInImportData( _ data: [String:String], fromContext moc: NSManagedObjectContext? = nil ) -> AlbumRef? {
        // will do all of the following to make sure a valid page object exists, and if so, return it (if not, returns nil)
        // 1. gets code of desired ref from data field "AlbumRef"
        // 2. calls AlbumFamily.getObjectInImportData() to get the proper relationship object for creation
        // 3. calls getUniqueObject() above to get the desired object, or create it if needed
        // 4. returns the object, or nil if anything goes wrong
        if let datacode = data[entityName],
            let parent = AlbumFamily.getObjectInImportData(data, fromContext: moc) {
                return getUniqueObject(datacode, fromContext: moc, createIfNeeded: true, withRelationships: ["family": parent])
        }
        return nil
    }

    var theSections: [AlbumSection] {
        guard let sections = self.sections else {
            return []
        }
        return Array(sections) as! [AlbumSection]
    }
    
    var theTotalPrice: String {
        // will return the total price of theSections array
        let total = theSections.reduce(0.0, {
            $0 + ($1.theTotalPrice.toDouble() ?? 0.0)
        })
        return String(format: "%.2f", total)
    }
}
