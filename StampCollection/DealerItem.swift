//
//  DealerItem.swift
//  StampCollection
//
//  Created by Michael L Mehr on 4/15/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import Foundation

class DealerItem: NSObject {

    var buy1: String
    var buy2: String
    var buy3: String
    var buy4: String
    var cat1: String
    var cat2: String
    var catgDisplayNum: Int16
    var descriptionX: String
    var group: String
    var id: String
    var oldprice1: String
    var oldprice2: String
    var oldprice3: String
    var oldprice4: String
    var pictid: String
    var pictype: String
    var price1: String
    var price2: String
    var price3: String
    var price4: String
    var status: String

    enum ValueType {
        case tInt(NSNumber)
        case tString(String)
    }
    
    override init() {
        catgDisplayNum = Int16(CollectionStore.CategoryAll)
        id = ""; descriptionX = ""; group = ""; status = ""
        pictid = ""; pictype = "0"
        cat1 = ""; cat2 = ""
        price1 = ""; price2 = ""; price3 = ""; price4 = ""
        buy1 = ""; buy2 = ""; buy3 = ""; buy4 = ""
        oldprice1 = ""; oldprice2 = ""; oldprice3 = ""; oldprice4 = ""
        super.init()
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
    
    static func makeObjectFromData( data: [String : String] ) -> DealerItem {
        return DealerItem.setDataValuesForObject(DealerItem(), fromData: data)
    }

    static func filterArray( collection: [DealerItem], byCategory category: Int ) -> [DealerItem] {
        if category == CollectionStore.CategoryAll {
            return collection
        }
        return collection.filter { x in
            x.catgDisplayNum == Int16(category)
        }
    }
    
    enum SortType {
        case ByCode, ByDesc, ByPrice, ByDate
    }
    
    static func isOrderedByCode( ob1: DealerItem, ob2: DealerItem ) -> Bool {
        return true
    }
    
    static func isOrderedByDate( ob1: DealerItem, ob2: DealerItem ) -> Bool {
        let date1str = extractDateFromDesc(ob1.descriptionX)
        return true
    }
}
