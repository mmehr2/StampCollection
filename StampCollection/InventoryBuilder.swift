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
// Minimal Data needed: DealerItem ref, priceType code, Album Location (data only, will use FindOrCreate pattern functions*)
// Optional additions: alt DealerItem ref, desc, notes,
// * Discovered during testing: adding to current location requires the actual albumPage object be specified, not just its data (I think)

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
    
    private var isReady: Bool {
        return albumLoc != nil
    }
    
    private var locationDataLevel: Int {
        guard let _ = data["albumPage"] else { return 0 }
        guard let _ = data["albumType"] else { return 0 }
        guard let _ = data["albumSection"] else { return 0 }
        if let _ = data["albumRef"] { return 2 }
        // if no albumRef, allow combination of albumFamily and albumIndex to substitute
        if let _ = data["albumFamily"], let _ = data["albumIndex"] { return 1 }
        return 0
    }
    
    private var canCreate: Bool {
        return locationDataLevel > 0
    }
    
    var navigatorForNewPage: AlbumFamilyNavigator? {
        guard let page = albumLoc else { return nil }
        return AlbumFamilyNavigator(page: page)
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
    
    func addLocation(_ indata:[String:String]) -> Bool {
        // add to a new page based only on album data not object refs
        // required data items: albumPage, albumSection, albumType
        //   and either: albumRef (creates data level 2)
        //   or: both albumFamily and albumIndex (number as String - use "0" for no number) (creates data level 1)
        var albumData = indata
        var retval = true
        if albumData["albumRef"] == nil {
            if let idx = albumData["albumIndex"],
                let fam = albumData["albumFamily"] {
                albumData["albumRef"] = AlbumRef.makeCode(fromFamily: fam, andNumber: idx)
            } else {
                retval = false
            }
        }
        if retval {
            data["albumPage"] = albumData["albumPage"]
            data["albumRef"] = albumData["albumRef"]
            data["albumSection"] = albumData["albumSection"]
            data["albumType"] = albumData["albumType"]
        }
        return retval
    }
    
    func addLocation(_ page:String, inSection sect:String?, ofAlbumSeries album:String, number num: String, ofType albumType: String) -> Bool {
        // add to a new page/section/album/type, which might not be creatable
        // same as addLocation([String:String]) but uses individual data parameters
        var albumData: [String:String] = [:]
        albumData["albumPage"] = page
        albumData["albumFamily"] = album
        albumData["albumIndex"] = num
        albumData["albumSection"] = sect ?? ""
        albumData["albumType"] = albumType
        return addLocation(albumData)
    }
    
    func createItem(for model: CollectionStore) -> Bool {
        var result = false
        var pagestr = ""
        if !canCreate {
            print("Unready to create INV item (missing loc) for ")
        } else {
            result = true
            let token = CollectionStore.mainContextToken
            let mocForThread = model.getContextForThread(token)
            if !isReady {
                // need to create a new album page
                pagestr = " on a new page"
                if locationDataLevel < 2 {
                    // make sure we have the data for it (create the albumRef from components)
                    if !addLocation(data) {
                        print("Unable to fix data of new album page for INV item for ")
                    }
                }
                // the theory here is that proper creation of new pages is done by the inventory item creation system at import time, so same here
            }
            // make sure we have the album page object to continue creation
            if result {
                result = InventoryItem.makeObjectFromData(data, withRelationships: relations, inContext: mocForThread)
                if result {
                    if let invRef = lastCreatedInventoryObject {
                        print("The created item #\(invRef.exOrder) on page \(invRef.page?.code ?? "none")")
                        if let thePage = invRef.page {
                            albumLoc = thePage
                        }
                    }
                    result = model.saveMainContext()
                    if result {
                        print("Successfully created and saved new INV item\(pagestr) for ")
                    } else {
                        print("Unable to save new INV item\(pagestr) for ")
                    }
                } else {
                    print("Unable to create new INV item\(pagestr) for ")
                }
            }
        }
        let desc = formatDealerDetail(dealerItem)
        print(desc)
        return result
    }
    
    func isItemAddable(to: AlbumFamilyNavigator) -> Bool {
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
