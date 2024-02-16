//
//  InventoryItem+Ex.swift
//  StampCollection
//
//  Created by Michael L Mehr on 5/6/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import Foundation
import CoreData

/*
This class provides useful extensions to the CoreData object model classes, to allow them to remain re-generateable by XCode 6.3.
Currently it seems that these generated classes are all @NSManaged properties, and any additions will be clobbered.
*/

// TOTAL DEBUGGING KLUDGE!
private var lastCreatedInventoryObject: InventoryItem?

extension InventoryItem:  SortTypeSortableEx {
    
    static func getLastCreatedInventoryObject() -> InventoryItem? {
        return lastCreatedInventoryObject
    }
    
    var normalizedCode: String {
        return dealerItem.normalizedCode
    }
    
    var normalizedDate: String {
        return dealerItem.normalizedDate
    }
    
    var plateNumber: Int {
        return dealerItem.plateNumber
    }

    var wanted: Bool {
        return self.wantHave == "w"
    }

    // This code was designed to check both description fields (INV and INFO), but then I rediscovered that
    //  the 6110t category has already created prices for each partial set entry, so this is no longer needed. Oops.
    // The real utility of this test is to prevent duplication of prices in partial sets derived from Zvi's site, esp.cat 24 (Special Sheets)
    //   where he was selling the entire sheet set as one entity with one overall price. The same issue would appear in the Sets category (2)
    //   when sets would be split over multiple pages (for example, Town Emblems I and II).
    //   Manual price splitting by inventory entries would duplicate these full-set prices unless this code weeded them out.
    // Basically, a designated Partial set will only show prices for the 1st partial, not the others (I limited testing to #2-9).
    private func isDescPartial(desc str: String, nth: Bool, useWord: Bool) -> Bool
    {
        var result = true
        var debug = "Partial[\(str)]?="
        var res = false
        if useWord {
            res = str.contains("Partial")
            debug += " Word(\(res))"
            result = result && res
        }
        if #available(iOS 16.0, *) {
            if !nth {
                res = str.contains("#1/")
                debug += " #1(\(res))"
                result = result && res
            }
            else
            {
                res = str.contains(/#[2-9]\//) // Regex
                debug += " #N(\(res))"
                result = result && res
            }
        } else {
            // Fallback on earlier versions
            if (!nth) {
                result = result && str.contains("#1/")
            }
            else
            {
                result = result && str.contains("#2/") || str.contains("#3/") || str.contains("#4/") || str.contains("#5/") || str.contains("#6/") || str.contains("#7/") || str.contains("#8/") || str.contains("#9/")
            }
        }
        //print(debug)
        return result
    }
    
    private var firstPartial: Bool {
        //if self.desc.isEmpty
        //{
        //    return isDescPartial(desc: self.dealerItem.descriptionX, nth: false, useWord: false)
        //}
        return isDescPartial(desc: self.desc, nth: false, useWord: true)
    }

    private var nthPartial: Bool {
        //if self.desc.isEmpty
        //{
        //    return isDescPartial(desc: self.dealerItem.descriptionX, nth: true, useWord: false)
        //}
        return isDescPartial(desc: self.desc, nth: true, useWord: true)
    }

    var canShowPrice: Bool {
        return self.desc.isEmpty || self.firstPartial || !self.nthPartial
    }

    var itemCondition: String {
        let prices = self.category.prices!
        let conds: [String:String]
        switch prices {
        case "PF": conds = ["price1":"Mint", "price2":"FDC"]
        default: conds = ["price1":"Mint", "price2":"Used", "price3":"OnFDC", "price4":"M/NT"]
        }
        return conds[itemType]!
    }
    
    var itemPrice: String {
        return self.dealerItem.getPrice(itemType)
    }

    func updateBaseItem( _ item: DealerItem ) {
        let newID = item.id
        self.baseItem = newID
        self.dealerItem = item
    }
    
    func updateRefItem( _ item: DealerItem ) {
        let newID = item.id
        self.refItem = newID
        self.referredItem = item
    }
    
    enum ValueType {
        case tInt(NSNumber)
        case tString(String)
    }
    
    fileprivate static func translateKeyName( _ nameIn: String, forExport: Bool = false ) -> String {
        var name = nameIn
        // translate key name if needed (not allowed to use 1st letter as capital, not allowed to use the word "description"
        switch name {
            //case "CatgDisplayNum": name = "catgDisplayNum"
        default:
            // need to lowercase the 1st character in the name
            let index = name.index(after: name.startIndex)
            let firstChar = forExport ? name[..<index].uppercased() : name[..<index].lowercased()
            let rest = name[index...]
            name = firstChar + rest
        }
        return name
    }
    
    fileprivate static func typeForKeyName( _ name: String, withValue value: String ) -> ValueType {
        var output = ValueType.tString(value)
        // translate key name if needed (not allowed to use 1st letter as capital, not allowed to use the word "description"
        switch name {
        case "catgDisplayNum": output = ValueType.tInt(NSNumber(value: Int(value)! as Int))
        case "exOrder": output = ValueType.tInt(NSNumber(value: Int(value)! as Int)) // autosequencing property generated by import processor
        default: break
        }
        return output
    }
    
    fileprivate static func setDataValuesForObject( _ newObject: InventoryItem, fromData  data: [String : String]) {
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
        // create fixups and extracted data properties here
    }
        
    static func makeObjectFromData( _ data: [String : String], withRelationships relations: [String:NSManagedObject], inContext moc: NSManagedObjectContext? = nil) -> Bool {
        // add a new object of this type to the moc
        if let moc = moc {
            let entityName = "InventoryItem"
            if let newObject = NSEntityDescription.insertNewObject(forEntityName: entityName, into: moc) as? InventoryItem {
                // set the relationships back to the proper objects
                if let robj = relations["referredItem"] as? DealerItem {
                    newObject.referredItem = robj
                }
                if let mobj = relations["dealerItem"] as? DealerItem {
                    newObject.dealerItem = mobj
                }
                if let cobj = relations["category"] as? Category {
                    newObject.category = cobj
                }
                if let pobj = relations["page"] as? AlbumPage {
                    newObject.page = pobj
                }
                // set all the other data values here, so it can use related object reference data
                InventoryItem.setDataValuesForObject(newObject, fromData: data)
                lastCreatedInventoryObject = newObject // optional reference usage by single-item creators
                return true
            } else {
                // report error creating object in CoreData MOC
                print("Unable to make CoreData InventoryItem from data \(data)")
            }
        }
        return false
    }
    
    // return the names of the data properties, in import/export order (from the CSV file)
    static func getDataHeaderNames() -> [String] {
        var output : [String] = []
        //In Defined Order for CSV file:
        // WantHave, BaseItem,ItemType, AlbumType,AlbumRef,AlbumSection,AlbumPage, RefItem, Desc,Notes, CatgDisplayNum
        output.append("wantHave")
        output.append("baseItem")
        output.append("itemType")
        output.append("albumType")
        output.append("albumRef")
        output.append("albumSection")
        output.append("albumPage")
        output.append("refItem")
        output.append("desc")
        output.append("notes")
        output.append("catgDisplayNum")
        return output
    }
    
    static func getExportHeaderNames() -> [String] {
        var output : [String] = []
        //In Defined Order for CSV file:
        // WantHave, BaseItem,ItemType, AlbumType,AlbumRef,AlbumSection,AlbumPage, RefItem, Desc,Notes, CatgDisplayNum
        output = getDataHeaderNames().map { x in
            self.translateKeyName(x, forExport: true)
        }
        return output
    }
    
    func makeDataFromObject() -> [String : String] {
        var output: [String : String] = [:]
        let headerNames = InventoryItem.getDataHeaderNames()
        //println("InventoryItem header names are \(headerNames)")
        for headerName in headerNames {
            let keyname = InventoryItem.translateKeyName(headerName, forExport: true)
            switch headerName {
            case "wantHave", "baseItem", "itemType", "desc", "notes", "refItem"
            , "albumPage", "albumRef", "albumSection", "albumType":
                let value = self.value(forKey: headerName) as? String ?? ""
                output[keyname] = value
                break
            case "catgDisplayNum":
                let value = self.value(forKey: headerName) as? Int ?? 0
                output[keyname] = "\(value)"
                break
            default: break // ignore any auto-generated properties; we just want the basics
            }
        }
        //println("New InventoryItem data is \(output)")
        return output
    }

}
