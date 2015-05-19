//
//  CollectionStore.swift
//  StampCollection
//
//  Created by Michael L Mehr on 4/24/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import UIKit
import CoreData

class CollectionStore: ExportDataSource {
    static let moduleName = "StampCollection" // TBD: get this from proper place
    static let CategoryAll : Int16 = -1
    
    static var sharedInstance = CollectionStore()
    
    enum DataType: Printable  {
        case Categories
        case Info
        case Inventory
        
        var description : String {
            switch self {
            case .Categories: return "Categories"
            case .Info: return "Info"
            case .Inventory: return "Inventory"
            }
        }
    }

    // the following arrays store items as currently fetched (with filters, sorting)
    var categories : [Category] = []
    var info : [DealerItem] = []
    var inventory : [InventoryItem] = []
    //var loading = false // means well, but ... not thread safe??
    var albums : [AlbumRef] = []
    var albumFamilies : [AlbumFamily] = []
    var albumTypes : [AlbumType] = []

    // MARK: basics for CoreData implementation
    var persistentStoreCoordinator: NSPersistentStoreCoordinator?
    
    typealias ContextToken = Int
    private static var nextContextToken = 0
    static let badContextToken = -1
    static let mainContextToken = 0
    private static let threadContextToken1 = 1
    private func isThreadContextToken( token: ContextToken ) -> Bool {
        return token >= CollectionStore.threadContextToken1
    }
    private func isBadContextToken( token: ContextToken ) -> Bool {
        return token == CollectionStore.badContextToken
    }
    private func isMainContextToken( token: ContextToken ) -> Bool {
        return token == CollectionStore.mainContextToken
    }
    
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
        // this should properly be called only by the thread using the returned context
        if isBadContextToken(token) {
            return nil
        } else if isMainContextToken(token) {
            return CollectionStore.getMainContext() // it can also get the main context for you with the proper token
        }
        return mocsForThreads[token]
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
        
        // For now, just wipe the managed object caches
        // Then use the CoreData context to wipe the database as well
        if let context = getContextForThread(CollectionStore.mainContextToken) {
            // Then remove all INVENTORY objects
            inventory = fetch("InventoryItem", inContext: context)
            println("Deleting \(inventory.count) inventory items")
            for obj in inventory {
                context.deleteObject(obj)
            }
            inventory = []
            //saveMainContext() // commit those changes
            // Then remove all INFO objects
            info = fetch("DealerItem", inContext: context)
            println("Deleting \(info.count) info items")
            for obj in info {
                context.deleteObject(obj)
            }
            info = []
            //saveMainContext() // commit those changes
            // Then remove all CATEGORY objects
            categories = fetch("Category", inContext: context)
            println("Deleting \(categories.count) category items")
            for obj in categories {
                context.deleteObject(obj)
            }
            categories = []
            // disassemble the derived Album Location hierarchy, from bottom to top
            let pages = fetch("AlbumPage", inContext: context)
            println("Deleting \(pages.count) album pages")
            for obj in pages {
                context.deleteObject(obj)
            }
            let sections = fetch("AlbumSection", inContext: context)
            println("Deleting \(sections.count) album sections")
            for obj in sections {
                context.deleteObject(obj)
            }
            let albums = fetch("AlbumRef", inContext: context)
            println("Deleting \(albums.count) album refs")
            for obj in albums {
                context.deleteObject(obj)
            }
            let families = fetch("AlbumFamily", inContext: context)
            println("Deleting \(families.count) album families")
            for obj in families {
                context.deleteObject(obj)
            }
            let types = fetch("AlbumType", inContext: context)
            println("Deleting \(types.count) album types")
            for obj in types {
                context.deleteObject(obj)
            }
            saveMainContext() // commit those changes
        }
    }

    // MARK: import/export functions
    // NOTE: these functions are used by the ImportExport class to perform their jobs
    // They use a Dictionary [String:String] simple data exchange format
    
    // to implement exporting data, we subscribe to the ExportDataSource protocol
    func prepareStorageContext(forExport exporting: Bool = false) -> ContextToken {
        return getContextTokenForThread()
    }
    
    func addObjectType(type: DataType, withData data: [String:String], toContext token: ContextToken) {
        // use the background thread's moc here
        let mocForThread = getContextForThread(token)
        switch type {
        case .Categories:
            Category.makeObjectFromData(data, inContext: mocForThread)
            //let valstr = ", ".join(data.values)
            //println("Made Category from \(valstr)")
            break
        case .Info:
            // get appropriate Category object (all loaded prior) from this thread's moc
            if let catnum = data["CatgDisplayNum"]?.toInt(),
                obj = fetchCategory(Int16(catnum), inContext: token)
            {
                    // pass the related object(s) in a Dictionary to make the new item in the moc
                    let relations = ["category": obj]
                    DealerItem.makeObjectFromData(data, withRelationships: relations, inContext: mocForThread)
                    //let valstr = ", ".join(data.values)
                    //println("Made DealerItem from \(valstr)")
            }
            break
        case .Inventory:
            if let code = data["BaseItem"], code2 = data["RefItem"], mocForThread = mocForThread {
                // need to pass the related dealer item object to construct its relationship on the fly
                let rule = NSPredicate(format: "%K == %@", "id", code)
                let rule2 : NSPredicate? = code2 == "" ? nil : NSPredicate(format: "%K == %@", "id", code2)
                if let catnum = data["CatgDisplayNum"]?.toInt(),
                    catobj = fetchCategory(Int16(catnum), inContext: token),
                    obj = fetch("DealerItem", inContext: mocForThread, withFilter: rule).first
                    , pobj = AlbumPage.getObjectInImportData(data, fromContext: mocForThread)
                {
                    // pass the related object(s) in a Dictionary to make the new item in the moc
                    var relations = ["dealerItem": obj, "category": catobj, "page": pobj]
                    // deal with the optional RefItem relationship here
                    if let rule2 = rule2,
                        robj = fetch("DealerItem", inContext: mocForThread, withFilter: rule2).first
                    {
                        relations.updateValue(robj, forKey: "referredItem")
                    }
                    InventoryItem.makeObjectFromData(data, withRelationships: relations, inContext: mocForThread)
                    //let valstr = ", ".join(data.values)
                    //println("Made InventoryItem from \(valstr)")
                }
            }
            break
        }
    }
    
    func finalizeStorageContext(token: ContextToken, forExport: Bool = false) {
        if !forExport {
            saveContextForThread(token)
        }
        removeContextForThread(token) // NOTE: do NOT use token after this point
    }

    // cached export contents are saved here
    private var dataArray : [NSManagedObject]  = []
    
    func numberOfItemsOfDataType( dataType: CollectionStore.DataType,
        withContext token: CollectionStore.ContextToken ) -> Int {
            var output = 0
            if let context = getContextForThread(token) {
                let sorts = prepareExportSortingForDataType(dataType)
                let entityName : String
                switch dataType {
                case .Categories:
                    entityName = "Category"
                    break
                case .Info:
                    entityName = "DealerItem"
                    break
                case .Inventory:
                    entityName = "InventoryItem"
                    break
                }
                // NOTE: this archives the fetch request results, but the batch size should limit the memory footprint
                dataArray = fetch(entityName, inContext: context, withFilter: nil, andSorting: sorts)
                output = dataArray.count
            }
            return output
    }
    
    func headersForItemsOfDataType( dataType: CollectionStore.DataType,
        withContext token: CollectionStore.ContextToken )  -> [String] {
            var output : [String] = []
            switch dataType {
            case .Categories:
                output = Category.getExportHeaderNames()
                break
            case .Info:
                output = DealerItem.getExportHeaderNames()
                break
            case .Inventory:
                output = InventoryItem.getExportHeaderNames()
                break
            }
            return output
    }

    private func prepareExportSortingForDataType( dataType: CollectionStore.DataType ) -> [NSSortDescriptor] {
        let outputSort : NSSortDescriptor
        // This should create data that can create a fetchRequest that gets the objects in the proper order
        switch dataType {
        case .Categories:
            outputSort = NSSortDescriptor(key: "exOrder", ascending: true)
            break
        case .Info:
            outputSort = NSSortDescriptor(key: "exOrder", ascending: true)
            break
        case .Inventory:
            outputSort = NSSortDescriptor(key: "exOrder", ascending: true)
            break
        }
        return [outputSort]
    }
    
    func dataType(dataType: CollectionStore.DataType, dataItemAtIndex index: Int,
        withContext token: CollectionStore.ContextToken ) -> [String:String] {
            var output : [String:String] = [:]
            if (0..<dataArray.count).contains(index) {
                var item = dataArray[index]
                switch dataType {
                case .Categories:
                    if let obj = item as? Category {
                        output = obj.makeDataFromObject()
                    }
                    break
                case .Info:
                    if let obj = item as? DealerItem {
                        output = obj.makeDataFromObject()
                    }
                    break
                case .Inventory:
                    if let obj = item as? InventoryItem {
                        output = obj.makeDataFromObject()
                    }
                    break
                }
            }
            return output
    }

    // MARK: main functionality
    func exportAllData(completion: (() -> Void)? = nil) {
        var exporter = ImportExport()
        exporter.dataSource = self
        exporter.exportData(compare: false, completion: completion)
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
                showLocationStats(moc, inCategory: category)
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

    private func getUniqueSectionNames(moc: NSManagedObjectContext) {
        var nameCountDict : [String:Int] = [:]
        var total = 0
        let albumSections = fetch("AlbumSection", inContext: moc, withFilter: nil)
        for section in albumSections as! [AlbumSection] {
            if nameCountDict[section.code] == nil {
                nameCountDict[section.code]  = 0
            }
            ++(nameCountDict[section.code]!)
            ++total
        }
        var unamelist = Array(nameCountDict.keys)
        unamelist.sort{ $0 < $1 }
        let unames = ", ".join(unamelist)
        println("There are \(nameCountDict.count-1) unique section names out of \(total) in use: \(unames)")
        //println("Dict of section keys: \(nameCountDict)")
    }
    
    private func showLocationStats(moc: NSManagedObjectContext, inCategory catnum: Int16) {
        let predTypes = NSPredicate(format: "%K == %@", "", "")
        let albumTypes : [AlbumType] = fetch("AlbumType", inContext: moc, withFilter: nil)
        let numAlbumTypes = albumTypes.count
        let albumTypeNames = albumTypes.map{ x in x.code }
        let typeList = ", ".join(albumTypeNames)
        let albumFamilies : [AlbumFamily] = fetch("AlbumFamily", inContext: moc, withFilter: nil)
        let numAlbumFamilies = albumFamilies.count
        let albumFamilyNames = albumFamilies.map{ x in x.code }
        let familyList = ", ".join(albumFamilyNames)
        let numAlbums = countFetches("AlbumRef", inContext: moc, withFilter: nil)
        let numAlbumSections = countFetches("AlbumSection", inContext: moc, withFilter: nil)
        let numAlbumPages = countFetches("AlbumPage", inContext: moc, withFilter: nil)
        let numItems = countFetches("InventoryItem", inContext: moc, withFilter: nil)
        println("There are \(numAlbums) albums in \(numAlbumFamilies) families of \(numAlbumTypes) types with \(numAlbumSections) sections holding \(numAlbumPages) pages for \(numItems) items")
        println("Types: \(typeList)")
        println("Families: \(familyList)")
        getUniqueSectionNames(moc)
    }
    
    func fetchCategory(category: Int16, inContext token: ContextToken = CollectionStore.mainContextToken ) -> Category? {
        // filter: returns category item with given category number; if -1 or unused cat# is passed, returns nil
        // i.e., this looks in the prefiltered categories list (no codes starting with '*')
//        var items : [Category] = categories.filter { x in
//            x.number == category
//        }
//        if items.count > 0 {
//            return items[0]
//        }
        // filter: go for the objects that have the right number, and ignore the weird Booklets (var) category
        if let context = getContextForThread(token) where category != CollectionStore.CategoryAll {
            let rule = NSPredicate(format: "%K == %@ AND NOT %K ENDSWITH %@", "number", NSNumber(short: category), "name", "(var)")
            let cat = fetch("Category", inContext: context, withFilter: rule) as [Category]
            if  cat.count ==  1 {
                return cat[0]
            }
        }
        return nil
    }

    // get counts directly from MOC
    func getCountForType( type: DataType, fromCategory category: Int16 = CollectionStore.CategoryAll, inContext token: ContextToken = CollectionStore.mainContextToken ) -> Int {
        var total = 0
        if let context = getContextForThread(token) {
            var rule: NSPredicate? = nil
            if category != CollectionStore.CategoryAll {
                rule = NSPredicate(format: "%K = %@", "catgDisplayNum", NSNumber(short: category))
            }
            let typeStr : String
            switch type {
            case .Categories: typeStr = "Category"
            case .Info: typeStr = "DealerItem"
            case .Inventory: typeStr = "InventoryItem"
            }
            total = countFetches(typeStr, inContext: context, withFilter: rule)
        }
        return total
    }
    
    private func fetchInfo(context: NSManagedObjectContext, inCategory category: Int16 = CollectionStore.CategoryAll, withSearching searching: [SearchType] = [], andSorting sortType: SortType = .None) {
        // filter: only for given category (catgDisplayNum) unless -1 is passed
        //        var rule: NSPredicate? = nil
        //        if category != CollectionStore.CategoryAll {
        //            rule = NSPredicate(format: "%K = %@", "catgDisplayNum", NSNumber(short: category))
        //        }
        let firstST = category == CollectionStore.CategoryAll ? SearchType.None : SearchType.Category(category)
        let allSTs = [firstST] + searching
        let rule = getPredicateOfType(.Info, forSearchTypes: allSTs)
        // sort in original archived order
        let sorts = prepareExportSortingForDataType(.Inventory)
        // TBD: replace sorting using its ViewModel types as well
        let temp : [DealerItem] = fetch("DealerItem", inContext: context, withFilter: rule, andSorting: sorts)
        // run phase 2 filtering, if needed
        let temp2 = filterInfo(temp, searching)
        // already sorted by default exOrder, so no need for further if specified
        info = sortCollection(temp2, byType: sortType)
    }
    
    private func fetchInventory(context: NSManagedObjectContext, inCategory category: Int16 = CollectionStore.CategoryAll, withSearching searching: [SearchType] = [], andSorting sortType: SortType = .None) {
        // filter: only for given category (catgDisplayNum) unless -1 is passed
//        var rule: NSPredicate? = nil
//        if category != CollectionStore.CategoryAll {
//            rule = NSPredicate(format: "%K = %@", "catgDisplayNum", NSNumber(short: category))
//        }
        let firstST = category == CollectionStore.CategoryAll ? SearchType.None : SearchType.Category(category)
        let allSTs = [firstST] + searching
        let rule = getPredicateOfType(.Inventory, forSearchTypes: allSTs)
        // sort in original archived order
        let sorts = prepareExportSortingForDataType(.Inventory)
        // TBD: replace sorting using its ViewModel types as well
        let temp : [InventoryItem] = fetch("InventoryItem", inContext: context, withFilter: rule, andSorting: sorts)
        // run phase 2 filtering, if needed
        inventory = filterInventory(temp, searching)
    }
    
    private func fetchCategories(context: NSManagedObjectContext) {
        // filter: remove any objects with code starting with a "*"
        let rule = NSPredicate(format: "NOT %K ENDSWITH %@", "name", "(var)")
        // sort: by category.number
        let sort = NSSortDescriptor(key: "number", ascending: true)
        categories = fetch("Category", inContext: context, withFilter: rule, andSorting: [sort])
    }

}

// global utility funcs for access of CoreData object collections
func fetch<T: NSManagedObject>( entity: String, inContext moc: NSManagedObjectContext, withFilter filter: NSPredicate? = nil, andSorting sorters: [NSSortDescriptor] = [] ) -> [T] {
    var output : [T] = []
    var fetchRequest = NSFetchRequest(entityName: entity)
    fetchRequest.sortDescriptors = sorters
    fetchRequest.predicate = filter
    fetchRequest.fetchBatchSize = 50 // supposedly double the typical number to be displayed is best here
    var error : NSError?
    if let fetchResults = moc.executeFetchRequest(fetchRequest, error: &error) {
        output = fromNSArray(fetchResults)
    } else if let error = error {
        println("Fetch error:\(error.localizedDescription)")
    }
    return output
}

func countFetches( entity: String, inContext moc: NSManagedObjectContext, withFilter filter: NSPredicate? = nil ) -> Int {
    var fetchRequest = NSFetchRequest(entityName: entity)
    fetchRequest.predicate = filter
    var error : NSError?
    let fetchResults = moc.countForFetchRequest(fetchRequest, error: &error)
    if let error = error {
        println("Count error:\(error.localizedDescription)")
    }
    return fetchResults
}

