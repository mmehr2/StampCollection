//
//  Category.swift
//  StampCollection
//
//  Created by Michael L Mehr on 4/15/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import Foundation
import CoreData

class Category: NSManagedObject {

    @NSManaged var code: String
    @NSManaged var number: Int16
    @NSManaged var name: String
    @NSManaged var items: String
    @NSManaged var catalogs: String
    @NSManaged var prices: String

    
    enum ValueType {
        case tInt(NSNumber)
        case tString(String)
    }
    
    private class func translateKeyName( nameIn: String ) -> String {
        var name = nameIn
        // translate key name if needed (not allowed to use 1st letter as capital, not allowed to use the word "description"
        switch name {
        case "#": name = "number"
        default: name = name.lowercaseString
        }
        return name
    }
    
    private class func typeForKeyName( name: String, withValue value: String ) -> ValueType {
        var output = ValueType.tString(value)
        // translate key name if needed (not allowed to use 1st letter as capital, not allowed to use the word "description"
        switch name {
        case "number": output = ValueType.tInt(NSNumber(integer: value.toInt()!))
        default: break
        }
        return output
    }

    private class func setDataValuesForObject( newObject: Category, fromData  data: [String : String]) -> Category {
        for (key, value) in data {
            // translate key name if needed (not allowed to use 1st letter as capital, not allowed to use the word "description"
            let keyName = translateKeyName(key)
            // set the attributes of the new object (allows Int16 type or String type, for now)
            let valueType = typeForKeyName( keyName, withValue: value )
            switch valueType {
            case .tInt (let val): newObject.setValue(val, forKey: keyName)
            case .tString: newObject.setValue(value, forKey: keyName)
            }
        }
        return newObject
    }
    
    static func makeObjectFromData( data: [String : String], inContext moc: NSManagedObjectContext? = nil) -> Category? {
        // add a new object of this type to the moc
        if let moc = moc {
            let entityName = "Category"
            if var newObject = NSEntityDescription.insertNewObjectForEntityForName(entityName, inManagedObjectContext: moc) as? Category {
                return Category.setDataValuesForObject(newObject, fromData: data)
            } else {
                // report error creating object in CoreData MOC
                println("Unable to make CoreData Category from data \(data)")
            }
        }
        return nil
    }
}
