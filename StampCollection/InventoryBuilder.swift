//
//  InventoryBuilder.swift
//  StampCollection
//
//  Created by Michael L Mehr on 6/19/17.
//  Copyright © 2017 Michael L. Mehr. All rights reserved.
//

import Foundation
import CoreData

// the InventoryItemBuilder is used to store an InventoryItem under construction for adding to collection
// Two-step process:
// 1. The base DealerItem is added by the InfoItemsTableVC when user swipes right and selects an item and its W/H state and price type (mint, FDC, ...)
// 2. The user navigates to the proper location in AlbumPageVC and performs an Add action (current page, next, new album, etc.)
// Minimal Data needed: DealerItem ref, priceType code, Album Location (data only, will use FindOrCreate pattern function)
// Optional additions: alt DealerItem ref, desc, notes,

//extension InventoryItem {
//    
//    @NSManaged var albumPage: String!
//    @NSManaged var albumRef: String!
//    @NSManaged var albumSection: String!
//    @NSManaged var albumType: String!
//    @NSManaged var baseItem: String!
//    @NSManaged var catgDisplayNum: Int16
//    @NSManaged var desc: String!
//    @NSManaged var exOrder: Int16
//    @NSManaged var itemType: String!
//    @NSManaged var notes: String!
//    @NSManaged var refItem: String!
//    @NSManaged var wantHave: String!
//    @NSManaged var category: Category!
//    @NSManaged var dealerItem: DealerItem!
//    @NSManaged var page: AlbumPage!
//    @NSManaged var referredItem: DealerItem!
//    
//}
//static func (InventoryItem=>)makeObjectFromData( _ data: [String : String], withRelationships relations: [String:NSManagedObject], inContext moc: NSManagedObjectContext? = nil) -> Bool {
//    // add a new object of this type to the moc
//    if let moc = moc {
//        let entityName = "InventoryItem"
//        if let newObject = NSEntityDescription.insertNewObject(forEntityName: entityName, into: moc) as? InventoryItem {
//            // set the relationships back to the proper objects
//            if let robj = relations["referredItem"] as? DealerItem {
//                newObject.referredItem = robj
//            }
//            if let mobj = relations["dealerItem"] as? DealerItem {
//                newObject.dealerItem = mobj
//            }
//            if let cobj = relations["category"] as? Category {
//                newObject.category = cobj
//            }
//            if let pobj = relations["page"] as? AlbumPage {
//                newObject.page = pobj
//            }
//            // set all the other data values here, so it can use related object reference data
//            InventoryItem.setDataValuesForObject(newObject, fromData: data)
//            return true
//        } else {
//            // report error creating object in CoreData MOC
//            print("Unable to make CoreData InventoryItem from data \(data)")
//        }
//    }
//    return false
//}


class InventoryBuilder {
    private let addWant: Bool
    private let priceType: String
    // to make the final call to build the item we need a data dictionary and several object references
    fileprivate var data: [String:String] = [:]
    fileprivate var relations: [String:NSManagedObject] = [:] // ONLY REF TO CORE DATA?? OH WELL
    private let dealerItem: DealerItem
    private let category: Category
    private var refItem: DealerItem?
    private var albumLoc: AlbumPage?
    
    var isReady: Bool {
        return albumLoc != nil
    }
    
    init(for baseItem: DealerItem, withPriceType ptype: String, want: Bool) {
        priceType = ptype
        data["itemType"] = ptype
        addWant = want
        data["wantHave"] = want ? "w": "h"
        dealerItem = baseItem
        relations["dealerItem"] = baseItem
        data["baseItem"] = baseItem.id!
        data["desc"] = ""
        data["notes"] = ""
        data["refItem"] = "" // but what is the default really? do we need refs for everything? what does IMPORT do?
        category = baseItem.category!
        relations["category"] = category
        data["catgDisplayNum"] = "\(category.number)"
        //relations[""] = ""
    }

    func addRef(_ item: DealerItem) {
        refItem = item
        relations["referredItem"] = item
    }
    
    func addLocation(_ pageRef: AlbumPage) -> Bool {
        // add to any existing album page
        albumLoc = pageRef
        relations["page"] = pageRef
        data["albumPage"] = pageRef.code!
        data["albumRef"] = pageRef.section.ref.code!
        data["albumSection"] = pageRef.section.code!
        data["albumType"] = pageRef.section.ref.family.type.code!
        return true
    }
    
    func addLocation(_ page:String, inSection sect:String?, ofAlbumSeries album:String, num number: Int, ofType albumType: String) -> Bool {
        // add to a new page/section/album/type, which might not be creatable
        let albumRef = album + "\(number)"
        //    @NSManaged var albumPage: String!
        //    @NSManaged var albumRef: String!
        //    @NSManaged var albumSection: String!
        //    @NSManaged var albumType: String!
        var albumData: [String:String] = [:]
        albumData["albumPage"] = page
        albumData["albumRef"] = albumRef
        albumData["albumSection"] = sect
        albumData["albumType"] = albumType
        // MARK: find-or-create pattern implementation
//        static func getObjectInImportData( _ data: [String:String], fromContext moc: NSManagedObjectContext? = nil ) -> AlbumPage? {
//            // will do all of the following to make sure a valid page object exists, and if so, return it (if not, returns nil)
//            // 1. gets code for the desired page from data field "AlbumPage"
//            // 2. calls AlbumSection.getObjectInImportData() to get the section object that is the parent of this page, creating it if needed
//            // 3. calls that object's getMemberObject() with the code from step 1 to get the desired page object, creating it if needed
//            // 4. returns the object, or nil if anything goes wrong
//            if let datacode = data[entityName],
//                let obj = AlbumSection.getObjectInImportData(data, fromContext: moc) {
//                return obj.getMemberObject(datacode, createIfNeeded: true)
//            }
//            return nil
//        }
        // use info provided to create a possibly new AlbumPage, or find the existing one if adding to the current page
        guard let newLoc = AlbumPage.getObjectInImportData(albumData) else { return false }
        return addLocation(newLoc)
    }
    
    func createItem(for model: CollectionStore) -> Bool {
        var result = false
        if !isReady {
            print("Unready to create INV item (missing loc) for ")
        } else {
            result = true
            let token = CollectionStore.mainContextToken
            let mocForThread = model.getContextForThread(token)
            result = InventoryItem.makeObjectFromData(data, withRelationships: relations, inContext: mocForThread)
            if result {
                result = model.saveMainContext()
                if result {
                    print("Successfully created and saved new INV item for ")
                } else {
                    print("Unable to save new INV item for ")
                }
            } else {
                print("Unable to create new INV item for ")
            }
        }
        let desc = formatDealerDetail(dealerItem)
        print(desc)
        return result
    }
    
    func isItemAddable(_ to: AlbumFamilyNavigator) -> Bool {
        // find out if our item is compatible with the album family being navigated
        // typically, category and pricetype are enough to narrow down the list of possible album families' sections
        // come categories have different needs though
        // this should be a subsystem
        //
        // For example, if we have cat 2 (sets) price3 (FDC) then we want the FDC family
        // Some items have an assigned album section, some don't yet (but we will fix this eventually)
        return true
    }
}

extension InventoryBuilder : CustomStringConvertible {
    
    var description: String {
        var retval = "Inventory Builder:\n"
        let headerNames = InventoryItem.getDataHeaderNames()
        for hname in headerNames {
            retval += "  \(hname): \(data[hname] ?? "")\n"
        }
        return retval
    }
    
}
