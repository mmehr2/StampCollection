//
//  InventoryItem.swift
//  StampCollection
//
//  Created by Michael L Mehr on 4/15/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import Foundation

class InventoryItem: NSObject {

    var albumPage: String
    var albumRef: String
    var albumSection: String
    var albumType: String
    var baseItem: String
    var catgDisplayNum: Int16
    var desc: String
    var itemType: String
    var notes: String
    var refItem: String
    var wantHave: String
    
    enum ValueType {
        case tInt(NSNumber)
        case tString(String)
    }
    
    override init() {
        catgDisplayNum = Int16(CollectionStore.CategoryAll)
        baseItem = ""; desc = ""; notes = ""; refItem = ""
        wantHave = ""; itemType = "0"
        wantHave = ""
        albumPage = ""; albumRef = ""; albumSection = ""; albumType = ""
        super.init()
    }
    
    private class func translateKeyName( nameIn: String ) -> String {
        var name = nameIn
        // translate key name if needed (not allowed to use 1st letter as capital, not allowed to use the word "description"
        switch name {
        //case "CatgDisplayNum": name = "catgDisplayNum"
        default:
            // need to lowercase the 1st character in the name (DANG! THIS IS CONVOLUTED! Thanks, Unicode!)
            let index = name.startIndex.successor()
            let firstCharLC = name.substringToIndex(index).lowercaseString
            let rest = name.substringFromIndex(index)
            name = firstCharLC.stringByAppendingString(rest)
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
    
    private class func setDataValuesForObject( newObject: InventoryItem, fromData  data: [String : String]) -> InventoryItem {
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
    
    static func makeObjectFromData( data: [String : String] ) -> InventoryItem {
        return InventoryItem.setDataValuesForObject(InventoryItem(), fromData: data)
    }

}
