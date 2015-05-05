//
//  CollectionStore.swift
//  StampCollection
//
//  Created by Michael L Mehr on 4/24/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import UIKit
import CoreData

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

    // MARK: basics for CoreData implementation
    var persistentStoreCoordinator: NSPersistentStoreCoordinator?
    
    typealias ContextToken = Int
    private static var nextContextToken = 0
    static let badContextToken = 0
    
    private var mocsForThreads : [ContextToken : NSManagedObjectContext] = [:]
    
    init() {
        // get the PSC from the application delegate
        if let ad = UIApplication.sharedApplication().delegate as? AppDelegate,
            psc = ad.persistentStoreCoordinator {
                persistentStoreCoordinator = psc
                // populate the arrays with any managed objects found
                //fetchType(.Categories, background: true)
        }
    }
    
    private static func getMainContext() -> NSManagedObjectContext? {
        if let ad = UIApplication.sharedApplication().delegate as? AppDelegate,
            context = ad.managedObjectContext {
                return context
        }
        return nil
    }
    
    func getContextTokenForThread() -> ContextToken {
        if let ad = UIApplication.sharedApplication().delegate as? AppDelegate,
            psc = persistentStoreCoordinator {
                let context = NSManagedObjectContext()
                context.persistentStoreCoordinator = psc
                let token = ++CollectionStore.nextContextToken
                mocsForThreads[token] = context
                return token
        }
        return CollectionStore.badContextToken // only if CoreData is broken
    }
    
    func getContextForThread(token: ContextToken) -> NSManagedObjectContext? {
        // this should be called on the thread using the context
        return token == CollectionStore.badContextToken ? nil : mocsForThreads[token]
    }
    
    func removeContextForThread(token: ContextToken) {
        if token != CollectionStore.badContextToken {
            mocsForThreads[token] = nil
        }
    }
    
    private static func saveContext(context: NSManagedObjectContext) {
        var error : NSError?
        if !context.save(&error) {
            println("Error saving CoreData context \(error!)")
        } else {
            println("Successful CoreData save")
        }
    }
    
    func saveMainContext() {
        if let context = CollectionStore.getMainContext() {
            CollectionStore.saveContext(context)
        }
    }
    
    func saveContextForThread(token: ContextToken) {
        if token != CollectionStore.badContextToken, let context = mocsForThreads[token] {
            CollectionStore.saveContext(context)
        }
    }
    
    func removeAllItemsInStore() {
        // NOTE: BE VERY CAREFUL IN USING THIS FUNCTION
        /*
        What we probably want to do with CoreData on Import is:
        A) Check if each item already exists (via ID check)
        B) If so, update any changed fields instead of creating duplicates (DOES THIS WORK FOR INV?)
        C) If not, okay to add the new item
        D) BE CAREFUL WITH ID CHANGES (possible!) AND BT RENUMBERING CATEGORIES!!
        */
        
//        // For now, just wipe the entire reference array set
//        allInventory = [] // Layer 2
//        allInfo = [] // Layer 1
//        allCategories = [] // Layer 0
//        clearInfoCounters()
//        // and wipe the caches
//        inventory = []
//        info = []
//        categories = []
    }
    
    func prepareStorageContext() -> ContextToken {
        return getContextTokenForThread()
    }
    
    func addObjectType(type: DataType, withData data: [String:String], toContext token: ContextToken) {
        // use the background thread's moc here
        let mocForThread = getContextForThread(token)
        switch type {
        case .Categories:
            Category.makeObjectFromData(data, inContext: mocForThread)
            break
        case .Info:
            DealerItem.makeObjectFromData(data, inContext: mocForThread)
            break
        case .Inventory:
            InventoryItem.makeObjectFromData(data, inContext: mocForThread)
            break
        }
    }
    
    func getObjectData(type: DataType, fromContext token: ContextToken) -> [[String:String]] {
        // TBD: get the entire array of objects of this type from CoreData for export, converting them to [:] form first
        return [[:]]
    }
    
    func finalizeStorageContext(token: ContextToken) {
        saveContextForThread(token)
        removeContextForThread(token) // NOTE: do NOT use token after this point
    }
    
    func fetchType(type: DataType, category: Int16 = CategoryAll, searching: [SearchType] = [], completion: (() -> Void)? = nil) {
        // run this on a background thread (does lots of work! approx 10-20K records)
        // do this on a background thread if background flag is set
//        let queue = background ? NSOperationQueue() : NSOperationQueue.mainQueue()
//        queue.addOperationWithBlock({
            //self.loading = true
        if let moc = CollectionStore.getMainContext() {
            switch type {
            case .Categories:
                self.fetchCategories(moc)
                break
            case .Info:
                self.fetchInfo(moc, inCategory: category, withSearching: searching)
                break
            case .Inventory:
                self.fetchInventory(moc, inCategory: category, withSearching: searching)
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
    }

    func fetchCategory(category: Int16 ) -> Category? {
        // filter: returns category item with given category number; if -1 or unused cat# is passed, returns nil
        // i.e., this looks in the prefiltered categories list (no codes starting with '*')
//        var items : [Category] = categories.filter { x in
//            x.number == category
//        }
//        if items.count > 0 {
//            return items[0]
//        }
        // filter: go for the objects that have the right number, and ignore the weird Booklets (var) category
        if let context = CollectionStore.getMainContext() where category != CollectionStore.CategoryAll {
            let rule = NSPredicate(format: "%K == %@ AND NOT %K ENDSWITH %@", "number", NSNumber(short: category), "name", "(var)")
            let cat = fetch("Category", inContext: context, withFilter: rule) as [Category]
            if  cat.count ==  1 {
                return cat[0]
            }
        }
        return nil
    }
    
    func getInfoCategoryCount( category: Int16 ) -> Int {
        var total = 0
//        if let context = CollectionStore.getMainContext() {
//            var rule: NSPredicate? = nil
//            if category != CollectionStore.CategoryAll {
//                rule = NSPredicate(format: "%K = %@", "catgDisplayNum", NSNumber(short: category))
//            }
//            // TBD: add way to convert [SearchType] into predicate on top of this predicate
//            // TBD: add sorting using its ViewModel types as well
//            total = count("DealerItem", inContext: context, withFilter: rule)
//        }
        return total
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
    
//    private func fetchCategories(moc: NSManagedObjectContext) {
//        // filter: removed the Booklets (var) category as not useful in current implementation
//        // sort: by category.number
//        let temp = allCategories.filter {
//                !$0.name.endsWith("(var)")
//            }.sorted {
//                $0.number < $1.number
//        }
////        let temp2 = sortKVOArray(allCategories, ["number"])
//        categories = temp
//    }
//    
//    private func fetchInfoinCategory(_ category: Int16 = CollectionStore.CategoryAll, searching: [SearchType] = []) {
//        // filter: only for given category (catgDisplayNum) unless -1 is passed
//        let temp = category == CollectionStore.CategoryAll ? allInfo : allInfo.filter { x in
//            x.catgDisplayNum == Int16(category)
//        } // unsorted for now, much work to do on that
// //       let temp = category == CollectionStore.CategoryAll ? allInfo : filterInfo(allInfo, [SearchType.Category(category)])
//        let temp2 = filterInfo(temp, searching) // more complex filtering
//        let output = temp2 // do sorting here, after filtering
//        info = output
//    }
//    
//    private func fetchInventoryinCategory(_ category: Int16 = CollectionStore.CategoryAll, searching: [SearchType] = []) {
////        // filter: only for given category (catgDisplayNum) unless -1 is passed
//        let temp = category == CollectionStore.CategoryAll ? allInventory : allInventory.filter { x in
//            x.catgDisplayNum == Int16(category)
//        } // unsorted for now, much work to do on that
////        let temp = category == CollectionStore.CategoryAll ? allInventory : filterInventory(allInventory, [SearchType.Category(category)])
//        let temp2 = filterInventory(temp, searching) // more complex filtering
//        let output = temp2 // do sorting here, after filtering
//        inventory = output
//    }
    
    private func fetchInfo(context: NSManagedObjectContext, inCategory category: Int16 = CollectionStore.CategoryAll, withSearching searching: [SearchType] = []) {
        // filter: only for given category (catgDisplayNum) unless -1 is passed
        var rule: NSPredicate? = nil
        if category != CollectionStore.CategoryAll {
            rule = NSPredicate(format: "%K = %@", "catgDisplayNum", NSNumber(short: category))
        }
        // TBD: add way to convert [SearchType] into predicate on top of this predicate
        // TBD: add sorting using its ViewModel types as well
        info = fetch("DealerItem", inContext: context, withFilter: rule)
    }
    
    private func fetchInventory(context: NSManagedObjectContext, inCategory category: Int16 = CollectionStore.CategoryAll, withSearching searching: [SearchType] = []) {
        // filter: only for given category (catgDisplayNum) unless -1 is passed
        var rule: NSPredicate? = nil
        if category != CollectionStore.CategoryAll {
            rule = NSPredicate(format: "%K = %@", "catgDisplayNum", NSNumber(short: category))
        }
        // TBD: add way to convert [SearchType] into predicate on top of this predicate
        // TBD: add sorting using its ViewModel types as well
        inventory = fetch("InventoryItem", inContext: context, withFilter: rule)
    }
    
    private func fetchCategories(context: NSManagedObjectContext) {
        // filter: remove any objects with code starting with a "*"
        let rule = NSPredicate(format: "NOT %K ENDSWITH %@", "name", "(var)")
        // sort: by category.number
        let sort = NSSortDescriptor(key: "number", ascending: true)
        categories = fetch("Category", inContext: context, withFilter: rule, andSorting: [sort])
    }
    
    private func fetch<T: NSManagedObject>( entity: String, inContext moc: NSManagedObjectContext, withFilter filter: NSPredicate? = nil, andSorting sorters: [NSSortDescriptor] = [] ) -> [T] {
        var output : [T] = []
        let name = /*CollectionStore.moduleName + "." +*/ entity
        var fetchRequest = NSFetchRequest(entityName: name)
        fetchRequest.sortDescriptors = sorters
        fetchRequest.predicate = filter
        var error : NSError?
        if let fetchResults = moc.executeFetchRequest(fetchRequest, error: &error) {
            output = fromNSArray(fetchResults)
        } else if let error = error {
            println("Fetch error:\(error.localizedDescription)")
        }
        return output
    }
//    
//    private func count<T: NSManagedObject>( entity: String, inContext moc: NSManagedObjectContext, withFilter filter: NSPredicate? = nil, andSorting sorters: [NSSortDescriptor] = [] ) -> Int {
//        let name = /*CollectionStore.moduleName + "." +*/ entity
//        var fetchRequest = NSFetchRequest(entityName: name)
//        fetchRequest.sortDescriptors = sorters
//        fetchRequest.predicate = filter
//        var error : NSError?
//        let fetchResults = moc.countForFetchRequest(fetchRequest, error: &error)
//        if let error = error {
//            println("Count error:\(error.localizedDescription)")
//        }
//        return fetchResults
//    }

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
