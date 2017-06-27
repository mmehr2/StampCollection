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
    
    private var hasPage: Bool {
        return albumLoc != nil
    }
    
    private var hasNewPageData: Bool {
        guard let _ = data["AlbumPage"] else { return false }
        guard let _ = data["AlbumType"] else { return false }
        guard let _ = data["AlbumSection"] else { return false }
        guard let _ = data["AlbumRef"] else { return false }
        guard let _ = data["AlbumFamily"] else { return false }
        return true
    }
    
    private var canCreate: Bool {
        return hasPage || hasNewPageData
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
        } else if albumData["albumFamily"] == nil {
            // make sure Family name is also available
            let (albumFamily, albumIndex) = AlbumRef.getFamilyAndNumber(fromRef: albumData["albumRef"]!)
            albumData["albumFamily"] = albumFamily
            albumData["albumIndex"] = albumIndex
        }
        if retval {
            // NOTE: for page object creation, internal data[] names must be capitalized as if doing import from CSV
            data["AlbumPage"] = albumData["albumPage"]
            data["AlbumRef"] = albumData["albumRef"]
            data["AlbumFamily"] = albumData["albumFamily"]
            data["AlbumSection"] = albumData["albumSection"]
            data["AlbumType"] = albumData["albumType"]
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
    
    private func getDataForItemCreation(_ count: Int) -> [String:String] {
        var retval = data
        retval.removeValue(forKey: "AlbumFamily") // used for page creation but not inventory item creation
        retval["exOrder"] = "\(count)" // NOTE: currently this is Int16 - need to expand it after 65K items in inventory
        return retval
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
            if !hasPage {
                // need to create a new album page
                pagestr = " on a new page"
                if let newLoc = AlbumPage.getObjectInImportData(data, fromContext: mocForThread) {
                    result = addLocation(newLoc)
                }
            }
            // make sure we have the album page object to continue creation
            if hasPage {
                let count = model.getCountForType(.inventory, fromCategory: CollectionStore.CategoryAll, inContext: token)
                let itemData = getDataForItemCreation(count)
                result = InventoryItem.makeObjectFromData(itemData, withRelationships: relations, inContext: mocForThread)
                if result {
                    if let invRef = lastCreatedInventoryObject {
                        print("The created item was #\(invRef.exOrder) on page \(invRef.page?.code ?? "none")")
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
            } else {
                print("Unable to create new page for INV item for ")
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
