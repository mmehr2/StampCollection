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
                fetchAll(nil)
        }
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
    
    func fetchAll(completion: (() -> Void)?) {
        // run this on a background thread (does lots of work! approx 10-20K records)
        // do this on a background thread
        NSOperationQueue().addOperationWithBlock({
            self.mocForThread = CollectionStore.getContextForThread()
            if let moc = self.mocForThread {
                //self.loading = true
                self.fetchCategories(moc)
                self.fetchInfo(moc)
                self.fetchInventory(moc)
                // run the completion block, if any, on the main queue
                if let completion = completion {
                    NSOperationQueue.mainQueue().addOperationWithBlock(completion)
                }
                //self.loading = false
            }
        })
    }
    
    private func fetchCategories(context: NSManagedObjectContext) {
        categories = fetch("Category", inContext: context)
    }
    
    private func fetchInfo(context: NSManagedObjectContext) {
        info = fetch("DealerItem", inContext: context)
    }
    
    private func fetchInventory(context: NSManagedObjectContext) {
        inventory = fetch("InventoryItem", inContext: context)
    }
    
    private func fetch<T: AnyObject>( entity: String, inContext moc: NSManagedObjectContext ) -> [T] {
        var output : [T] = []
        let name = /*CollectionStore.moduleName + "." +*/ entity
        let fetchRequest = NSFetchRequest(entityName: name)
        if let fetchResults = moc.executeFetchRequest(fetchRequest, error: nil) as? [T] {
            output = fetchResults
        }
        return output
    }
}
