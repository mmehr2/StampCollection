//
//  Category.swift
//  StampCollection
//
//  Created by Michael L Mehr on 4/15/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import Foundation

class Category: NSObject {

    var code: String
    var number: Int16
    var name: String
    var items: String
    var catalogs: String
    var prices: String

    override init() {
        number = Int16(CollectionStore.CategoryAll)
        code = ""; name = ""; catalogs = ""; prices = ""
        items = "0"
        super.init()
    }
    
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
    
    static func makeObjectFromData( data: [String : String] ) -> Category {
        return Category.setDataValuesForObject(Category(), fromData: data)
    }
}
