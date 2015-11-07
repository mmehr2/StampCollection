//
//  CollectionStore.swift
//  StampCollection
//
//  Created by Michael L Mehr on 4/24/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import UIKit
import CoreData

class CollectionStore: NSObject, ExportDataSource, ImportDataSink {
    static let CategoryAll : Int16 = -1
    
    //static var sharedInstance = CollectionStore() // yes this is a global singleton; looking into how to do dependency injection with it
    
    enum DataType: CustomStringConvertible  {
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

    private var initialized_ = false
    var initialized: Bool {
        get {
            return initialized_
        }
    }
    private var initCompletionBlock: (() -> Void)?
    
    init(completion: (() -> Void)? = nil) {
        // RayW init: class derives from NSObject so dependency injection can be done at runtime on all child VC objects
        super.init()
        // save completion block: it is NOT ok to use the persistence layer until this executes
        initCompletionBlock = completion
        // create the main thread's context using token 0 (never remove this)
        // init redesigned using Zarra pattern #1-2 (MLM 10/17/2015) - this will fire all setup, including connection / migration on a background thread
        let token = getNewContextTokenForThread()
        if !isBadContextToken(token) {
            print("Created the main CoreData context objects")
            // populate the arrays with any managed objects found
            // NOTE: this can no longer be done here with the Zarra design; it should be done inside the completion handler instead
            //fetchType(.Categories)
        }
    }

    // MARK: basics for CoreData implementation
    // Redesigned for Swift 2 and using concurrency pattern of Marcus Zarra from http://martiancraft.com/blog/2015/03/core-data-stack/
    // The Zarra design pattern / suggestion involves several steps:
    //   1. The initial setup of the stack is split into a lightweight portion that sets up the PSC, MOMD, and MOC objects, and
    //   2. ... a background task that performs attaching the SQLITE file to the PSC (which could trigger lengthy migrations)
    //   3. For regular usage, a parent MOC is put in a private property, set up to use the PrivateQueue concurrency type and the PSC as data source
    //   4. Then a child MOC is provided as the main "source of truth" for the app, as a child of #3, using the MainQueue concurrency type
    //   5. Finally, for any background queue work, other MOCs can be provided as children of #4
    // This design was also partially followed by the Ray Wenderlich tutorial series Intermediate Core Data (video), but due to differences I chose to ignore its design.
    // I wanted the design of CollectionStore to handle all the heavy lifting of CoreData and not "leak" any CoreData usage into other parts of the model,
    //   except when using the individual managed objects themselves.
    // The Zarra design uses the private parent MOC (#3) to save all data to disk without tying up the main queue.
    // The more public MainQ child context is used for all UI data interactions, and children of that context are provided for background thread work (always non-UI).
    // This means I can adapt my thread-confinement model to set up the private parent MOC separately, set the main controller as a child of this (with MainQ type),
    //    and provide the thread MOCs as children of this one.
    // The basic scheme of using integer tokens instead of actual MOCs should abstract the CoreData usage outside of this file sufficiently.
    // However, I may wish to revisit this design at a later date.
    
    static let moduleName = "StampCollection" // TBD: get this from proper place
    lazy var applicationDocumentsDirectory: NSURL = {
        // The directory the application uses to store the Core Data store file. This code uses a directory named "com.azuresults.StampCollection" in the application's documents Application Support directory.
        let urls = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)
        return urls[urls.count-1] 
        }()
    
    lazy var managedObjectModel: NSManagedObjectModel = {
        // The managed object model for the application. This property is not optional. It is a fatal error for the application not to be able to find and load its model.
        // This resource is the same name as your xcdatamodeld contained in your project.
        guard let modelURL = NSBundle.mainBundle().URLForResource(moduleName, withExtension:"momd") else {
            fatalError("Error loading object model from bundle")
        }
        // The managed object model for the application. It is a fatal error for the application not to be able to find and load its model.
        guard let mom = NSManagedObjectModel(contentsOfURL: modelURL) else {
            fatalError("Error initializing object model from url: \(modelURL)")
        }
        return mom
        }()
    
    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator? = {
        // The persistent store coordinator for the application. This implementation creates and return a coordinator, having added the store for the application to it. This property is optional since there are legitimate error conditions that could cause the creation of the store to fail.
        // Create the coordinator and store
        let psc = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)) {
            let urls = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)
            let docURL = urls[urls.endIndex-1]
            /* The directory the application uses to store the Core Data store file.
            This code uses a file named "*.sqlite" in the application's documents directory.
            */
            let storeURL = self.applicationDocumentsDirectory.URLByAppendingPathComponent(moduleName+".sqlite")
            do {
                try psc.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: storeURL,
                    options: [NSMigratePersistentStoresAutomaticallyOption: true, NSInferMappingModelAutomaticallyOption: true])
                print("CoreData stack established at \(storeURL)")
                // SUCCESS: fire the init completion handler block on the main queue here
                if let handler = self.initCompletionBlock {
                    dispatch_sync(dispatch_get_main_queue(), handler)
                } else {
                    print("Unable to send completion signal block for UI continuation after persistence layer initialization.")
                }
                self.initialized_ = true
            } catch {
                fatalError("Error migrating store: \(error)")
            }
        }
        return psc
        }()
    
    typealias ContextToken = Int
    static let badContextToken: ContextToken = -1
    static let mainContextToken: ContextToken = 0 // see Zarra pattern #4
    private var nextContextToken: ContextToken = mainContextToken
    private func isBadContextToken( token: ContextToken ) -> Bool {
        return token == CollectionStore.badContextToken
    }

    private lazy var saveManagedObjectContext: NSManagedObjectContext? = {
        guard let coordinator = self.persistentStoreCoordinator else { return nil }
        let managedObjectContext = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = coordinator
        // not needed and crashes! // managedObjectContext.parentContext = nil // this is the parent for the main UI MOC (Zarra pattern #3)
        managedObjectContext.undoManager = nil // speed optimization: no UM needed for non-UI contexts
        return managedObjectContext
    }()
    
    private lazy var mainManagedObjectContext: NSManagedObjectContext? = {
        guard let coordinator = self.persistentStoreCoordinator else { return nil }
        let managedObjectContext = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = nil // no PSC; this is the parent for other MOCs (Zarra pattern #4)
        managedObjectContext.parentContext = self.saveManagedObjectContext // this is a child of the save context (Zarra pattern #3) above
        //managedObjectContext.undoManager = nil // speed optimization: no UM needed for non-UI contexts
        return managedObjectContext
        }()
    
    private func getScratchContext() -> NSManagedObjectContext? {
        if persistentStoreCoordinator != nil {
            let context = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
            context.persistentStoreCoordinator = nil
            context.parentContext = mainManagedObjectContext // Zarra pattern #4
            context.undoManager = nil // speed optimization: no UM needed for non-UI contexts
            return context
        }
        return nil
    }
    
    private var mocsForThreads : [ContextToken : NSManagedObjectContext] = [:]
    
    func getNewContextTokenForThread() -> ContextToken {
        if persistentStoreCoordinator != nil {
            let token = nextContextToken++
            let setupMain = (token == CollectionStore.mainContextToken)
            print("Setting up token #\(token) for \(setupMain ? "main " : "private") context")
            if let context = (setupMain ? mainManagedObjectContext : getScratchContext()) {
                mocsForThreads[token] = context
                return token
            }
        }
        return CollectionStore.badContextToken // only if CoreData is broken
    }
    
    func getContextForThread(token: ContextToken) -> NSManagedObjectContext? {
        // this should properly be called only by the thread using the returned context
        if isBadContextToken(token) {
            return nil
        } 
        return mocsForThreads[token]
    }

    // NOTE: every call to getNewContextTokenForThread() should eventually call removeContextForThread() on the returned token (defer this)
    func removeContextForThread(token: ContextToken) {
        if token != CollectionStore.badContextToken && token != CollectionStore.mainContextToken {
            // create the closure that will do the work
            let completion = {
                print("Context #\(token) removal on private queue")
                self.mocsForThreads[token] = nil
            }
            // schedule it as the next task on the context's private queue (async call)
            if let context = self.mocsForThreads[token] {
                context.performBlock(completion)
            }
        }
    }

    // save the main context
    private func saveMainContextOnQueue(userCompletion: (()->Void)?) {
        if let context = mainManagedObjectContext, contextP = saveManagedObjectContext {
            // two-step process:
            // step 1 - save the source of truth running sync on its own queue (main)
            if context.hasChanges {
                context.performBlockAndWait() {
                    do {
                        try context.save()
                        print("Successful CoreData main memory save")
                    } catch {
                        print("Error saving main CoreData memory context \(error)")
                        return
                    }
                }
            }
            // step 1A - run the user completion routine async on main queue
            if let userCompletion = userCompletion {
                context.performBlock(userCompletion)
            }
            // step 2 - save the parent MOC running async on its own queue (pvt)
            if contextP.hasChanges {
                contextP.performBlock() {
                    do {
                        try contextP.save()
                        print("Successful CoreData disk save")
                    } catch {
                        print("Error saving private CoreData disk context \(error)")
                    }
                }
            }
        }
    }
    
    private func saveMainContextOnQueueAsync(userCompletion: (()->Void)?) {
        if let context = mainManagedObjectContext, contextP = saveManagedObjectContext {
            // two-step process:
            // step 1 - save the source of truth running async on its own queue (main)
            if context.hasChanges {
                context.performBlock() {
                    do {
                        try context.save()
                        print("Successful CoreData main memory saveA")
                        // step 2 - now do the async private save (it IS needed), on the private queue
                        contextP.performBlock() {
                            do {
                                try contextP.save()
                                print("Successful CoreData disk saveA")
                            } catch {
                                print("Error savingA private CoreData disk context \(error)")
                            }
                        }
                    } catch {
                        print("Error savingA main CoreData memory context \(error)")
                        return
                    }
                }
                // step 1A - queue the user's block on the main queue in any case
                if let userCompletion = userCompletion {
                    context.performBlock(userCompletion)
                }
            }
                // ALT (no changes in main, but still some left on pvt?) - should never happen?
                // save the parent MOC running async on its own queue (pvt)
            else if contextP.hasChanges {
                // this really shouldn't happen, since contextP only gets changes that are scheduled by changes in context(main)
                contextP.performBlock() {
                    do {
                        try contextP.save()
                        print("Successful CoreData disk saveA2")
                    } catch {
                        print("Error savingA2 private CoreData disk context \(error)")
                    }
                }
                // queue the user's block on the main queue in any case
                if let userCompletion = userCompletion {
                    context.performBlock(userCompletion)
                }
            }
        }
    }
    
    private func saveChildContextOnQueue(context: NSManagedObjectContext) -> Bool {
        // this is actually now a multi-step process, since save only goes up one parent level
        // the function will perform a one-level save to its parent on whatever queue is assigned to it (main or pvt)
        // by using performBlockAndWait() we actually run it synchronously
        var result = false
        let completion = {
            do {
                try context.save()
                print("Successful CoreData save")
                result = true
            } catch {
                print("Error saving CoreData context \(error)")
            }
        }
        if context.hasChanges {
            context.performBlockAndWait(completion)
        }
        return result
    }
    
    private func saveContext(context: NSManagedObjectContext, background: Bool = false, userCompletion: (() -> Void)?) -> Bool {
        if context == saveManagedObjectContext {
            print("PROGRAMMING ERROR! Attempt to save master CoreData context directly.")
            return false // this should not be used this way! assert?? programming error!
        } else if context == mainManagedObjectContext {
            background ? saveMainContextOnQueueAsync(userCompletion) : saveMainContextOnQueue(userCompletion)
        } else {
            let saved = saveChildContextOnQueue(context)
            if saved {
                saveMainContextOnQueueAsync(userCompletion)
            }
        }
        return true
    }
    
    func saveMainContext(userCompletion: (() -> Void)? = nil) -> Bool {
        // this has two steps: save the context to parent, and then fire the async save of the private parent context
        if let context = getContextForThread(CollectionStore.mainContextToken) {
            return saveContext(context, userCompletion: userCompletion)
        }
        return false
    }
    
    func saveContextForThread(token: ContextToken, userCompletion: (() -> Void)? = nil) -> Bool {
        if token == CollectionStore.mainContextToken {
            return saveMainContext(userCompletion)
        }
        else if token != CollectionStore.badContextToken, let context = mocsForThreads[token] {
            return saveContext(context, userCompletion: userCompletion)
        }
        return false
    }

    // MARK: object removal
    func removeAllItemsInStore(completion: (()-> Void)?) {
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
        // Use private queue context for this operation (may take time)
        let token = getNewContextTokenForThread()
        addOperationToContext(token) {
            if let context = self.getContextForThread(token) {
                // Then remove all INVENTORY objects
                self.inventory = fetch("InventoryItem", inContext: context)
                print("Deleting \(self.inventory.count) inventory items")
                for obj in self.inventory {
                    context.deleteObject(obj)
                }
                self.inventory = []
                //saveMainContext() // commit those changes
                // Then remove all INFO objects
                self.info = fetch("DealerItem", inContext: context)
                print("Deleting \(self.info.count) info items")
                for obj in self.info {
                    context.deleteObject(obj)
                }
                self.info = []
                //saveMainContext() // commit those changes
                // Then remove all CATEGORY objects
                self.categories = fetch("Category", inContext: context)
                print("Deleting \(self.categories.count) category items")
                for obj in self.categories {
                    context.deleteObject(obj)
                }
                self.categories = []
                // disassemble the derived Album Location hierarchy, from bottom to top
                let pages = fetch("AlbumPage", inContext: context)
                print("Deleting \(pages.count) album pages")
                for obj in pages {
                    context.deleteObject(obj)
                }
                let sections = fetch("AlbumSection", inContext: context)
                print("Deleting \(sections.count) album sections")
                for obj in sections {
                    context.deleteObject(obj)
                }
                let albums = fetch("AlbumRef", inContext: context)
                print("Deleting \(albums.count) album refs")
                for obj in albums {
                    context.deleteObject(obj)
                }
                let families = fetch("AlbumFamily", inContext: context)
                print("Deleting \(families.count) album families")
                for obj in families {
                    context.deleteObject(obj)
                }
                let types = fetch("AlbumType", inContext: context)
                print("Deleting \(types.count) album types")
                for obj in types {
                    context.deleteObject(obj)
                }
                self.saveContext(context, userCompletion: nil) // save all these deletes to the local child context's parent
                self.removeContextForThread(token) // finally done with the local child context, release it
                //self.saveMainContext() // commit those changes to the parent and its background saver
                
                if let completion = completion {
                    self.addCompletionOperationWithBlock(completion)
                }
            }
        }
    }

    // single-item remove (if commit is set, will call saveContext() afterward to commit change)
    func removeInfoItemByID( itemID: String, commit: Bool = true, fromContext token: ContextToken = mainContextToken ) {
        if let obj = fetchInfoItemByID(itemID, inContext: token) {
            removeInfoItem(obj, commit: commit)
        }
    }
    
    func removeInfoItem( item: DealerItem, commit: Bool = true ) -> Bool {
        if item.referringItems.count > 0 || item.inventoryItems.count > 0 {
            // disallow delete if any relationships exist
            // TBD: should change data model so delete rule takes care of this instead
            return false
        }
        if let context = item.managedObjectContext {
            context.deleteObject(item)
            if commit {
                return saveContext(context, userCompletion: nil)
            }
            return true
        }
        return false
    }
    
    // MARK: ImportExportable protocol: import/export functions
    // NOTE: these functions are used by the ImportExport class to perform their jobs
    // They use a Dictionary [String:String] simple data exchange format
    
    // to implement exporting data, we subscribe to the ExportDataSource protocol
    func prepareStorageContext(forExport exporting: Bool = false) -> ContextToken {
        return getNewContextTokenForThread()
    }
    
    func finalizeStorageContext(token: ContextToken, forExport: Bool = false) {
        if !forExport {
            saveContextForThread(token)
        }
        removeContextForThread(token) // NOTE: do NOT use token after this point
    }
    
    func addOperationToContext(token: ContextToken, withBlock handler: () -> Void) {
        // add an operation to the queue for the provided token's private context
        // does NOT wait for completion (async call)
        if let context = mocsForThreads[token] {
            context.performBlock(handler)
        }
    }
    
    func addCompletionOperationWithBlock( completion: () -> Void) {
        // add an operation to the queue for the main context
        // does NOT wait for completion (async call)
        if let context = mainManagedObjectContext {
            context.performBlock(completion)
        }
    }

    // MARK: protocol ImportDataSink
    // import protocol: persist a new object as requested
    func addObjectType(type: DataType, withData data: [String:String], toContext token: ContextToken = mainContextToken) {
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
            if let catnumstr = data["CatgDisplayNum"], catnum = Int(catnumstr),
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
                if let catnumstr = data["CatgDisplayNum"], catnum = Int(catnumstr),
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

    // MARK: protocol ExportDataSource
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
        var outputSorts : [NSSortDescriptor] = []
        // This should create data that can create a fetchRequest that gets the objects in the proper order
        switch dataType {
        case .Categories:
            outputSorts.append(NSSortDescriptor(key: "exOrder", ascending: true))
            break
        case .Info:
            outputSorts.append(NSSortDescriptor(key: "category.number", ascending: true))
            outputSorts.append(NSSortDescriptor(key: "exOrder", ascending: true))
            break
        case .Inventory:
            outputSorts.append(NSSortDescriptor(key: "exOrder", ascending: true))
            break
        }
        return outputSorts
    }
    
    func dataType(dataType: CollectionStore.DataType, dataItemAtIndex index: Int,
        withContext token: CollectionStore.ContextToken ) -> [String:String] {
            var output : [String:String] = [:]
            if (0..<dataArray.count).contains(index) {
                let item = dataArray[index]
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
        let exporter = ImportExport()
        exporter.exportData(false, fromModel: self, completion: completion)
    }
    
    func fetchType(type: DataType, category: Int16 = CategoryAll, searching: [SearchType] = [], completion: (() -> Void)? = nil) {
        // run this on a background thread (does lots of work! approx 10-20K records)
        // do this on a background thread if background flag is set
//        let queue = background ? NSOperationQueue() : NSOperationQueue.mainQueue()
//        queue.addOperationWithBlock({
            //self.loading = true
        if let moc = getContextForThread(CollectionStore.mainContextToken) {
            switch type {
            case .Categories:
                self.fetchCategories(moc)
                break
            case .Info:
                info = self.fetchInfo(moc, inCategory: category, withSearching: searching)
                break
            case .Inventory:
                inventory = self.fetchInventory(moc, inCategory: category, withSearching: searching)
                //showLocationStats(moc, inCategory: category)
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
        unamelist.sortInPlace{ $0 < $1 }
        let unames = unamelist.joinWithSeparator(", ")
        print("There are \(nameCountDict.count-1) unique section names out of \(total) in use: \(unames)")
        //println("Dict of section keys: \(nameCountDict)")
    }
    
    private func showLocationStats(moc: NSManagedObjectContext, inCategory catnum: Int16) {
        //let predTypes = NSPredicate(format: "%K == %@", "", "")
        let albumTypes : [AlbumType] = fetch("AlbumType", inContext: moc, withFilter: nil)
        let numAlbumTypes = albumTypes.count
        let albumTypeNames = albumTypes.map{ x in x.code as String }
        let typeList = albumTypeNames.joinWithSeparator(", ")
        let albumFamilies : [AlbumFamily] = fetch("AlbumFamily", inContext: moc, withFilter: nil)
        let numAlbumFamilies = albumFamilies.count
        let albumFamilyNames = albumFamilies.map{ x in x.code as String }
        let familyList = albumFamilyNames.joinWithSeparator(", ")
        let numAlbums = countFetches("AlbumRef", inContext: moc, withFilter: nil)
        let numAlbumSections = countFetches("AlbumSection", inContext: moc, withFilter: nil)
        let numAlbumPages = countFetches("AlbumPage", inContext: moc, withFilter: nil)
        let numItems = countFetches("InventoryItem", inContext: moc, withFilter: nil)
        print("There are \(numAlbums) albums in \(numAlbumFamilies) families of \(numAlbumTypes) types with \(numAlbumSections) sections holding \(numAlbumPages) pages for \(numItems) items")
        print("Types: \(typeList)")
        print("Families: \(familyList)")
        getUniqueSectionNames(moc)
    }

    // get a particular category object from CoreData
    func fetchCategory(category: Int16, inContext token: ContextToken = CollectionStore.mainContextToken ) -> Category? {
        if let context = getContextForThread(token) where category != CollectionStore.CategoryAll {
            let cat = fetchCategoriesEx(category, inContext: context)
            if  cat.count ==  1 {
                return cat[0]
            }
        }
        return nil
    }
    
    // get a particular info object from CoreData
    func fetchInfoItemByID(id: String, inContext token: ContextToken = CollectionStore.mainContextToken ) -> DealerItem? {
        if let context = getContextForThread(token) where !id.isEmpty {
            let type = SearchType.SubCategory("^\(id)$")
            let data = fetchInfo(context, inCategory: CollectionStore.CategoryAll, withSearching: [type], andSorting: .None)
            if data.count > 1 {
                print("Non-unique ID found: \(id) has \(data.count) items.")
            }
            return data.first
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
    
    private func fetchInfo(context: NSManagedObjectContext, inCategory category: Int16 = CollectionStore.CategoryAll, withSearching searching: [SearchType] = [], andSorting sortType: SortType = .None) -> [DealerItem] {
        // filter: only for given category (catgDisplayNum) unless -1 is passed
        //        var rule: NSPredicate? = nil
        //        if category != CollectionStore.CategoryAll {
        //            rule = NSPredicate(format: "%K = %@", "catgDisplayNum", NSNumber(short: category))
        //        }
        let firstST = category == CollectionStore.CategoryAll ? SearchType.None : SearchType.Category(category)
        let allSTs = [firstST] + searching
        let rule = getPredicateOfType(.Info, forSearchTypes: allSTs)
        // sort in original archived order
        let sorts = prepareExportSortingForDataType(.Info)
        // TBD: replace sorting using its ViewModel types as well
        let temp : [DealerItem] = fetch("DealerItem", inContext: context, withFilter: rule, andSorting: sorts)
        // run phase 2 filtering, if needed
        let temp2 = filterInfo(temp, types: searching)
        // already sorted by default exOrder, so no need for further if specified
        return sortCollection(temp2, byType: sortType)
    }
    
    func fetchInfoInCategory( category: Int16 = CollectionStore.CategoryAll, withSearching searching: [SearchType] = [], andSorting sortType: SortType = .None, fromContext token: Int = mainContextToken ) -> [DealerItem] {
        if let context = getContextForThread(token) {
            return fetchInfo(context, inCategory: category, withSearching: searching, andSorting: sortType)
        }
        return []
    }
    
    private func fetchInventory(context: NSManagedObjectContext, inCategory category: Int16 = CollectionStore.CategoryAll, withSearching searching: [SearchType] = [], andSorting sortType: SortType = .None) -> [InventoryItem] {
        let firstST = category == CollectionStore.CategoryAll ? SearchType.None : SearchType.Category(category)
        let allSTs = [firstST] + searching
        let rule = getPredicateOfType(.Inventory, forSearchTypes: allSTs)
        // sort in original archived order
        let sorts = prepareExportSortingForDataType(.Inventory)
        // TBD: replace sorting using its ViewModel types as well
        let temp : [InventoryItem] = fetch("InventoryItem", inContext: context, withFilter: rule, andSorting: sorts)
        // run phase 2 filtering, if needed
        return filterInventory(temp, types: searching)
    }
    
    func fetchInventoryInCategory( category: Int16 = CollectionStore.CategoryAll, withSearching searching: [SearchType] = [], andSorting sortType: SortType = .None, fromContext token: Int = mainContextToken ) -> [InventoryItem] {
        if let context = getContextForThread(token) {
            return fetchInventory(context, inCategory: category, withSearching: searching, andSorting: sortType)
        }
        return []
    }
    
    private func fetchCategories(context: NSManagedObjectContext) {
        categories = fetchCategoriesEx(CollectionStore.CategoryAll, inContext: context)
    }
    
    private func fetchCategoriesEx(category: Int16, inContext context: NSManagedObjectContext) -> [Category] {
        let rule: NSPredicate
        if category == CollectionStore.CategoryAll {
            rule = NSPredicate(format: "NOT %K ENDSWITH %@", "name", "(var)")
        } else {
            rule = NSPredicate(format: "%K == %@ AND NOT %K ENDSWITH %@", "number", NSNumber(short: category), "name", "(var)")
        }
        let sort = NSSortDescriptor(key: "number", ascending: true)
        return fetch("Category", inContext: context, withFilter: rule, andSorting: [sort]) as [Category]
    }
    
    func updateCategory( catnum: Int16, completion: ((UpdateComparisonTable) -> Void)? = nil ) {
        // do this on a background thread
        let token = getNewContextTokenForThread()
        self.addOperationToContext(token) {
            // if doing all categories, load each one's data, get the comparison table, and add it to the master table
            // if only doing one category, load its data, get the comparison table, and add that to the master table
            let output = UpdateComparisonTable(model: self)
            if let context = self.getContextForThread(token) {
                let cats = self.fetchCategoriesEx(catnum, inContext: context)
                output.processUpdateComparison(cats)
            }
            self.saveContextForThread(token)
            self.removeContextForThread(token)
            // and then call the completion routine
            if let completion = completion {
                self.addCompletionOperationWithBlock() {
                    completion(output)
                }
            }
        }
    }
}

// global utility funcs for access of CoreData object collections
func fetch<T: NSManagedObject>( entity: String, inContext moc: NSManagedObjectContext, withFilter filter: NSPredicate? = nil, andSorting sorters: [NSSortDescriptor] = [] ) -> [T] {
    var output : [T] = []
    let fetchRequest = NSFetchRequest(entityName: entity)
    fetchRequest.sortDescriptors = sorters
    fetchRequest.predicate = filter
    fetchRequest.fetchBatchSize = 50 // supposedly double the typical number to be displayed is best here
    do {
        let fetchResults = try moc.executeFetchRequest(fetchRequest)
        output = fromNSArray(fetchResults)
    } catch {
        print("Fetch error:\(error)")
    }
    return output
}

func countFetches( entity: String, inContext moc: NSManagedObjectContext, withFilter filter: NSPredicate? = nil ) -> Int {
    let fetchRequest = NSFetchRequest(entityName: entity)
    fetchRequest.predicate = filter
    var error : NSError?
    let fetchResults = moc.countForFetchRequest(fetchRequest, error: &error)
    if let error = error {
        print("Count error:\(error.localizedDescription)")
    }
    return fetchResults
}

