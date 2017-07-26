//
//  BTCategory.swift
//  StampCollection
//
//  Created by Michael L Mehr on 4/17/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import Foundation

class BTCategory: NSObject {
    // the following is basic data populated by the getCategories message
    //var raw = ""
    var name = ""
    var href = ""
    var number = -1
    var items = 0
    // the following is data added by the getItems message for the individual category
    var notes = ""
    var headers : [String] = []
    
    private var dataItems : [BTDealerItem] = []
    private var dataIndex : [String:BTDealerItem] = [:]
    var integrityViolationDetected = false
    
    var dataItemCount: Int {
        return dataItems.count
    }
    
    func resetDataItems() {
        dataItems = []
        dataIndex = [:]
    }
    
    func getAllDataItems() -> [BTDealerItem] {
        return dataItems
    }
    
    func addDataItem(_ item: BTDealerItem) {
        // NOTE: must check for uniqueness here and throw if it already exists
        // REASON IT COULD HAPPEN: BT MIGHT MISTAKENLY REUSE AN ID NUMBER OR HAVE SOME OTHER NEED TO REUSE ONE
        // ALSO - look into their use of temporary ID numbers before catalog numbers come out - what category was that again?
        // For now, I'll just refuse to clobber an existing item (prefer old working data to new updates)
//        integrityViolationDetected = false
//        guard dataItems[item.code] == nil else {
//            print("Data integrity violation prevented; refused to append item with ID=\(item.code)")
//            print("Old item:\(dataItems[item.code]!)")
//            print("Attempted new item \(item.code):\(item.descr)")
//            integrityViolationDetected = true
//            // TBD - this should throw
//            return
//        }
        dataItems.append(item)
        dataIndex[item.code] = item
    }
    
    func fetchData(withCode code:String) -> BTDealerItem? {
        return dataIndex[code]
    }
    
    var infoNumber: Int16 {
        return BTCategory.translateNumberToInfoCategory(number)
    }
    
    class func translateNumberToInfoCategory( _ catnum: Int) -> Int16 {
        // takes the category of current BT site and translates it into the internal category number used in the collection data
        switch catnum {
        case 1...3: return Int16(catnum)
        case 4: return 4 // event
        case 5: return 6 // post offices
        case 6: return -1 // no counterpart (new category added since collection was scraped)
        case 7: return 7 // slogan
        case 8: return 5 // military admin == w.bank & gaza
        case JSCategoryAll: return 28 // Judaica Sales Austria Tabs category
        case BTCategoryAll: return Int16(catnum) // just in case (shouldn't occur)
        default: return Int16(catnum) - 1
        }
    }
    
    class func translateNumberFromInfoCategory( _ catnum: Int16) -> Int {
        // takes the category of current BT site and translates it into the internal category number used in the collection data
        switch catnum {
        case 1...3: return Int(catnum)
        case 4: return 4 // event
        case 6: return 5 // post offices
            //case 6: return -1 // no counterpart (new category added since collection was scraped)
        case 7: return 7 // slogan
        case 5: return 8 // military admin == w.bank & gaza
        case 28: return JSCategoryAll // Judaica Sales Austria Tabs category
        case CollectionStore.CategoryAll: return Int(catnum) // just in case (shouldn't occur)
        default: return Int(catnum) + 1
        }
    }
    
    class func copyBasicDataFrom(_ sender: BTCategory, toCategoryObject receiver: BTCategory) {
        //receiver.raw = sender.raw
        receiver.name = sender.name
        receiver.href = sender.href
        receiver.number = sender.number
        receiver.items = sender.items
    }
    
    class func copyBasicDataFrom(_ sender: [BTCategory], toCategoryArray receiver: [BTCategory]) {
        for i in 0 ..< sender.count {
            copyBasicDataFrom(sender[i], toCategoryObject: receiver[i])
        }
    }
    
    class func copyItemDataFrom(_ sender: BTCategory, toCategoryObject receiver: BTCategory) {
        receiver.notes = sender.notes
        receiver.headers = sender.headers
        receiver.dataItems = sender.dataItems
    }
    
    class func getExportNameList() -> [String] {
        return [
            "name",
            "number",
            "href",
            "items",
            "notes",
            "headers"
        ]
    }
    
    func getExportData() -> [String:String] {
        var output:[String:String] = [:]
        output["name"] = self.name
        output["number"] = "\(self.number)"
        output["href"] = self.href
        output["items"] = "\(self.items)"
        output["notes"] = self.notes // poss.needs some escaping?
        output["headers"] = self.headers.joined(separator: ";")
        return output
    }
    
    func importFromData(_ data: [String:String]) {
        let refObj = self
        if let name = data["name"] { refObj.name = name }
        if let numstr = data["number"], let number = Int(numstr) { refObj.number = number }
        if let href = data["href"] { refObj.href = href }
        if let itemstr = data["items"], let items = Int(itemstr) { refObj.items = items }
        if let notes = data["notes"] { refObj.notes = notes } // maybe needs unescaping then
        if let headers = data["headers"] { refObj.headers = headers.components(separatedBy: ";") }
    }
}
