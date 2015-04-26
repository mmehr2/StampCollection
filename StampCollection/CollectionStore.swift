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
    static let CategoryAll = -1
    
    static var sharedInstance = CollectionStore()
    
    var persistentStoreCoordinator: NSPersistentStoreCoordinator?

    var categories : [Category] = []
    var info : [DealerItem] = []
    var inventory : [InventoryItem] = []
    //var loading = false // means well, but ... not thread safe??
    
    
    private var mocForThread : NSManagedObjectContext?
    
    init() {
        // get the PSC from the application delegate
        if let ad = UIApplication.sharedApplication().delegate as? AppDelegate,
            psc = ad.persistentStoreCoordinator {
                persistentStoreCoordinator = psc
                // populate the arrays with any managed objects found
                //fetchType(.Categories, background: true)
        }
    }

    static func getMainContext() -> NSManagedObjectContext? {
        if let ad = UIApplication.sharedApplication().delegate as? AppDelegate,
            context = ad.managedObjectContext {
                return context
       }
        return nil
    }
    
    static func getContextForThread() -> NSManagedObjectContext? {
        // this should be called on the thread using the context
        if let psc = sharedInstance.persistentStoreCoordinator {
            var context = NSManagedObjectContext()
            context.persistentStoreCoordinator = psc
            return context
        }
        return nil
    }

    static func saveContext(context: NSManagedObjectContext) {
        var error : NSError?
        if !context.save(&error) {
            println("Error saving CoreData context \(error!)")
        } else {
            println("Successful CoreData save")
        }
    }

    enum FetchType {
        case Categories
        case Info
        case Inventory
    }
    
    func fetchType(type: FetchType, category: Int = CategoryAll, background: Bool = true, completion: (() -> Void)? = nil) {
        // run this on a background thread (does lots of work! approx 10-20K records)
        // do this on a background thread if background flag is set
        let queue = background ? NSOperationQueue() : NSOperationQueue.mainQueue()
        queue.addOperationWithBlock({
            self.mocForThread = CollectionStore.getContextForThread()
            if let moc = self.mocForThread {
                //self.loading = true
                switch type {
                case .Categories:
                    self.fetchCategories(moc)
                    break
                case .Info:
                    self.fetchInfo(moc, inCategory: category)
                    break
                case .Inventory:
                    self.fetchInventory(moc, inCategory: category)
                    break
                }
                // run the completion block, if any, on the main queue
                if let completion = completion {
                    NSOperationQueue.mainQueue().addOperationWithBlock(completion)
                }
                //self.loading = false
            }
        })
    }

    func fetchCategory( category: Int ) -> Category? {
        if let ad = UIApplication.sharedApplication().delegate as? AppDelegate,
            context = ad.managedObjectContext {
                // filter: only for given category (catgDisplayNum) unless -1 is passed
                var rule: NSPredicate? = nil
                if category != CollectionStore.CategoryAll {
                    rule = NSPredicate(format: "%K = %@", "number", NSNumber(integer: category))
                }
                var items : [Category] = fetch("Category", inContext: context, withFilter: rule)
                if items.count > 0 {
                    return items[0]
                }
        }
        return nil
    }
    
    private func fetchCategories(context: NSManagedObjectContext) {
        // filter: remove any objects with code starting with a "*"
        let rule = NSPredicate(format: "NOT %K BEGINSWITH %@", "code", "*")
        // sort: by category.number
        let sort = NSSortDescriptor(key: "number", ascending: true)
        categories = fetch("Category", inContext: context, withFilter: rule, andSorting: [sort])
    }
    
    private func fetchInfo(context: NSManagedObjectContext, inCategory category: Int = -1) {
        // filter: only for given category (catgDisplayNum) unless -1 is passed
        var rule: NSPredicate? = nil
        if category != CollectionStore.CategoryAll {
            rule = NSPredicate(format: "%K = %@", "catgDisplayNum", NSNumber(integer: category))
        }
        info = fetch("DealerItem", inContext: context, withFilter: rule)
    }
    
    private func fetchInventory(context: NSManagedObjectContext, inCategory category: Int = -1) {
        // filter: only for given category (catgDisplayNum) unless -1 is passed
        var rule: NSPredicate? = nil
        if category != CollectionStore.CategoryAll {
            rule = NSPredicate(format: "%K = %@", "catgDisplayNum", NSNumber(integer: category))
        }
        inventory = fetch("InventoryItem", inContext: context, withFilter: rule)
    }
    
    private func fetch<T: NSManagedObject>( entity: String, inContext moc: NSManagedObjectContext, withFilter filter: NSPredicate? = nil, andSorting sorters: [NSSortDescriptor] = [] ) -> [T] {
        var output : [T] = []
        let name = /*CollectionStore.moduleName + "." +*/ entity
        var fetchRequest = NSFetchRequest(entityName: name)
        fetchRequest.sortDescriptors = sorters
        fetchRequest.predicate = filter
        if let fetchResults = moc.executeFetchRequest(fetchRequest, error: nil) as? [T] {
            output = fetchResults
        }
        return output
    }
}
