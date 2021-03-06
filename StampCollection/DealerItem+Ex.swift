//
//  DealerItem+Ex.swift
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

class InfoDependentVars {
    var _normalizedCode: String?
    var _exNormalizedStartDate: String?
    var _exNormalizedEndDate: String?
    var _exNormalizedDate: String?
    var _exStartDate: Date?
    var _exEndDate: Date?
    var _exSheetPlateNumber: Int?

    init(descr: String = "", id: String = "", cat: Int16 = (-1)) {
        update(descr, id: id, cat: cat)
    }
    
    func update(_ descr: String = "", id: String = "", cat: Int16 = (-1)) {
        updateKey("descriptionX", value: descr)
        updateKey("id", value: id, extra: cat)
    }
    
    fileprivate func updateKey(_ keyPath: String, value: String, extra: Int16 = 0) {
        /*
        NOTE: If regenerating DealerItem automatically, copy the following additional cache fields back:
        
        // cached fields - REPLACE AFTER OVERWRITING
        var _transientVars: InfoDependentVars?
        */
        
        // call this when setting descriptionX so that the dependents can be updated too
        if keyPath == "descriptionX" {
            // Update date range vars from descriptionX
            // NOTE: if start is set, end is set; if year is set, month and day will also be set; if not recognized, Y=M=D=0
            let (_, daterange) = extractDateRangesFromDescription(value)
            _exStartDate = daterange.lowerBound
            _exEndDate = daterange.upperBound
            _exNormalizedStartDate = normalizedStringFromDate(_exStartDate!)
            _exNormalizedEndDate = normalizedStringFromDate(_exEndDate!)
            _exNormalizedDate = _exNormalizedStartDate! + "-" + _exNormalizedEndDate!
            _exSheetPlateNumber = extractPlateNumberFromSheetDescription(value);
        } else if keyPath == "id" {
            // Update _normalizedCode from id (NOTE: requires date range to be set 1st!)
            var postE1K = false
            let catgDisplayNum = extra
            let id = value
            if catgDisplayNum == 3 || catgDisplayNum == 24 || catgDisplayNum == 25 {
                if String(id.prefix(4)) == "6110e" {
                    if let exd = _exStartDate {
                        let (y, _, _) = componentsFromDate(exd)
                        postE1K = y >= 2000
                    }
                }
            }
            //println("Normalizing ID=\(id) catnum=\(catgDisplayNum), E1K=\(postE1K)")
            _normalizedCode = normalizeIDCode(value, forCat: catgDisplayNum, isPostE1K: postE1K)
        }
        
    }
}

extension DealerItem: SortTypeSortable {
    
    func updateDependentVars() {
        _transientVars = InfoDependentVars(descr: descriptionX, id: id, cat: catgDisplayNum)
    }

    override func awakeFromFetch() {
        super.awakeFromFetch()
        // update transient variables (non-managed)
        updateDependentVars()
    }

    var normalizedCode: String {
        if _transientVars == nil { updateDependentVars() }
        return _transientVars!._normalizedCode!
    }
    
    var normalizedDate: String {
        if _transientVars == nil { updateDependentVars() }
        return _transientVars!._exNormalizedDate!
    }
    
    var isJS: Bool {
        if id.count > 2 {
            return id.hasPrefix("AUI")
        }
        return false
    }
    
    var plateNumber: Int {
        if _transientVars == nil { updateDependentVars() }
        return _transientVars!._exSheetPlateNumber ?? 0
    }
    
    var picPageURL: URL? {
        if catgDisplayNum == CATEG_BULLETINS || catgDisplayNum == CATEG_INFOLDERS { return nil }
        return getPicRefURL(pictid, refType: isJS ? .dljsRef  : .dlRef)
    }
    
    var picFileRemoteURL: URL? {
        return getPicFileRemoteURL(pictid, refType: isJS ? .dljsRef  : .dlRef, category: Int(catgDisplayNum))
    }
    
    var picFileLocalURL: URL? {
        return getPicFileLocalURL(pictid, refType: isJS ? .dljsRef  : .dlRef, category: catgDisplayNum)
    }
    
    func getPrice(_ type: String) -> String {
        switch type {
        case "price1": return price1
        case "price2": return price2
        case "price3": return price3
        case "price4": return price4
        default: return ""
        }
    }
    
    func getOldPrice(_ type: String) -> String {
        switch type {
        case "price1": return oldprice1
        case "price2": return oldprice2
        case "price3": return oldprice3
        case "price4": return oldprice4
        default: return ""
        }
    }
    
    func getBuyURL(_ type: String) -> String {
        switch type {
        case "price1": return buy1
        case "price2": return buy2
        case "price3": return buy3
        case "price4": return buy4
        default: return ""
        }
    }
    
    enum ValueType {
        case tInt(NSNumber)
        case tString(String)
    }
 
    fileprivate static func translateKeyName( _ nameIn: String ) -> String {
        var name = nameIn
        // translate key name if needed (not allowed to use 1st letter as capital, not allowed to use the word "description"
        switch name {
        case "CatgDisplayNum": name = "catgDisplayNum"
        case "description": name = name + "X"
        case "catgDisplayNum": name = "CatgDisplayNum" // for export
        case "descriptionX": name = "description" // for export
        default: break //name = name.lowercaseString
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
    
    fileprivate static func setDataValuesForObject( _ newObject: DealerItem, fromData  data: [String : String]) {
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
        //newObject.updateDependentVars()
    }
    
    static func makeObjectFromData( _ data: [String : String], withRelationships relations: [String:NSManagedObject], inContext moc: NSManagedObjectContext? = nil) -> Bool {
        // add a new object of this type to the moc
        if let moc = moc {
            let entityName = "DealerItem"
            if let newObject = NSEntityDescription.insertNewObject(forEntityName: entityName, into: moc) as? DealerItem {
                // set the relationship back to the proper Category object
                if let mobj = relations["category"] as? Category {
                    newObject.category = mobj
                }
                // set all the other data values here, so it can use related object reference data
                DealerItem.setDataValuesForObject(newObject, fromData: data)
                return true
            } else {
                // report error creating object in CoreData MOC
                print("Unable to make CoreData DealerItem from data \(data)")
            }
        }
        return false
    }
    
    func updateFromData( _ data: [String : String] ) {
        let oldID = self.id
        DealerItem.setDataValuesForObject( self, fromData: data )
        _transientVars = nil // refresh the extracted transient data
        // if we detect that the ID code has changed,
        //  we need to update any dependent relationships to reflect that new ID string
        let newID = self.id
        if newID != oldID {
            for item in inventoryItems {
                if let invItem = item as? InventoryItem {
                    invItem.baseItem = newID
                }
            }
            for item in referringItems {
                if let invItem = item as? InventoryItem {
                    invItem.refItem = newID
                }
            }
        }
    }

    // MARK: special pictypes
    // These items are generated parts of the database but aren't sold by the supported dealers at this time
    // Thus, they don't participate in Updates and may have other properties regarding Inventory
    var autoGenerated: Bool {
        return pictype == "-1"
    }
    
    func markAsAutoGenerated() {
        self.pictype = "-1"
    }
    
    // This feature is used in lieu of database removal, to keep a record of old ID numbers supported in the past, esp.if I have inventory based on them
    // The idea is to reassign inventory to either an AutoGenerated number or a different active ID (eventually)
    var retired: Bool {
        return id.test("retired$")
    }
    
    func markAsRetired() {
        switch pictype {
        case "0": pictype = "-2"
        case "1": pictype = "-3"
        default: break
        }
        if !retired {
            id = id + "retired"
        }
    }
    
    // return the names of the data properties, in import/export order (from the CSV file)
    static func getDataHeaderNames() -> [String] {
        var output : [String] = []
        //In Defined Order for CSV file:
        // id, description, status,pictid, pictype,group, cat1,cat2, price1,price2,price3,price4, buy1,buy2,buy3,buy4, oldprice1,oldprice2,oldprice3,oldprice4, CatgDisplayNum
        output.append("id")
        output.append("descriptionX")
        output.append("status")
        output.append("pictid")
        output.append("pictype")
        output.append("group")
        output.append("cat1")
        output.append("cat2")
        output.append("price1")
        output.append("price2")
        output.append("price3")
        output.append("price4")
        output.append("buy1")
        output.append("buy2")
        output.append("buy3")
        output.append("buy4")
        output.append("oldprice1")
        output.append("oldprice2")
        output.append("oldprice3")
        output.append("oldprice4")
        output.append("catgDisplayNum")
        return output
    }
    
    static func getExportHeaderNames() -> [String] {
        var output : [String] = []
        //In Defined Order for CSV file:
        // id, description, status,pictid, pictype,group, cat1,cat2, price1,price2,price3,price4, buy1,buy2,buy3,buy4, oldprice1,oldprice2,oldprice3,oldprice4, CatgDisplayNum
        output = getDataHeaderNames().map { x in
            self.translateKeyName(x) //, forExport: true)
        }
        return output
    }
    
    func makeDataFromObject() -> [String : String] {
        var output: [String : String] = [:]
        let headerNames = DealerItem.getDataHeaderNames()
        //println("DealerItem header names are \(headerNames)")
        for headerName in headerNames {
            let keyname = DealerItem.translateKeyName(headerName) //, forExport: true)
            switch headerName {
            case "group", "id", "descriptionX", "status", "pictype", "pictid"
            , "cat1", "cat2"
            , "price1", "price2", "price3", "price4"
            , "buy1", "buy2", "buy3", "buy4"
            , "oldprice1", "oldprice2", "oldprice3", "oldprice4":
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
        //println("New DealerItem data is \(output)")
        return output
    }

}
