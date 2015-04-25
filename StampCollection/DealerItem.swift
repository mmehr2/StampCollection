//
//  DealerItem.swift
//  StampCollection
//
//  Created by Michael L Mehr on 4/15/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import Foundation
import CoreData

class DealerItem: NSManagedObject {

    @NSManaged var buy1: String
    @NSManaged var buy2: String
    @NSManaged var buy3: String
    @NSManaged var buy4: String
    @NSManaged var cat1: String
    @NSManaged var cat2: String
    @NSManaged var catgDisplayNum: Int16
    @NSManaged var descriptionX: String
    @NSManaged var group: String
    @NSManaged var id: String
    @NSManaged var oldprice1: String
    @NSManaged var oldprice2: String
    @NSManaged var oldprice3: String
    @NSManaged var oldprice4: String
    @NSManaged var pictid: String
    @NSManaged var pictype: String
    @NSManaged var price1: String
    @NSManaged var price2: String
    @NSManaged var price3: String
    @NSManaged var price4: String
    @NSManaged var status: String

    enum ValueType {
        case tInt(NSNumber)
        case tString(String)
    }
    
    private class func translateKeyName( nameIn: String ) -> String {
        var name = nameIn
        // translate key name if needed (not allowed to use 1st letter as capital, not allowed to use the word "description"
        switch name {
            case "CatgDisplayNum": name = "catgDisplayNum"
            case "description": name = name + "X"
            default: name = name.lowercaseString
        }
        return name
    }
    
    private class func typeForKeyName( name: String, withValue value: String ) -> ValueType {
        var output = ValueType.tString(value)
        // translate key name if needed (not allowed to use 1st letter as capital, not allowed to use the word "description"
        switch name {
        case "catgDisplayNum": output = ValueType.tInt(NSNumber(integer: value.toInt()!))
        default: break
        }
        return output
    }
    
    private class func setDataValuesForObject( newObject: DealerItem, fromData  data: [String : String]) -> DealerItem {
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
    
    static func makeObjectFromData( data: [String : String], inContext moc: NSManagedObjectContext? = nil) -> DealerItem? {
        // add a new object of this type to the moc
        if let moc = moc {
            let entityName = "DealerItem"
           if var newObject = NSEntityDescription.insertNewObjectForEntityForName(entityName, inManagedObjectContext: moc) as? DealerItem {
                return DealerItem.setDataValuesForObject(newObject, fromData: data)
            } else {
                // report error creating object in CoreData MOC
                println("Unable to make CoreData DealerItem from data \(data)")
            }
        }
        return nil
    }

}
