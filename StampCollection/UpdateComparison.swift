//
//  UpdateComparison.swift
//  StampCollection
//
//  Created by Michael L Mehr on 5/18/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import Foundation
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}


/*
Code is adapted from website BTProcess.PHP file, functions CompareCatalogRecords() and isEqualCR()
*/

enum CompareStatus : Int {
    case unknown = -3
    case onlyInNew
    case onlyInOld
    case unequal
    case equalIfTC
    case equal
}

func <(lhs: CompareStatus, rhs: CompareStatus) -> Bool {
    return lhs.rawValue < rhs.rawValue
}

extension CompareStatus: Comparable { }

typealias InfoRecord = [String:String]
typealias CompRecord = [String:CompareStatus]

private func compareWithTC( _ lhs: String, rhs: String ) -> Bool {
    let output = false
    // we know the strings are unequal here, but PHP would try to convert them to numbers, so let's try that
    // use double conversion if either string contains a '.', else integers
    let hasPdA = lhs.contains(".")
    let hasPdB = rhs.contains(".")
    let epsilon = 1.0e-6 // the tiny number for equality testing of doubles in our context
    if hasPdA || hasPdB {
        if let dblA = lhs.toDouble(), let dblB = rhs.toDouble() {
            if fabs(dblA - dblB) < epsilon {
                return true
            }
        }
    } else {
        if let intA = Int(lhs), let intB = Int(rhs) {
            if intA == intB {
                return true
            }
        }
    }
    return output
}

// basic record comparison
// first param oldRec is a data array created from the existinc CoreData model, as a dictionary of String/String key/value pairs
// second param newRec is the candidate data array created from the comparison target, such as the live BT data candidate
// output is a detailed field-by-field comparison evaluation using the above comparison function and the String == operator
private func compareInfoRecords( _ oldRec: InfoRecord, newRec: InfoRecord ) -> CompRecord {
    var output = CompRecord()
    let akeys = Set(oldRec.keys)
    let bkeys = Set(newRec.keys)
    let abkeys = akeys.union(bkeys)
    for fieldName in abkeys {
        if fieldName == "rownum" {continue} // not sure why PHP code does this
        let inA = akeys.contains(fieldName)
        let inB = bkeys.contains(fieldName)
        if inA && inB {
            let fieldA = oldRec[fieldName]!
            let fieldB = newRec[fieldName]!
            if fieldA == fieldB {
                output[fieldName] = .equal
            } else if compareWithTC(fieldA, rhs: fieldB) {
                output[fieldName] = .equalIfTC
            } else {
                output[fieldName] = .unequal
            }
        } else if inA {
            output[fieldName] = .onlyInOld
        } else if inB {
            output[fieldName] = .onlyInNew
        } else {
            // should never happen, due to nature of set construction
            output[fieldName] = .unknown
        }
    }
    return output
}

func isEqualCR(_ comprec: CompRecord, strict: Bool) -> Bool  {
    let result = true; // return F if different, T if same
    // collapse field name status codes (see above from CompareCatalogRecords()) into boolean result
    // if strict is T, strict comparisons only are allowed (status 2 for all records returns TRUE)
    // if strict is F, looser comparisons are allowed (status 2 or 1 for all records returns TRUE)
    for (_, status) in comprec
    {
        if (strict && status < .equal) {
            return false
        }
        if (!strict && status < .equalIfTC) {
            return false
        }
    }
    return result
}

func hasDifferentDescription(_ comprec: CompRecord) -> Bool  {
    return comprec["description"] < .equalIfTC
}

func getCRReport(_ oldRec: InfoRecord, newRec: InfoRecord, comprec: CompRecord) -> String {
    var output = ""
    for (fname, status) in comprec {
        if status >= .equalIfTC {
            continue
        }
        //
        if output.isEmpty {
            output += "\n"
        }
        let showOld = (status == .unequal || status == .onlyInOld)
        if showOld {
            let oldField = oldRec[fname]!
            output += "OLD.\(fname)(\(oldField))\n"
        }
        let showNew = (status == .unequal || status == .onlyInNew)
        if showNew {
            let newField = newRec[fname]!
            output += "NEW.\(fname)(\(newField))\n"
        }
    }
    return output
}

enum UpdateComparisonResult {
    case sameItem(String)
    // new item matched an existing item entirely (old ID)
    case changedItem(String, BTDealerItem, BTCategory, CompRecord)
    // new item matched an existing item ID with different data (old ID, new item, inp.category, comp.record)
    case changedIDItem(String, BTDealerItem, BTCategory, CompRecord)
    // new item matched an existing item's essential data but with different ID (old ID, new item, cat item, comp.record)
    case addedItem(BTDealerItem, BTCategory)
    // new item does not match an existing item (new item, cat item)
    case removedItem(String)
    // an existing item which did not get a match from any new item (old ID)
    // get some normalized ID strings - either CoreData, BT, or coalesced types
    var idCode: String {
        switch self {
        case .sameItem(let dlrid): return dlrid
        case .removedItem(let dlrid): return dlrid
        case .changedItem(let dlrid, _, _, _): return dlrid
        case .changedIDItem(let dlrid, _, _, _): return dlrid
        case .addedItem(let btitem, _): return btitem.code
        }
    }
    var id: String {
        switch self {
        case .sameItem(let dlrid): return dlrid
        case .removedItem(let dlrid): return dlrid
        case .changedItem(let dlrid, _, _, _): return dlrid
        case .changedIDItem(let dlrid, _, _, _): return dlrid
        case .addedItem: return ""
        }
    }
    var code: String {
        switch self {
        case .sameItem: return ""
        case .removedItem: return ""
        case .changedItem(_, let btitem, _, _): return btitem.code
        case .changedIDItem(_, let btitem, _, _): return btitem.code
        case .addedItem(let btitem, _): return btitem.code
        }
    }
}

enum UpdateCommitAction {
    case none
    case add
    case remove
    case convertType
    case update
    case addAndRemove
}

extension UpdateComparisonResult {
    // this is for use in creating a unique index for the UpdateActionTable
    var commitActionCode: String {
        switch self {
        case .sameItem: return ""
        case .removedItem(let dlrid): return dlrid
        case .changedItem(let dlrid, _, _, _): return dlrid
        case .changedIDItem(let dlrid, let btitem, _, _): return dlrid + "+" + btitem.code
        case .addedItem(let btitem, _): return btitem.code
        }
    }
}

typealias UpdateActionTable = [String: UpdateCommitAction]

class UpdateComparisonTable {
    enum TableID: Int {
        case same = -1, added, removed, changedID, changed, ambiguous
    }
    var dataModel: CollectionStore!

    var sameItems: [UpdateComparisonResult] = []
    var removedItems: [UpdateComparisonResult] = []
    var addedItems: [UpdateComparisonResult] = []
    var changedItems: [UpdateComparisonResult] = []
    var changedIDItems: [UpdateComparisonResult] = []
    var ambiguousChangedItems: [UpdateComparisonResult] = []
    // this is an editable list of items specifying how to commit if not using the default actions for the given idCode value
    fileprivate var commitItems: UpdateActionTable = [:]
    // the oldRecs cache is used to allow lookup only on those items originally searched for (from category) and NOT as currently modified into the database
    // it is populated at commit time and used for searching during commit, replacing the CollectionStore's fetchItemByID() function
    fileprivate var catnums: Set<Int16> = Set()
    fileprivate var oldRecsCache: [String: DealerItem] = [:]
    
    init(model: CollectionStore) {
        dataModel = model
    }

    var count: Int {
        return removedItems.count + addedItems.count + changedItems.count + changedIDItems.count + ambiguousChangedItems.count
    }
    
    fileprivate func getDataItem(_ itemID: String) -> DealerItem? {
        return dataModel.fetchInfoItemByID(itemID)
    }

    func sort() {
        //sameItems = sortCollection(sameItems, byType: .ByImport(true))
        struct Sorter: SortTypeSortable {
            unowned var outerSelf: UpdateComparisonTable // required by Swift 2 - cannot close struct definition over variable at outer scope - TEST THIS!!
            var id: String
            var exVars: InfoDependentVars
            var exOrder: Int16
            var result: UpdateComparisonResult
            var normalizedDate: String { return exVars._exNormalizedDate! }
            var normalizedCode: String { return exVars._normalizedCode! }
            init(_ res: UpdateComparisonResult, os: UpdateComparisonTable) {
                outerSelf = os
                result = res
                var itemID = ""
                switch result {
                case .changedItem(let dealerItemID, _, _, _ ):
                    itemID = dealerItemID
                case .changedIDItem(let dealerItemID, _, _, _ ):
                    itemID = dealerItemID
                case .sameItem(let dealerItemID):
                    itemID = dealerItemID
                case .removedItem(let dealerItemID):
                    itemID = dealerItemID
                case .addedItem(let item, let categ):
                    let catNum = BTCategory.translateNumberToInfoCategory(categ.number)
                    id = item.code
                    exVars = InfoDependentVars(descr: item.descr, id: id, cat: catNum)
                    exOrder = 0 // not supported for BT items (live from website, haven't been ordered on import yet)
                    return
//                default:
//                    break
                }
                let item = outerSelf.getDataItem(itemID)!
                id = item.id
                exVars = InfoDependentVars(descr: item.descriptionX, id: id, cat: item.catgDisplayNum)
                exOrder = item.exOrder
            }
        }

        var sortables : [Sorter] = []
        sortables = removedItems.map { Sorter($0, os: self) }
        sortables = sortCollection(sortables, byType: .byImport(true))
        removedItems = sortables.map { $0.result }
        
        sortables = addedItems.map { Sorter($0, os: self) }
        sortables = sortCollection(sortables, byType: .byCode(true))
        addedItems = sortables.map { $0.result }
        
        sortables = changedItems.map { Sorter($0, os: self) }
        sortables = sortCollection(sortables, byType: .byCode(true))
        changedItems = sortables.map { $0.result }
        
        sortables = changedIDItems.map { Sorter($0, os: self) }
        sortables = sortCollection(sortables, byType: .byCode(true))
        changedIDItems = sortables.map { $0.result }
        
        sortables = ambiguousChangedItems.map { Sorter($0, os: self) }
        sortables = sortCollection(sortables, byType: .byCode(true))
        ambiguousChangedItems = sortables.map { $0.result }
    }

    func merge( _ other: UpdateComparisonTable ) {
        sameItems += other.sameItems
        removedItems += other.removedItems
        addedItems += other.addedItems
        changedItems += other.changedItems
        changedIDItems += other.changedIDItems
        ambiguousChangedItems += other.ambiguousChangedItems
        catnums = catnums.union(other.catnums)
    }

    fileprivate func updateItem( _ item: DealerItem, data: [String: String], comprec: CompRecord ) -> Bool {
        // make changes to a (possibly new) DealerItem from the provided data and comprec
        var dirty = false
        let inputData = item.makeDataFromObject()
        let crr = getCRReport(inputData, newRec: data, comprec: comprec)
        print("Update item:\(crr)")
        var outputData: [String: String] = [:]
        for (fieldName, status) in comprec {
            switch status {
            case .equal:
                break
            case .equalIfTC:
                break
            case .unequal:
                outputData[fieldName] = data[fieldName]!
                dirty = true
            case .onlyInNew:
                print("Unusual field encountered: \(fieldName) only in BTitem ")
            case .onlyInOld:
                print("Unusual field encountered: \(fieldName) not in BT item")
            default:
                print("Unknown field encountered: \(fieldName)")
            }
        }
        if dirty {
            item.updateFromData(outputData)
        }
        return dirty
    }

    fileprivate func checkItemForRemoval( _ item: DealerItem ) -> Bool {
        var result = true
        // initially, this should say NO if item has any inventory or referrals
        // ultimataely, it might be able to deal with transferring the inventory or referring items to unremoved objects
        if let arr = Array(item.inventoryItems) as? [InventoryItem] , arr.count > 0 {
            let items = arr.map{ $0.baseItem }.joined(separator: ", ")
            print("Item \(item.id) cannot be removed due to inventory items \(items).")
            result = false
        }
        if let arr = Array(item.referringItems) as? [InventoryItem] , arr.count > 0 {
            let items = arr.map{ $0.refItem }.joined(separator: ", ")
            print("Item \(item.id) cannot be removed due to referring items \(items).")
            result = false
        }
        return result
    }
    
    fileprivate func populateItemCache(_ categoryNumber: Int16) {
        // retrieve the category object on the current thread, and use its dealerItems to populate the cache
        if let category = dataModel.fetchCategory(categoryNumber) {
            let oldRecs = getDealerItemsForUpdate(category)
            for item in oldRecs {
                let id = item.id!
                if oldRecsCache[id] != nil {
                    print("Cache hit: Duplicate ID \(id) found in category \(category.name)")
                }
                oldRecsCache[id] = item
            }
        }
    }
    
    fileprivate func commitItem( _ item: UpdateComparisonResult, action: UpdateCommitAction ) -> Bool {
        var dirty = false
        if action != .none {
            switch item {
            case .changedItem(let dealerItemID, let btitem, let categ, let comprec ):
                if let dealerItem = oldRecsCache[dealerItemID] {
                    if action == .update {
                        let newData = btitem.createInfoItem(categ)
                        dirty = updateItem(dealerItem, data: newData, comprec: comprec)
                    } else if action == .remove {
                        dirty = true
                        let removeResult = UpdateComparisonResult.removedItem(dealerItemID)
                        let _ = commitItem(removeResult, action: .remove)
                    } else if action == .addAndRemove {
                        dirty = true
                        let removeResult = UpdateComparisonResult.removedItem(dealerItemID)
                        let _ = commitItem(removeResult, action: .remove)
                        let addResult = UpdateComparisonResult.addedItem(btitem, categ)
                        let _ = commitItem(addResult, action: .add)
                    }
                }
            case .changedIDItem(let dealerItemID, let btitem, let categ, let comprec ):
                // NOTE: the need for itemsCache has gone away, since we are caching all dealer items by their old ID
                // the ID of the item may change, but its position in the cache under its old ID index does not
                // therefore, we can just recast this as a ChangedItem and run the commit algorithm on that
                let result = UpdateComparisonResult.changedItem(dealerItemID, btitem, categ, comprec)
                let _ = commitItem(result, action: action)
            case .removedItem(let dealerItemID):
                if let dealerItem = oldRecsCache[dealerItemID] {
                    let _ = /*let removable =*/ checkItemForRemoval(dealerItem)
                    if action == .convertType {
                        dealerItem.markAsAutoGenerated() // items that are auto-generated parts of the database, not sold by dealers in the system
                        dirty = true
                    } else if action == .remove /*&& removable*/ {
                        // NOTE: this has consequences to relationships - will CoreData fix them or barf?
                        //dataModel.removeInfoItemByID(dealerItemID)
                        // UPDATE: rather than remove items, we mark them as retired by the dealer system (special pictypes used for this)
                        dealerItem.markAsRetired()
                        dirty = true
                    }
                }
            case .addedItem(let btitem, let categ):
                if action == .add {
                    var newData = btitem.createInfoItem(categ)
                    // BUGFIX: exOrder is not automatically added by addObjectType() (import delegate does it)
                    let nextOrderSeqNum = dataModel.getCountForType(.info)
                    newData["exOrder"] = "\(nextOrderSeqNum)"
                    dataModel.addObjectType(.info, withData: newData)
                    let _ = /*let nextOrderSeqNum2 ??? =*/ dataModel.getCountForType(.info)
                    dirty = true
                }
            default:
                break
            }
        }
        return dirty
    }

    // commit changes specified by the various item tables
    // the altItems list can be used to alter the default actions for each item; it is indexed by the item's ID code
    // default for removed items is to convert their pictype so they don't get flagged in the future; if removal is desired, they must be added to the altItems list of alternate actions
    // default for added items is to add a new DealerItem object
    // default for changed items is to update existing properties of the DealerItem specified
    // default for changed items with ID change is to update existing properties of the old DealerItem specified (incl.ID change), then update inventory that refers to this item
    //   NOTE: it does NOT redo any relationships, it only changes the strings in the inventory data item that refer to the specified DealerItem object's ID string that has been changed
    fileprivate func commitTable(_ items: [UpdateComparisonResult], altActions: UpdateActionTable = [:]) -> Bool {
        var dirty = false
        // loop through the items and commit each one
        for item in items {
            switch item {
            case .sameItem: continue
            default: break
            }
            let action = getActionForResult(item, actionTable: altActions)
            if action == .none {
                continue
            }
            let flag = commitItem(item, action: action) //commitItems.append( UpdateCommitRecord(item, .ConvertType) )
            dirty = dirty || flag
        }
        return dirty
    }
    
    func getActionForResult( _ item: UpdateComparisonResult, actionTable: UpdateActionTable? = nil ) -> UpdateCommitAction {
        let altActions = actionTable ?? commitItems
        var action = UpdateCommitAction.none
        switch item {
        case .removedItem:
            action = .convertType
        case .addedItem:
            action = .add
        case .changedItem:
            action = .update
        case .changedIDItem:
            action = .update
        default:
            break
        }
        let id = item.commitActionCode
        if let altAction = altActions[id] {
            action = altAction
        }
        return action
    }

    // returns possible supported actions for a result type; NOTE: first item returned is default action
    static func getAllowedActionsForResult( _ item: UpdateComparisonResult, isAmbiguous: Bool = false ) -> [UpdateCommitAction] {
        var output: [UpdateCommitAction] = []
        switch item {
        case .removedItem:
            output = [.convertType, .remove, .none]
        case .addedItem:
            output = [.add, .none]
        case .changedItem:
            if isAmbiguous {
                output = [.update, .addAndRemove, .remove, .none]
            } else {
                output = [.update, .none]
            }
        case .changedIDItem:
            output = [.update, .addAndRemove, .remove, .none]
        default:
            output = [.none]
        }
        return output
    }
    
    static func getDefatulActionForResult( _ item: UpdateComparisonResult ) -> UpdateCommitAction {
        return getAllowedActionsForResult(item).first!
    }
    
    fileprivate static func getPrototypeResultForSection( _ section: TableID ) -> UpdateComparisonResult {
        switch section {
        case .added: return UpdateComparisonResult.addedItem(BTDealerItem(), BTCategory())
        case .ambiguous: return UpdateComparisonResult.changedItem("amb", BTDealerItem(), BTCategory(), CompRecord())
        case .changed: return UpdateComparisonResult.changedItem("chg", BTDealerItem(), BTCategory(), CompRecord())
        case .changedID: return UpdateComparisonResult.changedIDItem("chgid", BTDealerItem(), BTCategory(), CompRecord())
        case .removed: return UpdateComparisonResult.removedItem("rmv")
        case .same: return UpdateComparisonResult.sameItem("same")
        }
    }
    
    static func getAllowedActionsForSection( _ section: TableID ) -> [UpdateCommitAction] {
        let proto = getPrototypeResultForSection(section)
        let ambi = section == .ambiguous
        return getAllowedActionsForResult(proto, isAmbiguous: ambi)
    }

    func setAction( _ action: UpdateCommitAction, forID idCode: String ) {
        commitItems[idCode] = action
    }

    func setDefaultActionForID( _ idCode: String ) {
        commitItems[idCode] = nil
    }
    
    func commit(_ sections: [TableID] = []) {
        // commit the entire category table; should be done here, since we need to control the order of changes and the policy of not having dealt with ambiguities
        // the individual section tables are numbered 0...4 and can be specified; the empty set signifies committing all sections by convention
        let allSectionsSet: Set<TableID> = [.added, .removed, .changedID, .changed, .ambiguous]
        
        let sectionSet: Set<TableID>
        if sections.isEmpty {
            sectionSet = allSectionsSet
        } else {
            sectionSet = Set(sections)
        }
        var dirty = false
        // prepare the category cache table for this run
        for catnum in catnums {
            populateItemCache(catnum)
        }
        // the order of execution is important:
        // removals first, then ID changes must come before additions, finally updates
        if sectionSet.contains(.removed) {
            let flag = commitTable(self.removedItems, altActions: self.commitItems)
            dirty = dirty || flag
        }
        if sectionSet.contains(.changedID) {
            let flag = commitTable(self.changedIDItems, altActions: self.commitItems)
            dirty = dirty || flag
        }
        if sectionSet.contains(.added) {
            let flag = commitTable(self.addedItems, altActions: self.commitItems)
            dirty = dirty || flag
        }
        if sectionSet.contains(.ambiguous) {
            let flag = commitTable(self.ambiguousChangedItems, altActions: self.commitItems)
            dirty = dirty || flag
        }
        if sectionSet.contains(.changed) {
            let flag = commitTable(self.changedItems, altActions: self.commitItems)
            dirty = dirty || flag
        }
        if dirty {
            print("Saving committed changes to CoreData context.")
            let _ = dataModel.saveMainContext()
        }
    }

    // utility function to get relevant dealer items from Category object, filtering out those with pictype < 0
    fileprivate func getDealerItemsForUpdate(_ category: Category) -> [DealerItem] {
        let oldRecsInput = Array(category.dealerItems) as! [DealerItem]
        // ignore input records with pictype of <0 (has no dealer)
        let oldRecs = oldRecsInput.filter{
            if let ptype = Int($0.pictype) {
                if ptype < 0 {
                    return false
                }
            }
            return true
        }
        return oldRecs
    }
    
    // This MONSTER function, translated from the PHP code in BTProcess.PHP, does the magic work of comparing live website data with CoreData model data
    // Currently, it has no output, other than notes to println(); it remains half translated, since the second half makes modifications to the database, which needs major translation work.
    // For the 1st TBD, my plan is to put the FixCatFields() code into the BTDealerItem class itself; for now it will prove that the code is working if it comes up with the list on its own.
    //
    // The following are notes from the PHP code:
    // updates the given category's catalog (L1) database from the corresponding file BAITTOVxx.TXT (xx=cat.number)
    // (these files are made by cut-and-pasting the data portion of the website page into the TXT file)
    // this is the database-aware version for Update usage after the DB has been loaded or reconstructed
    // it should operate in the following modes:
    //   Full(3) - both making L1 changes and annotating those changes to the message parameter (ALLOWS DELETES)
    //   Live(2) - both making L1 changes and annotating those changes to the message parameter (NO DELETES)
    //   Silent(1) - make changes to L1 data silently, with no changes to the message parameter
    //   Review(0) - generate all comments to message parameter, but make no L1 changes
    // Rather than creating an entirely separate version to use the Memory version of $info[], let's see if we can make
    //   a combined one. Code may get ugly :)
    // The idea is that during L1 reconstruction, the Updates are processed one category at a time, so the interactions
    //   with the database don't make sense. The initial construction phase adds records to $info[] one at a time, so
    //   there can be checks along the way, but do these make any sense? Actually, this version could lead to some problems
    //   with identity if a new TXT file comes in and the DB isn't processed to check for identity changes. Existing inventory
    //   is designed to refer to a particular ID, and now it's different. WRONG-O!!
    // L2-Inventory Fixups:
    //   There are several scenarios -
    //      1. All L2 items refer to BaseItem (L1 ID) - so any change needs to modify these directly (custom SQL?)
    //      2. Some L2 items have a RefItem (L1 ID xref) - these are currently set for Folders(fe), Bulletins(bu), and
    //         I'm about to add a referencing system between Joint items, S.Leaves, and S.Folders
    //      3. Check for other uses of the Ref Item field - how? a custom webpage mode?
    func processUpdateComparison(_ category: Category) -> UpdateComparisonTable {
        let output = UpdateComparisonTable(model: dataModel)
        let oldRecs = getDealerItemsForUpdate(category)
        if oldRecs.count == 0 {
            print("No existing INFO records to compare")
            return output
        }
        
        // get the category number from the first item (assume that all are the same for efficiency)
        // NOTE: unfortunate choice of names, redefining 'category' from persistent object to Int16 number
        let category = oldRecs.first!.catgDisplayNum
        let catstr = oldRecs.first!.group
        output.catnums.insert(category) // save this for commit-time use
        // get the corresponding category and item data from the live BT website (assumed to be done loading)
        let webtcatnum = BTCategory.translateNumberFromInfoCategory(category)
        let webtcatX = BTDealerStore.model.getCategoryByNumber(webtcatnum)
        if webtcatX == nil {
            print("No Website category \(webtcatnum) available")
            return output
        }
        let webtcat = webtcatX!
        let newRecs = webtcat.dataItems
        if newRecs.count == 0 {
            print("No Website records to compare in category \(category) = website category \(webtcatnum)")
            return output
        }
        // reimplement this code in modern swift
        // create mappings between set IDs and data index numbers (into old or new arrays) for efficient usage (reverse ID lookup)
        // OR we could just map the actual objects here, and dispense with row numbers...
        var newIndex : [String:BTDealerItem] = [:]
        for newObj in newRecs {
            // detect new data integrity (ID uniqueness) here, making sure the entry is nil before we add it
            if let violationRow = newIndex[newObj.code] {
                print("Integrity violation (NEW) ID=\(newObj.code) already appears in new data at row \(violationRow)")
            } else {
                newIndex[newObj.code] = newObj
            }
        }
        var oldIndex : [String:DealerItem] = [:]
        for oldObj in oldRecs {
            // detect old data integrity (ID uniqueness) here, making sure the entry is nil before we add it
            if let violationRow = oldIndex[oldObj.id] {
                print("Integrity violation (OLD) ID=\(oldObj.id) already appears in old data at row \(violationRow)")
            } else {
                oldIndex[oldObj.id] = oldObj
            }
        }
        // create sets of IDs from each collection
        let newIDs = Set(newIndex.keys) //Set(newRecs.map{$0.code}) // set of all new IDs
        let oldIDs = Set(oldIndex.keys) //Set(oldRecs.map{$0.id}) // set of all old IDs
        var foundIDs = newIDs.intersection(oldIDs) // common IDs
        // we need to classify the found items into same or different; count the same set, compare the different one for updates
        // to do this we need to run the comparison on the object's dictionary forms
        // NOTE: this loop is the largest for most normal situations (updating existing database)
        var samecount = 0
        var updatedIDs = Set<String>()
        var rejectedIDs = Set<String>()
        for id in foundIDs {
            // get the new and old objects referred by this ID
            let oldObj = oldIndex[id]!
            let newObj = newIndex[id]!
            // run the comparison, and see if it's equal or not
            let oldData = oldObj.makeDataFromObject()
            let newData = newObj.createInfoItem(webtcat)
            let compRec = compareInfoRecords(oldData, newRec: newData)
            let compResult = isEqualCR(compRec, strict: false)
            // if equal, just bump the equality counter
            if compResult {
                samecount += 1
                output.sameItems.append(.sameItem(id))
            }
            else if hasDifferentDescription(compRec) {
                // else we should save the ID in the updated set
                rejectedIDs.insert(id)
            } else {
                updatedIDs.insert(id)
                output.changedItems.append(.changedItem(id, newObj, webtcat, compRec))
            }
        }
        // remove the rejected IDs (possible ID change even if found in both old and new) from the found list
        foundIDs = foundIDs.subtracting(rejectedIDs)
        // Phase 2: determine if added and deleted sets are totally unrelated or if any items have commonality
        // This commonality test would compare other identity related fields of the object such as description or picID
        // BT COULD change all of these at once, which is why we need a manual override; for now, just check descriptions
        let addedIDs = newIDs.subtracting(foundIDs) // new but not both
        let deletedIDs = oldIDs.subtracting(foundIDs) // old but not both
        var realaddedIDs = Set<String>() // should be added to the database
        var realdeletedIDs = Set<String>() // should be marked in the database somehow to prevent further comparisons here
        var opcounter = 0
        //var testedIDsByOld = [String:String]() // dictionary of tests, oldID is key, newID is value
        var realchangedIDsByOld = [String:String]() // dictionary of transforms, oldID is key, newID is value
        var realchangedIDsByNew = [String:String]() // dictionary of transforms, newID is key, oldID is value
        // we need to identify "deleted" objects (no or rejected ID match) that have a common description with a new object coming in
        // the code below checks each such object and scans the addition descriptions until the first match is found
        // if so, the ID is in the set of ID-change updates; if no descriptions match, the ID is considered a real deletion
        for delID in deletedIDs {
            let delObj = oldIndex[delID]!
            var matched = false
            // for each deleted object, find if any added object has the same description and/or other fields in common
            for addID in addedIDs {
                // get the two objects represented by the two IDs
                let addObj = newIndex[addID]!
                opcounter += 1 // double check the size of the set; should be half of count(addedIDs) * count(deletedIDs)
                // analyze their similarities:
                // current rule: descriptions must be equal
                // TBD: could also look at catalog fields (2), pic ID codes, or combinations)
                let compResult = delObj.descriptionX == addObj.descr
                // if this comparison passes, it's an ID change with possible other updates: add to the realchangedX dictionaries
                if compResult {
                    realchangedIDsByNew[addID] = delID
                    realchangedIDsByOld[delID] = addID
                    matched = true
                    // add a copy to the output dictionary, creating the auxiliary info items needed
                    let delRec = delObj.makeDataFromObject()
                    let addRec = addObj.createInfoItem(webtcat)
                    let compRec = compareInfoRecords(delRec, newRec: addRec)
                    output.changedIDItems.append(.changedIDItem(delID, addObj, webtcat, compRec))
                    break
                }
            }
            if !matched {
                // if it fails to match in the whole loop, add the the old ID to the realdeleted set
                // we may only choose to mark them in the DB rather than actually delete, depending on if any inventory uses the item
                realdeletedIDs.insert(delID)
            }
        }
        // once this process is over, any additions that haven't been matched as updates are really "additions"
        let addsWhichWereUpdates = Set(realchangedIDsByNew.keys)
        realaddedIDs = addedIDs.subtracting(addsWhichWereUpdates)
        // for items which are still common to both added and removed sets, these COULD be updates OR could be add/del pairs
        // place them in a table of ambiguities for user review; store them efficiently as update items
        let ambiguousChangedIDs = realdeletedIDs.intersection(realaddedIDs)
        realdeletedIDs = realdeletedIDs.subtracting(ambiguousChangedIDs)
        realaddedIDs = realaddedIDs.subtracting(ambiguousChangedIDs)
        // add real added items to output
        for addID in realaddedIDs {
            // check for valid ID (avoid separator records with IDs like "-------")
            if !addID.test("^[a-zA-Z0-9]") {
                print("Rejected addition of data record with ID \(addID)")
                continue
            }
            let addObj = newIndex[addID]!
            output.addedItems.append(.addedItem(addObj, webtcat))
        }
        // add real deleted items to output
        for delID in realdeletedIDs {
            output.removedItems.append(.removedItem(delID))
        }
        // add ambiguous items to output as ChangedItems
        for ambigID in ambiguousChangedIDs {
            let delObj = oldIndex[ambigID]!
            let addObj = newIndex[ambigID]!
            let delRec = delObj.makeDataFromObject()
            let addRec = addObj.createInfoItem(webtcat)
            let compRec = compareInfoRecords(delRec, newRec: addRec)
            output.ambiguousChangedItems.append(.changedItem(ambigID, addObj, webtcat, compRec))
        }
        // sort the various output tables
        output.sort()
        printFullStats(output, categoryStr: catstr!)
        return output
    }

    // call the above function for every category in provided list that is appropriate
    func processUpdateComparison(_ cats: [Category]) {
        for cat in cats {
            // filter out cats who are not of the proper type
            // for now this means ignoring numbers after the Austria/JS one (all generated info, not directly from BT or JS sites)
            // TBD: later we need postprocessing to enter generated info items too (SIMA sets, JOINT items, sheets from sets, etc.)
            if cat.updateable {
                let temp = self.processUpdateComparison(cat)
                self.merge(temp)
            }
        }
    }
}

func printSummaryStats(_ table: UpdateComparisonTable, inCategory categ: String = "") {
    var incount = 0
    var samecount = 0
    var addcount = 0
    var foundcount = 0
    var deletedcount = 0
    var updatedcount = 0
    var addcount2 = 0
    var updatedcount2 = 0
    var deletedcount2 = 0
//    let combinedTable = table.sameItems + table.addedItems + table.removedItems + table.changedItems + table.changedIDItems + table.ambiguousChangedItems
//    // NOTE: BUGFIX - previous line causes compilation times over 1 hour! just splitting it in half fixes the bug
    let combinedTable0 = table.sameItems + table.addedItems + table.removedItems
    let combinedTable1 = table.changedItems + table.changedIDItems + table.ambiguousChangedItems
    let combinedTable = combinedTable0 + combinedTable1
    for result in combinedTable {
        incount += 1
        switch result {
        case .sameItem:
            foundcount += 1
            samecount += 1
        case .changedItem:
            foundcount += 1
            updatedcount += 1
        case .changedIDItem:
            updatedcount2 += 1
            deletedcount += 1
            addcount += 1
        case .addedItem:
            addcount += 1
            addcount2 += 1
        case .removedItem:
            deletedcount2 += 1
            deletedcount += 1
            incount -= 1 // not a NEW item
        }
    }
    let catstr = !categ.isEmpty ? " for Category \(categ)" : ""
    print("Summary of Comparison Table Results\(catstr)")
    print("Of the \(incount) imported lines, \(foundcount) were FOUND in L1 by ID, leading to \(updatedcount) UPDATES, and \(samecount) PRESERVED.")
    print("Of the rest (\(addcount) ADDITIONS) vs. \(deletedcount) DELETIONS), there are \(addcount2) REAL ADDITIONS, \(deletedcount2) REAL DELETIONS, and \(updatedcount2) ID CHANGES.")
}

private func printFullStats(_ table: UpdateComparisonTable, categoryStr: String) {
    printSummaryStats(table, inCategory: categoryStr)
    let addedIDs = table.addedItems.map{ $0.idCode }.joined(separator: ", ")
    let deletedIDs = table.removedItems.map{ $0.idCode }.joined(separator: ", ")
    let changedIDs = table.changedItems.map{ $0.idCode }.joined(separator: ", ")
    let changedID_IDs = table.changedIDItems.map{ $0.idCode }.joined(separator: ", ")
    let changedAmbig_IDs = table.ambiguousChangedItems.map{ $0.idCode }.joined(separator: ", ")
    print("Real additions: \(addedIDs)")
    print("Real deletions: \(deletedIDs)")
    print("Real updates: \(changedIDs)")
    print("Real ID changes: \(changedID_IDs)")
    print("Ambiguous changes (could be Add+Del): \(changedAmbig_IDs)")
}
