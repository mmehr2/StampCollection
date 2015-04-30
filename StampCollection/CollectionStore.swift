//
//  CollectionStore.swift
//  StampCollection
//
//  Created by Michael L Mehr on 4/24/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import UIKit

class CollectionStore {
    static let moduleName = "StampCollection" // TBD: get this from proper place
    static let CategoryAll = -1
    
    static var sharedInstance = CollectionStore()
    
    // the following arrays store items as currently fetched (with filters, sorting)
    var categories : [Category] = []
    var info : [DealerItem] = []
    var inventory : [InventoryItem] = []
    //var loading = false // means well, but ... not thread safe??
    
    // the following arrays store all imported items (source of objects for non-CoreData version)
    private var allCategories : [Category] = []
    private var allInfo : [DealerItem] = []
    private var allInventory : [InventoryItem] = []
    
    enum DataType {
        case Categories
        case Info
        case Inventory
    }

    func addObject(data: AnyObject) {
        if data is Category {
            allCategories.append(data as! Category)
        }
        if data is DealerItem {
            allInfo.append(data as! DealerItem)
        }
        if data is InventoryItem {
            allInventory.append(data as! InventoryItem)
        }
    }
    
    func fetchType(type: DataType, category: Int = CategoryAll, background: Bool = true, completion: (() -> Void)? = nil) {
        // run this on a background thread (does lots of work! approx 10-20K records)
        // do this on a background thread if background flag is set
//        let queue = background ? NSOperationQueue() : NSOperationQueue.mainQueue()
//        queue.addOperationWithBlock({
            //self.loading = true
            switch type {
            case .Categories:
                self.fetchCategories()
                break
            case .Info:
                self.fetchInfoinCategory(category)
                break
            case .Inventory:
                self.fetchInventoryinCategory(category)
                break
            }
            // run the completion block, if any, on the main queue
            if let completion = completion {
                //NSOperationQueue.mainQueue().addOperationWithBlock(completion)
                completion()
            }
            //self.loading = false
//        })
    }

    func fetchCategory(category: Int ) -> Category? {
        // filter: returns category item with given category number; if -1 or unused cat# is passed, returns nil
        // i.e., this looks in the prefiltered categories list (no codes starting with '*')
        var items : [Category] = categories.filter { x in
            x.number == Int16(category)
        }
        if items.count > 0 {
            return items[0]
        }
        return nil
    }
    
    func fetchInfoItem(code: String ) -> DealerItem? {
        // filter: returns info item with given unique code string; if -1 or unused cat# is passed, returns nil
        // i.e., this looks in the prefiltered info list (usually filtered by category)
        var items : [DealerItem] = info.filter { x in
            x.id == code
        }
        if items.count > 0 {
            return items[0]
        }
        return nil
    }
    
    func fetchInventoryItems(code: String ) -> [InventoryItem] {
        // filter: returns inventory items with given baseItem code string
        // NOTE: due to duplicates, this needs to work differently from the INFO and CATEGORY item fetchers
        // i.e., this looks in the prefiltered info list (usually filtered by category)
        var items : [InventoryItem] = inventory.filter { x in
            x.baseItem == code
        }
        return items
    }
    
    private func fetchCategories() {
        // sort: by category.number
        let temp = allCategories.sorted {
                $0.number < $1.number
        }
        categories = temp
    }
    
    private func fetchInfoinCategory(_ category: Int = -1) {
        // filter: only for given category (catgDisplayNum) unless -1 is passed
        let temp = allInfo.filter { x in
            x.catgDisplayNum == Int16(category)
        } // unsorted for now, much work to do on that
        info = temp
    }
    
    private func fetchInventoryinCategory(_ category: Int = -1) {
        // filter: only for given category (catgDisplayNum) unless -1 is passed
        let temp = allInventory.filter { x in
            x.catgDisplayNum == Int16(category)
        } // unsorted for now, much work to do on that
        inventory = temp
    }

//    private func fetch<T: NSObject>( entity: String, collection: [T], withFilter filter: NSPredicate? = nil, andSorting sorters: [NSSortDescriptor] = [] ) -> [T] {
//        println("fetch with type \(T.self)")
//        var output : [T] = []
//        let resultsNS : NSArray
//        if let filter = filter {
//            // get the proper list of objects from the proper type array
//            resultsNS = (collection as NSArray).filteredArrayUsingPredicate(filter)
//        } else {
//            resultsNS = collection
//        }
//        // NOTE: the following line seems to break XCode 6.3.1 - causes HUGE numbers to be returned and corruption of memory - why??
//        if let results = resultsNS.sortedArrayUsingDescriptors(sorters) as? [T] {
//            let ccount = results.count
//            return results
//        }
//        let ocount = output.count
//        return output
//    }
}
