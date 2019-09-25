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
    private var relatedFolder: DealerItem?
    
    var allowRelatedFolder: Bool
    
    private var hasPage: Bool {
        return albumLoc != nil
    }
    
    private var hasNewPageData: Bool {
        guard let _ = data["AlbumPage"] else { return false }
        guard let _ = data["AlbumSection"] else { return false }
        guard let _ = data["AlbumRef"] else { return false }
        guard let _ = data["AlbumFamily"] else { return false }
        guard let _ = data["AlbumType"] else { return false }
        return true
    }
    
    private var canCreate: Bool {
        return hasPage || hasNewPageData
    }
    
    private var addingSetFDC: Bool {
        // detects if we are adding a set (cat.2) FDC to the album family "FDC"
        guard let aref = data["AlbumFamily"], aref == "FDC" else { return false }
        let pufdc = PriceUsage(.FDC(false), num: dealerItem.category!.numPriceTypes)
        return dealerItem.catgDisplayNum == CATEG_SETS && priceType == pufdc.ptype.ptype
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
        allowRelatedFolder = true
        //relations[""] = ""
    }

    func addRef(_ item: DealerItem) {
        refItem = item
        relations["referredItem"] = item
    }
    
    func setPartialSetInfo(_ values:[String]) {
        // sets the desc field to the form:
        // Partial set (2v): 2.00(blue) 5.00(red) (#1/3)
        // input is assumed to be in order [N, M, val1, val2, ...]
        // empty entries ("") are ignored, except N and M which get defaults as follows:
        let n : Int
        let m : Int
        // UPDATE: if m is the character "s", the "Partial set" desc refers to sheets (as "sh"), and vals are assumed to be plate numbers
        let useSheet = values[0].lowercased().hasPrefix("s")
        if useSheet {
            let xx = values[1].components(separatedBy: " ")
            if xx.count > 1 {
                n = Int(xx[0]) ?? 1
                m = Int(xx[1]) ?? 0
            } else {
                n = 1
                m = 0
            }
            
        } else {
            n = Int(values[0]) ?? 1
            m = Int(values[1]) ?? 0
        }
        // UPDATE: if m is the character "v", the "Partial set" desc becomes a "Variety" instead
        let useVar = values[0].lowercased().hasPrefix("v")
        // UPDATE: if m is the character "n", desc will not be generated, just notes
        let useOnlyNotes = values[0].lowercased().hasPrefix("n")
        let useDesc = !useOnlyNotes
        // UPDATE: special handling for Notes field: if values[i][0]=="n",append that value verbatim to notes field
        var vals = [String]()
        var notes = [String]()
        for val in values[2..<values.count] {
            if !val.isEmpty {
                if (useDesc && val.lowercased().hasPrefix("n")) {
                    notes.append(String(val.dropFirst()))
                } else {
                    let val_ = useSheet ? "Pl.No." + val : val
                    vals.append(val_)
                }
            }
        }
        if (useDesc) {
            let valstrs = vals.joined(separator: " ")
            let ofstr:String
            if m>0 && n>1 {
                ofstr = " (#\(m)/\(n))"
            } else {
                ofstr = ""
            }
            let titlestr = useVar ? "Variety" : "Partial set"
            let vnumstr = useSheet ? "sh" : "v"
            let desc = "\(titlestr) (\(vals.count)\(vnumstr)): \(valstrs)\(ofstr)"
            print("Setting desc field to \(desc)")
            data["desc"] = desc
        }
        let notestrs = (useOnlyNotes ? vals : notes).joined(separator: " ")
        if (!notestrs.isEmpty) {
            print("Setting notes field to \(notestrs)")
            data["notes"] = notestrs;
        }
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
        //   and either: albumRef
        //   or: both albumFamily and albumIndex (number as String - use "0" for no number)
        var albumData = indata
        var retval = true
        if albumData["albumRef"] == nil {
            if let idx = albumData["albumIndex"],
                let fam = albumData["albumFamily"] {
                albumData["albumRef"] = fam + idx
            } else {
                retval = false
            }
        } else { //if albumData["albumFamily"] == nil {
            // make sure Family name is also available
            let albumFamily = AlbumRef.getFamily(fromRef: albumData["albumRef"]!)
            let albumIndex = AlbumRef.getIndex(fromRef: albumData["albumRef"]!)
            albumData["albumFamily"] = albumFamily
            albumData["albumIndex"] = albumIndex // TBD - not used??
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
    
    func addLocation(_ page:String, inSection sect:String?, ofAlbumSeries album:String, number num: Int, ofType albumType: String) -> Bool {
        // add to a new page/section/album/type, which might not be creatable
        // same as addLocation([String:String]) but uses individual data parameters
        var albumData: [String:String] = [:]
        albumData["albumPage"] = page
        albumData["albumRef"] = AlbumRef.makeCode(fromFamily: album, andNumber: num)
        albumData["albumSection"] = sect ?? ""
        albumData["albumType"] = albumType
        return addLocation(albumData)
    }
    
    private func modifyData(_ data:[String:String], forItemCreation count: Int) -> [String:String] {
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
                let itemData = modifyData(data, forItemCreation: count)
                result = InventoryItem.makeObjectFromData(itemData, withRelationships: relations, inContext: mocForThread)
                if result {
                    if let invRef = InventoryItem.getLastCreatedInventoryObject() {
                        print("The created item was #\(invRef.exOrder) on page \(invRef.page?.code ?? "none")")
                        // also if we are adding an FDC to the FDC album, add the related folder if found
                        if allowRelatedFolder && addingSetFDC {
                            findRelatedFolder(in: model)
                            if let _ = relatedFolder {
                                // add the folder to inventory on the same page, and make sure it refers to the set item used
                                let fdata = getRelatedFolderData()
                                let folderRlations = getRelatedFolderRelations()
                                let folderData = modifyData(fdata, forItemCreation: count + 1)
                                result = InventoryItem.makeObjectFromData(folderData, withRelationships: folderRlations, inContext: mocForThread)
                                if result {
                                    if let invFolderRef = InventoryItem.getLastCreatedInventoryObject() {
                                        print("The created item for the related folder was #\(invFolderRef.exOrder) on page \(invFolderRef.page?.code ?? "none")")
                                    }
                                }
                           }
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
            } else {
                print("Unable to create new page for INV item for ")
            }
        }
        let desc = formatDealerDetail(dealerItem)
        print(desc)
        return result
    }
    
    func findRelatedFolder(in model: CollectionStore) {
        // look up the Info Folder item, if any, with the same description as the base DealerItem we are building
        let descWords = dealerItem.descriptionX!.components(separatedBy: " ").filter() { $0.count > 5 }
        let search = SearchType.keyWordListAll(descWords)
        let fitems = model.fetchInfoInCategory(CATEG_INFOLDERS, withSearching: [search], andSorting: .byCode(false))
        if fitems.count == 0 {
            print("Could not find folder related to item \(dealerItem.id!): \(dealerItem.descriptionX!)")
        } else {
            print("Examining \(fitems.count) related folders for exact match to item \(dealerItem.id!): \(dealerItem.descriptionX!)")
            for fldr in fitems {
                if fldr.descriptionX! == dealerItem.descriptionX! {
                    relatedFolder = fldr
                    print("Found related folder #\(fldr.id!): \(fldr.descriptionX!)")
                }
            }
        }
    }
    
    private func getRelatedFolderData() -> [String:String] {
        // create a copy of the inventory data and modify it
        var rfdata = data
        rfdata["itemType"] = "price1"
        rfdata["wantHave"] = data["wantHave"]
        rfdata["baseItem"] = relatedFolder!.id!
        rfdata["desc"] = ""
        rfdata["notes"] = ""
        rfdata["refItem"] = dealerItem.id!
        rfdata["catgDisplayNum"] = "\(relatedFolder!.category.number)"
        return rfdata
    }
    
    private func getRelatedFolderRelations() -> [String:NSManagedObject] {
        // create a copy of the inventory relations and modify it
        var rfrelations = relations
        rfrelations["dealerItem"] = relatedFolder!
        rfrelations["category"] = relatedFolder!.category!
        rfrelations["referredItem"] = dealerItem
        rfrelations["page"] = albumLoc!
        return rfrelations
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
