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
    static let CategoryAll : Int16 = -1
    
    static var sharedInstance = CollectionStore()
    
    enum DataType {
        case Categories
        case Info
        case Inventory
    }

    // the following arrays store items as currently fetched (with filters, sorting)
    var categories : [Category] = []
    var info : [DealerItem] = []
    var inventory : [InventoryItem] = []
    //var loading = false // means well, but ... not thread safe??
    
    // the following arrays store all imported items (source of objects for non-CoreData version)
    private var allCategories : [Category] = []
    private var allInfo : [DealerItem] = []
    private var allInventory : [InventoryItem] = []
    private var categoryItemCounters : [Int16: Int] = [:]
    private var masterCount = 0
    
    func removeAllItemsInStore() {
        // NOTE: BE VERY CAREFUL IN USING THIS FUNCTION
        /*
        What we probably want to do with CoreData on Import is:
        A) Check if each item already exists (via ID check)
        B) If so, update any changed fields instead of creating duplicates (DOES THIS WORK FOR INV?)
        C) If not, okay to add the new item
        D) BE CAREFUL WITH ID CHANGES (possible!) AND BT RENUMBERING CATEGORIES!!
        */
        
        // For now, just wipe the entire reference array set
        allInventory = [] // Layer 2
        allInfo = [] // Layer 1
        allCategories = [] // Layer 0
        clearInfoCounters()
        // and wipe the caches
        inventory = []
        info = []
        categories = []
    }
    
    private func clearInfoCounters() {
        masterCount = 0
        categoryItemCounters = [:]
    }
    
    private func incrementInfoCounter( catnum: Int16 ) {
        if categoryItemCounters[catnum] == nil {
            categoryItemCounters[catnum] = 0
        }
        ++(categoryItemCounters[catnum]!)
        ++masterCount
    }
    
    func getInfoCategoryCount( catnum: Int16 ) -> Int {
        if catnum == CollectionStore.CategoryAll {
            return masterCount
        } else if let cntr = categoryItemCounters[catnum] {
            return cntr
        } else {
            return 0
        }
    }
    
    func addObject(data: AnyObject) {
        if let data = data as? Category {
            allCategories.append(data)
            clearInfoCounters() // NOTE: requires all categories to be loaded before any info items
        }
        else if let data = data as? DealerItem {
            allInfo.append(data)
            let cat = data.catgDisplayNum
            incrementInfoCounter(cat)
        }
        else if let data = data as? InventoryItem {
            allInventory.append(data)
        }
    }
    
    func fetchType(type: DataType, category: Int16 = CategoryAll, searching: [SearchType] = [], completion: (() -> Void)? = nil) {
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
                self.fetchInfoinCategory(category, searching: searching)
                break
            case .Inventory:
                self.fetchInventoryinCategory(category, searching: searching)
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

    func fetchCategory(category: Int16 ) -> Category? {
        // filter: returns category item with given category number; if -1 or unused cat# is passed, returns nil
        // i.e., this looks in the prefiltered categories list (no codes starting with '*')
        var items : [Category] = categories.filter { x in
            x.number == category
        }
        if items.count > 0 {
            return items[0]
        }
        return nil
    }
    
    func fetchInfoItem(code: String ) -> DealerItem? {
        // filter: returns info item with given unique code string; if item not found, returns nil
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
        // filter: removed the Booklets (var) category (anomaly of web processing)
        // sort: by category.number
        let temp = allCategories.filter {
                !$0.name.endsWith("(var)")
            }.sorted {
                $0.number < $1.number
        }
//        let temp2 = sortKVOArray(allCategories, ["number"])
        categories = temp
    }
    
    private func fetchInfoinCategory(_ category: Int16 = CollectionStore.CategoryAll, searching: [SearchType] = []) {
        // filter: only for given category (catgDisplayNum) unless -1 is passed
        let temp = category == CollectionStore.CategoryAll ? allInfo : allInfo.filter { x in
            x.catgDisplayNum == Int16(category)
        } // unsorted for now, much work to do on that
 //       let temp = category == CollectionStore.CategoryAll ? allInfo : filterInfo(allInfo, [SearchType.Category(category)])
        let temp2 = filterInfo(temp, searching) // more complex filtering
        let output = temp2 // do sorting here, after filtering
        info = output
    }
    
    private func fetchInventoryinCategory(_ category: Int16 = CollectionStore.CategoryAll, searching: [SearchType] = []) {
//        // filter: only for given category (catgDisplayNum) unless -1 is passed
        let temp = category == CollectionStore.CategoryAll ? allInventory : allInventory.filter { x in
            x.catgDisplayNum == Int16(category)
        } // unsorted for now, much work to do on that
//        let temp = category == CollectionStore.CategoryAll ? allInventory : filterInventory(allInventory, [SearchType.Category(category)])
        let temp2 = filterInventory(temp, searching) // more complex filtering
        let output = temp2 // do sorting here, after filtering
        inventory = output
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
