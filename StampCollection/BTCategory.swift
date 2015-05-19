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
    var raw = ""
    var name = ""
    var href = ""
    var number = -1
    var items = 0
    // the following is data added by the getItems message for the individual category
    var notes = ""
    var headers : [String] = []
    var dataItems : [BTDealerItem] = []

    class func translateNumberToInfoCategory( catnum: Int) -> Int16 {
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
    
    class func translateNumberFromInfoCategory( catnum: Int16) -> Int {
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
    
    class func copyBasicDataFrom(sender: BTCategory, toCategoryObject receiver: BTCategory) {
        receiver.raw = sender.raw
        receiver.name = sender.name
        receiver.href = sender.href
        receiver.number = sender.number
        receiver.items = sender.items
    }
    
    class func copyBasicDataFrom(sender: [BTCategory], toCategoryArray receiver: [BTCategory]) {
        for var i=0; i<sender.count; ++i {
            copyBasicDataFrom(sender[i], toCategoryObject: receiver[i])
        }
    }
    
    class func copyItemDataFrom(sender: BTCategory, toCategoryObject receiver: BTCategory) {
        receiver.notes = sender.notes
        receiver.headers = sender.headers
        receiver.dataItems = sender.dataItems
    }
}
