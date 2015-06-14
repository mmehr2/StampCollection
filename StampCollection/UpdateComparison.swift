//
//  UpdateComparison.swift
//  StampCollection
//
//  Created by Michael L Mehr on 5/18/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import Foundation

/*
Code is adapted from website BTProcess.PHP file, functions CompareCatalogRecords() and isEqualCR()
*/

enum CompareStatus : Int {
    case Unknown = -3
    case OnlyInNew
    case OnlyInOld
    case Unequal
    case EqualIfTC
    case Equal
}

func <(lhs: CompareStatus, rhs: CompareStatus) -> Bool {
    return lhs.rawValue < rhs.rawValue
}

extension CompareStatus: Comparable { }

typealias InfoRecord = [String:String]
typealias CompRecord = [String:CompareStatus]

private func compareWithTC( lhs: String, rhs: String ) -> Bool {
    var output = false
    // we know the strings are unequal here, but PHP would try to convert them to numbers, so let's try that
    // use double conversion if either string contains a '.', else integers
    let hasPdA = lhs.contains(".")
    let hasPdB = rhs.contains(".")
    let epsilon = 1.0e-6 // the tiny number for equality testing of doubles in our context
    if hasPdA || hasPdB {
        if let dblA = lhs.toDouble(), dblB = rhs.toDouble() {
            if fabs(dblA - dblB) < epsilon {
                return true
            }
        }
    } else {
        if let intA = lhs.toInt(), intB = rhs.toInt() {
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
private func compareInfoRecords( oldRec: InfoRecord, newRec: InfoRecord ) -> CompRecord {
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
                output[fieldName] = .Equal
            } else if compareWithTC(fieldA, fieldB) {
                output[fieldName] = .EqualIfTC
            } else {
                output[fieldName] = .Unequal
            }
        } else if inA {
            output[fieldName] = .OnlyInOld
        } else if inB {
            output[fieldName] = .OnlyInNew
        } else {
            // should never happen, due to nature of set construction
            output[fieldName] = .Unknown
        }
    }
    return output
}

func isEqualCR(comprec: CompRecord, strict: Bool) -> Bool  {
    var result = true; // return F if different, T if same
    // collapse field name status codes (see above from CompareCatalogRecords()) into boolean result
    // if strict is T, strict comparisons only are allowed (status 2 for all records returns TRUE)
    // if strict is F, looser comparisons are allowed (status 2 or 1 for all records returns TRUE)
    for (_, status) in comprec
    {
        if (strict && status < .Equal) {
            return false
        }
        if (!strict && status < .EqualIfTC) {
            return false
        }
    }
    return result
}

func hasDifferentDescription(comprec: CompRecord) -> Bool  {
    return comprec["description"] < .EqualIfTC
}

func getCRReport(oldRec: InfoRecord, newRec: InfoRecord, comprec: CompRecord) -> String {
    var output = ""
    for (fname, status) in comprec {
        if status >= .EqualIfTC {
            continue
        }
        //
        if output.isEmpty {
            output += "\n"
        }
        let showOld = (status == .Unequal || status == .OnlyInOld)
        if showOld {
            let oldField = oldRec[fname]!
            output += "OLD.\(fname)(\(oldField))\n"
        }
        let showNew = (status == .Unequal || status == .OnlyInNew)
        if showNew {
            let newField = newRec[fname]!
            output += "NEW.\(fname)(\(newField))\n"
        }
    }
    return output
}

enum UpdateComparisonResult {
    case SameItem(String)
    // new item matched an existing item entirely (old ID)
    case ChangedItem(String, BTDealerItem, BTCategory, CompRecord)
    // new item matched an existing item ID with different data (old ID, new item, inp.category, comp.record)
    case ChangedIDItem(String, BTDealerItem, BTCategory, CompRecord)
    // new item matched an existing item's essential data but with different ID (old ID, new item, cat item, comp.record)
    case AddedItem(BTDealerItem, BTCategory)
    // new item does not match an existing item (new item, cat item)
    case RemovedItem(String)
    // an existing item which did not get a match from any new item (old ID)
    // get some normalized ID strings - either CoreData, BT, or coalesced types
    var idCode: String {
        switch self {
        case .SameItem(let dlrid): return dlrid
        case .RemovedItem(let dlrid): return dlrid
        case .ChangedItem(let dlrid, _, _, _): return dlrid
        case .ChangedIDItem(let dlrid, _, _, _): return dlrid
        case .AddedItem(let btitem, _): return btitem.code
        }
    }
    var id: String {
        switch self {
        case .SameItem(let dlrid): return dlrid
        case .RemovedItem(let dlrid): return dlrid
        case .ChangedItem(let dlrid, _, _, _): return dlrid
        case .ChangedIDItem(let dlrid, _, _, _): return dlrid
        case .AddedItem: return ""
        }
    }
    var code: String {
        switch self {
        case .SameItem: return ""
        case .RemovedItem: return ""
        case .ChangedItem(_, let btitem, _, _): return btitem.code
        case .ChangedIDItem(_, let btitem, _, _): return btitem.code
        case .AddedItem(let btitem, _): return btitem.code
        }
    }
}

enum UpdateCommitAction {
    case None
    case Add
    case Remove
    case ConvertType
    case Update
    case AddAndRemove
//    case UpdateWithIDFix
}

typealias UpdateActionTable = [String: UpdateCommitAction]

class UpdateComparisonTable {
    enum TableID: Int {
        case Same = -1, Added, Removed, ChangedID, Changed, Ambiguous
    }
    var sameItems: [UpdateComparisonResult] = []
    var removedItems: [UpdateComparisonResult] = []
    var addedItems: [UpdateComparisonResult] = []
    var changedItems: [UpdateComparisonResult] = []
    var changedIDItems: [UpdateComparisonResult] = []
    var ambiguousChangedItems: [UpdateComparisonResult] = []
    // this is an editable list of items specifying how to commit if not using the default actions for the given idCode value
    var commitItems: UpdateActionTable = [:]
    // the item cache is used to cache ID-to-object mappings locally to avoid issues during the ID change process
    var itemCache: [String: DealerItem] = [:]

    var count: Int {
        return removedItems.count + addedItems.count + changedItems.count + changedIDItems.count + ambiguousChangedItems.count
    }

    func sort() {
        //sameItems = sortCollection(sameItems, byType: .ByImport(true))
        struct Sorter: SortTypeSortable {
            var id: String
            var exVars: InfoDependentVars
            var exOrder: Int16
            var result: UpdateComparisonResult
            var normalizedDate: String { return exVars._exNormalizedDate! }
            var normalizedCode: String { return exVars._normalizedCode! }
            init(_ res: UpdateComparisonResult) {
                result = res
                var itemID = ""
                switch result {
                case .ChangedItem(let dealerItemID, _, _, _ ):
                    itemID = dealerItemID
                case .ChangedIDItem(let dealerItemID, _, _, _ ):
                    itemID = dealerItemID
                case .SameItem(let dealerItemID):
                    itemID = dealerItemID
                case .RemovedItem(let dealerItemID):
                    itemID = dealerItemID
                case .AddedItem(let item, let categ):
                    let catNum = BTCategory.translateNumberToInfoCategory(categ.number)
                    id = item.code
                    exVars = InfoDependentVars(descr: item.descr, id: id, cat: catNum)
                    exOrder = 0 // not supported for BT items (live from website, haven't been ordered on import yet)
                    return
                default:
                    break
                }
                let item = CollectionStore.sharedInstance.fetchInfoItemByID(itemID)!
                id = item.id
                exVars = InfoDependentVars(descr: item.descriptionX, id: id, cat: item.catgDisplayNum)
                exOrder = item.exOrder
            }
        }
    
        var sortables : [Sorter] = []
        sortables = removedItems.map { Sorter($0) }
        sortables = sortCollection(sortables, byType: .ByImport(true))
        removedItems = sortables.map { $0.result }
        
        sortables = addedItems.map { Sorter($0) }
        sortables = sortCollection(sortables, byType: .ByCode(true))
        addedItems = sortables.map { $0.result }
        
        sortables = changedItems.map { Sorter($0) }
        sortables = sortCollection(sortables, byType: .ByCode(true))
        changedItems = sortables.map { $0.result }
        
        sortables = changedIDItems.map { Sorter($0) }
        sortables = sortCollection(sortables, byType: .ByCode(true))
        changedIDItems = sortables.map { $0.result }
        
        sortables = ambiguousChangedItems.map { Sorter($0) }
        sortables = sortCollection(sortables, byType: .ByCode(true))
        ambiguousChangedItems = sortables.map { $0.result }
    }
    
    func merge( other: UpdateComparisonTable ) {
        sameItems += other.sameItems
        removedItems += other.removedItems
        addedItems += other.addedItems
        changedItems += other.changedItems
        changedIDItems += other.changedIDItems
        ambiguousChangedItems += other.ambiguousChangedItems
    }

    private func updateItem( item: DealerItem, data: [String: String], comprec: CompRecord ) -> Bool {
        // make changes to a (possibly new) DealerItem from the provided data and comprec
        var dirty = false
        var inputData = item.makeDataFromObject()
        let crr = getCRReport(inputData, data, comprec)
        println("Update item:\(crr)")
        var outputData: [String: String] = [:]
        for (fieldName, status) in comprec {
            switch status {
            case .Equal:
                break
            case .EqualIfTC:
                break
            case .Unequal:
                outputData[fieldName] = data[fieldName]!
                dirty = true
            case .OnlyInNew:
                println("Unusual field encountered: \(fieldName) only in BTitem ")
            case .OnlyInOld:
                println("Unusual field encountered: \(fieldName) not in BT item")
            default:
                println("Unknown field encountered: \(fieldName)")
            }
        }
        if dirty {
            item.updateFromData(outputData)
        }
        return dirty
    }

    private func checkItemForRemoval( item: DealerItem ) -> Bool {
        var result = true
        // initially, this should say NO if item has any inventory or referrals
        // ultimataely, it might be able to deal with transferring the inventory or referring items to unremoved objects
        if let arr = Array(item.inventoryItems) as? [InventoryItem] where arr.count > 0 {
            let items = ", ".join(arr.map{ $0.baseItem })
            println("Item \(item.id) cannot be removed due to inventory items \(items).")
            result = false
        }
        if let arr = Array(item.referringItems) as? [InventoryItem] where arr.count > 0 {
            let items = ", ".join(arr.map{ $0.refItem })
            println("Item \(item.id) cannot be removed due to referring items \(items).")
            result = false
        }
        return result
    }
    
    private func commitItem( item: UpdateComparisonResult, action: UpdateCommitAction ) -> Bool {
        var dirty = false
        if action != .None {
            switch item {
            case .ChangedItem(let dealerItemID, let btitem, let categ, let comprec ):
                if let dealerItem = CollectionStore.sharedInstance.fetchInfoItemByID(dealerItemID) {
                    if action == .Update {
                        let newData = btitem.createInfoItem(categ)
                        dirty = updateItem(dealerItem, data: newData, comprec: comprec)
                    } else if action == .AddAndRemove {
                        dirty = true
                        let removeResult = UpdateComparisonResult.RemovedItem(dealerItemID)
                        commitItem(removeResult, action: .Remove)
                        let addResult = UpdateComparisonResult.AddedItem(btitem, categ)
                        commitItem(addResult, action: .Add)
                    }
                }
            case .ChangedIDItem(let dealerItemID, let btitem, let categ, let comprec ):
                // NOTE: we must get ID changeable items from the local cache rather than the store, since we are changing their fetch IDs one at a time and could get the wrong object
                if let dealerItem = itemCache[dealerItemID] where action == .Update {
                    let newData = btitem.createInfoItem(categ)
                    dirty = updateItem(dealerItem, data: newData, comprec: comprec)
                }
            case .RemovedItem(let dealerItemID):
                if let dealerItem = CollectionStore.sharedInstance.fetchInfoItemByID(dealerItemID) {
                    let removable = checkItemForRemoval(dealerItem)
                    if action == .ConvertType {
                        dealerItem.pictype = "-1"
                        dirty = true
                    } else if action == .Remove && removable {
                        // NOTE: this has consequences to relationships - will CoreData fix them or barf?
                        CollectionStore.sharedInstance.removeInfoItemByID(dealerItemID)
                        dirty = true
                    }
                }
            case .AddedItem(let btitem, let categ):
                if action == .Add {
                    var newData = btitem.createInfoItem(categ)
                    // BUGFIX: exOrder is not automatically added by addObjectType() (import delegate does it)
                    let nextOrderSeqNum = CollectionStore.sharedInstance.getCountForType(.Info)
                    newData["exOrder"] = "\(nextOrderSeqNum)"
                    CollectionStore.sharedInstance.addObjectType(.Info, withData: newData)
                    let nextOrderSeqNum2 = CollectionStore.sharedInstance.getCountForType(.Info)
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
    private func commitTable(items: [UpdateComparisonResult], altActions: UpdateActionTable = [:]) -> Bool {
        var dirty = false
        // preload the itemCache if needed with any ID change objects
        itemCache = [:]
        for item in items {
            switch item {
            case .ChangedIDItem(let dealerItemID, _, _, _):
                // for ID changes, we need to cache the DealerItems locally to avoid ID fetch problems during the modification
                itemCache[dealerItemID] = CollectionStore.sharedInstance.fetchInfoItemByID(dealerItemID)
            default:
                continue
            }
        }
        // loop through the items again and commit each one
        var action = UpdateCommitAction.None
        for item in items {
            switch item {
            case .RemovedItem:
                action = .ConvertType
            case .AddedItem:
                action = .Add
            case .ChangedItem:
                action = .Update
            case .ChangedIDItem:
                action = .Update
            default:
                continue
            }
            var id = item.idCode
            if let altAction = altActions[id] {
                action = altAction
            }
            let flag = commitItem(item, action: action) //commitItems.append( UpdateCommitRecord(item, .ConvertType) )
            dirty = dirty || flag
        }
        return dirty
    }
    
    func commit(sections: [TableID] = []) {
        // commit the entire category table; should be done here, since we need to control the order of changes and the policy of not having dealt with ambiguities
        // the individual section tables are numbered 0...4 and can be specified; the empty set signifies committing all sections by convention
        let allSectionsSet: Set<TableID> = [.Added, .Removed, .ChangedID, .Changed, .Ambiguous]
        
        let sectionSet: Set<TableID>
        if sections.isEmpty {
            sectionSet = allSectionsSet
        } else {
            sectionSet = Set(sections)
        }
        var dirty = false
        // however the order is important:
        // ID changes must come before additions, then removals, finally updates
        if sectionSet.contains(.ChangedID) {
            let flag = commitTable(self.changedIDItems, altActions: self.commitItems)
            dirty = dirty || flag
        }
        if sectionSet.contains(.Added) {
            let flag = commitTable(self.addedItems, altActions: self.commitItems)
            dirty = dirty || flag
        }
        if sectionSet.contains(.Removed) {
            let flag = commitTable(self.removedItems, altActions: self.commitItems)
            dirty = dirty || flag
        }
        if sectionSet.contains(.Ambiguous) {
            let flag = commitTable(self.ambiguousChangedItems, altActions: self.commitItems)
            dirty = dirty || flag
        }
        if sectionSet.contains(.Changed) {
            let flag = commitTable(self.changedItems, altActions: self.commitItems)
            dirty = dirty || flag
        }
        if dirty {
            println("Saving committed changes to CoreData context.")
            CollectionStore.sharedInstance.saveMainContext()
        }
    }
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
func processUpdateComparison(category: Category) -> UpdateComparisonTable {
    var output = UpdateComparisonTable()
    let oldRecsInput = Array(category.dealerItems) as! [DealerItem]
    if oldRecsInput.count == 0 {
        println("No existing INFO records to compare")
        return output
    }
    // ignore input records with pictype of <0 (has no dealer)
    let oldRecs = oldRecsInput.filter{
        if let ptype = $0.pictype.toInt() {
            if ptype < 0 {
                return false
            }
        }
        return true
    }
    
    // get the category number from the first item (assume that all are the same for efficiency)
    // NOTE: unfortunate choice of names, redefining 'category' from persistent object to Int16 number
    let category = oldRecs.first!.catgDisplayNum
    let catstr = oldRecs.first!.group
    // get the corresponding category and item data from the live BT website (assumed to be done loading)
    let webtcatnum = BTCategory.translateNumberFromInfoCategory(category)
    let webtcat = BTDealerStore.model.getCategoryByNumber(webtcatnum)!
    let newRecs: [BTDealerItem] = webtcat.dataItems
    if newRecs.count == 0 {
        println("No Website records to compare in category \(category) = website category \(webtcatnum)")
        return output
    }
    // reimplement this code in modern swift
    // create mappings between set IDs and data index numbers (into old or new arrays) for efficient usage (reverse ID lookup)
    // OR we could just map the actual objects here, and dispense with row numbers...
    var newIndex : [String:BTDealerItem] = [:]
    for (newRow, newObj) in enumerate(newRecs) {
        // detect new data integrity (ID uniqueness) here, making sure the entry is nil before we add it
        if let violationRow = newIndex[newObj.code] {
            println("Integrity violation (NEW) ID=\(newObj.code) already appears in new data at row \(violationRow)")
        } else {
            newIndex[newObj.code] = newObj
        }
    }
    var oldIndex : [String:DealerItem] = [:]
    for (oldRow, oldObj) in enumerate(oldRecs) {
        // detect old data integrity (ID uniqueness) here, making sure the entry is nil before we add it
        if let violationRow = oldIndex[oldObj.id] {
            println("Integrity violation (OLD) ID=\(oldObj.id) already appears in old data at row \(violationRow)")
        } else {
            oldIndex[oldObj.id] = oldObj
        }
    }
    // create sets of IDs from each collection
    let newIDs = Set(newIndex.keys) //Set(newRecs.map{$0.code}) // set of all new IDs
    let oldIDs = Set(oldIndex.keys) //Set(oldRecs.map{$0.id}) // set of all old IDs
    var foundIDs = newIDs.intersect(oldIDs) // common IDs
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
        let compRec = compareInfoRecords(oldData, newData)
        let compResult = isEqualCR(compRec, false)
        // if equal, just bump the equality counter
        if compResult {
            ++samecount
            output.sameItems.append(.SameItem(id))
        }
        // else we should save the ID in the updated set
        else if hasDifferentDescription(compRec) {
            rejectedIDs.insert(id)
        } else {
            updatedIDs.insert(id)
            output.changedItems.append(.ChangedItem(id, newObj, webtcat, compRec))
        }
    }
    // remove the rejected IDs (possible ID change even if found in both old and new) from the found list
    foundIDs = foundIDs.subtract(rejectedIDs)
    // Phase 2: determine if added and deleted sets are totally unrelated or if any items have commonality
    // This commonality test would compare other identity related fields of the object such as description or picID
    // BT COULD change all of these at once, which is why we need a manual override; for now, just check descriptions
    let addedIDs = newIDs.subtract(foundIDs) // new but not both
    let deletedIDs = oldIDs.subtract(foundIDs) // old but not both
    var realaddedIDs = Set<String>() // should be added to the database
    var realdeletedIDs = Set<String>() // should be marked in the database somehow to prevent further comparisons here
    var opcounter = 0
    var testedIDsByOld = [String:String]() // dictionary of tests, oldID is key, newID is value
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
            ++opcounter // double check the size of the set; should be half of count(addedIDs) * count(deletedIDs)
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
                let compRec = compareInfoRecords(delRec, addRec)
                output.changedIDItems.append(.ChangedIDItem(delID, addObj, webtcat, compRec))
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
    realaddedIDs = addedIDs.subtract(addsWhichWereUpdates)
    // for items which are still common to both added and removed sets, these COULD be updates OR could be add/del pairs
    // place them in a table of ambiguities for user review; store them efficiently as update items
    let ambiguousChangedIDs = realdeletedIDs.intersect(realaddedIDs)
    realdeletedIDs = realdeletedIDs.subtract(ambiguousChangedIDs)
    realaddedIDs = realaddedIDs.subtract(ambiguousChangedIDs)
    // add real added items to output
    for addID in realaddedIDs {
        let addObj = newIndex[addID]!
        output.addedItems.append(.AddedItem(addObj, webtcat))
    }
    // add real deleted items to output
    for delID in realdeletedIDs {
        output.removedItems.append(.RemovedItem(delID))
    }
    // add ambiguous items to output as ChangedItems
    for ambigID in ambiguousChangedIDs {
        let delObj = oldIndex[ambigID]!
        let addObj = newIndex[ambigID]!
        let delRec = delObj.makeDataFromObject()
        let addRec = addObj.createInfoItem(webtcat)
        let compRec = compareInfoRecords(delRec, addRec)
        output.ambiguousChangedItems.append(.ChangedItem(ambigID, addObj, webtcat, compRec))
    }
    // sort the various output tables
    output.sort()
    printFullStats(output, catstr)
    return output
}

func printSummaryStats(table: UpdateComparisonTable, inCategory categ: String = "") {
    var incount = 0
    var samecount = 0
    var addcount = 0
    var foundcount = 0
    var deletedcount = 0
    var updatedcount = 0
    var addcount2 = 0
    var updatedcount2 = 0
    var deletedcount2 = 0
    let combinedTable = table.sameItems + table.addedItems + table.removedItems + table.changedItems + table.changedIDItems + table.ambiguousChangedItems
    for result in combinedTable {
        ++incount
        switch result {
        case .SameItem:
            ++foundcount
            ++samecount
        case .ChangedItem:
            ++foundcount
            ++updatedcount
        case .ChangedIDItem:
            ++updatedcount2
            ++deletedcount
            ++addcount
        case .AddedItem:
            ++addcount
            ++addcount2
        case .RemovedItem:
            ++deletedcount2
            ++deletedcount
            --incount // not a NEW item
        }
    }
    let catstr = !categ.isEmpty ? " for Category \(categ)" : ""
    println("Summary of Comparison Table Results\(catstr)")
    println("Of the \(incount) imported lines, \(foundcount) were FOUND in L1 by ID, leading to \(updatedcount) UPDATES, and \(samecount) PRESERVED.")
    println("Of the rest (\(addcount) ADDITIONS) vs. \(deletedcount) DELETIONS), there are \(addcount2) REAL ADDITIONS, \(deletedcount2) REAL DELETIONS, and \(updatedcount2) ID CHANGES.")
}

func printFullStats(table: UpdateComparisonTable, categoryStr: String) {
    printSummaryStats(table, inCategory: categoryStr)
    let addedIDs = ", ".join(table.addedItems.map{ $0.idCode })
    let deletedIDs = ", ".join(table.removedItems.map{ $0.idCode })
    let changedIDs = ", ".join(table.changedItems.map{ $0.idCode })
    let changedID_IDs = ", ".join(table.changedIDItems.map{ $0.idCode })
    let changedAmbig_IDs = ", ".join(table.ambiguousChangedItems.map{ $0.idCode })
    println("Real additions: \(addedIDs)")
    println("Real deletions: \(deletedIDs)")
    println("Real updates: \(changedIDs)")
    println("Real ID changes: \(changedID_IDs)")
    println("Ambiguous changes (could be Add+Del): \(changedAmbig_IDs)")
}

/*
BEFORE MAKING ALGO CHANGES:
Showing ALL (#-1) Info Items
No existing INFO records to compare
Summary of Comparison Table Results for Category Sets, SS, FDC
Of the 1072 imported lines, 1041 were FOUND in L1 by ID, leading to 5 UPDATES, and 1036 PRESERVED.
Of the rest (31 ADDITIONS) vs. 0 DELETIONS), there are 31 REAL ADDITIONS, 0 REAL DELETIONS, and 0 ID CHANGES.
Real additions: 6110s1236, 6110s1237, 6110s1238, 6110s1239, 6110s1241, 6110s1243, 6110s1246, 6110s1247, 6110s1248, 6110s1250, 6110s1251, 6110s1252, 6110s1255, 6110s1257, 6110s1258, 6110s1260, 6110s1262, 6110s1263, 6110s1264, 6110s1265, 6110s1266, 6110s1267, 6110s1269, 6110s1270, 6110s1271, 6110s1272, 6110s1273, 6110s1274, 6110s1275, 6110s1276, 6110s1278
Real deletions:
Real updates: 6110s1, 6110s39, 6110s90, 6110s670, 6110s1155
Real ID changes:
Summary of Comparison Table Results for Category Booklets
Of the 141 imported lines, 136 were FOUND in L1 by ID, leading to 91 UPDATES, and 45 PRESERVED.
Of the rest (5 ADDITIONS) vs. 0 DELETIONS), there are 5 REAL ADDITIONS, 0 REAL DELETIONS, and 0 ID CHANGES.
Real additions: 6110e037G, 6110e144D, 6110e1245, 6110e245A, 6110e1254
Real deletions:
Real updates: 6110e536, 6110e537, 6110e537A, 6110e558, 6110e567A, 6110e567B, 6110e567C, 6110e567D, 6110e567E, 6110e567F, 6110e567G, 6110e567H, 6110e580, 6110e605, 6110e617, 6110e617A, 6110e625, 6110e634, 6110e676, 6110e688A, 6110e688B, 6110e707, 6110e718A, 6110e718B, 6110e718C, 6110e733, 6110e733A, 6110e761, 6110e780, 6110e800, 6110e827, 6110e827A, 6110e871, 6110e873, 6110e873A, 6110e894, 6110e923A, 6110e923B, 6110e937, 6110e937A, 6110e937B, 6110e937C, 6110e937D, 6110e937E, 6110e937F, 6110e937G, 6110e937H, 6110e956, 6110e976, 6110e1001, 6110e1018, 6110e018A, 6110e018B, 6110e018C, 6110e018D, 6110e018E, 6110e018F, 6110e018G, 6110e1026, 6110e1027, 6110e1028, 6110e1029, 6110e1037, 6110e037B, 6110e037D, 6110e037E, 6110e037F, 6110e1066, 6110e1074, 6110e074A, 6110e074B, 6110e074C, 6110e074D, 6110e074E, 6110e074F, 6110e1104, 6110e1117, 6110e1120, 6110e1128, 6110e128A, 6110e128B, 6110e128C, 6110e1144, 6110e144A, 6110e144B, 6110e144C, 6110e1149, 6110e1176, 6110e1182, 6110e1214, 6110e1227
Real ID changes:
No existing INFO records to compare
No existing INFO records to compare
No existing INFO records to compare
No existing INFO records to compare
No existing INFO records to compare
Summary of Comparison Table Results for Category Exhibition Show Cards
Of the 38 imported lines, 38 were FOUND in L1 by ID, leading to 1 UPDATES, and 37 PRESERVED.
Of the rest (0 ADDITIONS) vs. 0 DELETIONS), there are 0 REAL ADDITIONS, 0 REAL DELETIONS, and 0 ID CHANGES.
Real additions:
Real deletions:
Real updates: 6110x37
Real ID changes:
No existing INFO records to compare
No existing INFO records to compare
Summary of Comparison Table Results for Category International Reply Coupons
Of the 20 imported lines, 19 were FOUND in L1 by ID, leading to 1 UPDATES, and 18 PRESERVED.
Of the rest (1 ADDITIONS) vs. 143 DELETIONS), there are 1 REAL ADDITIONS, 143 REAL DELETIONS, and 0 ID CHANGES.
Real additions: ILrc2002
Real deletions: ILrc1, ILrc2, ILrc3, ILrc4, ILrc5, ILrc6, ILrc7, ILrc8, ILrc9, ILrc9a, ILrc10, ILrc11, ILrc12, ILrc13, ILrc14, ILrc15, ILrc15a, ILrc16, ILrc17, ILrc18, ILrc20, ILrc21, ILrc22, ILrc23, ILrc24, ILrc26, ILrc27, ILrc28, ILrc29, ILrc30, ILrc31, ILrc32, ILrc33, ILrc34, ILrc36, ILrc37, ILrc38, ILrc38a, ILrc38b, ILrc38c, ILrc38d, ILrc43, ILrc44, ILrc47, ILrc48, ILrc54, ILrc55, ILrc56, ILrc59, ILrc61, ILrc62, ILrc65, ILrc66, ILrc67, ILrc68, ILrc69, ILrc70, ILrc71, ILrc72, ILrc73, ILrc74, ILrc75, ILrc76, ILrc77, ILrc79, ILrc80, ILrc81, ILrc82, ILrc83, ILrc84, ILrc85, ILrc86, ILrc87, ILrc88, ILrc89, ILrc90, ILrc91, ILrc92, ILrc93, ILrc94, ILrc95, ILrc96, ILrc97, ILrc98, ILrc99, ILrc100, ILrc101, ILrc102, ILrc103, ILrc104, ILrc105, ILrc106, ILrc107, ILrc108, ILrc109, ILrc110, ILrc111, ILrc112, ILrc113, ILrc114, ILrc115, ILrc116, ILrc117, ILrc118, ILrc119, ILrc120, ILrc121, ILrc122, ILrc123, ILrc124, ILrc125, ILrc126, ILrc127, ILrc129, ILrc130, ILrc131, ILrc132, ILrc133, ILrc134, ILrc135, ILrc136, ILrc137, ILrc138, ILrc139, ILrc140, ILrc141, ILrc142, ILrc143, ILrc144, ILrc145, ILrc146, ILrc147, ILrc148, ILrc149, ILrc150, ILrc151, ILrc152, ILrc153, ILrc154, ILrc155, ILrc156, ILrc157, ILrc2001
Real updates: ILrc2006
Real ID changes:
Summary of Comparison Table Results for Category Joint Issues
Of the 42 imported lines, 38 were FOUND in L1 by ID, leading to 2 UPDATES, and 36 PRESERVED.
Of the rest (4 ADDITIONS) vs. 53 DELETIONS), there are 4 REAL ADDITIONS, 53 REAL DELETIONS, and 0 ID CHANGES.
Real additions: 6110j1220, 6110j1228, 6110j1246, 6110j1266
Real deletions: 6110j595xFTB, 6110j595xTB, 6110j595xFJFDC, 6110j595xFSF, 6110j595xJFDC, 6110j682xJFDC, 6110j682xFS, 6110j682xFS2, 6110j682xFS3, 6110j693xJFDC, 6110j708xJFDC, 6110j752xJFDC, 6110j752xFMC, 6110j762xFSP, 6110j786xJFDC, 6110j786xFSL, 6110j786xFSF, 6110j786xFMC, 6110j786xFMC2, 6110j814xJFDC, 6110j895xJFDC, 6110j898xJFDC, 6110j898xFSL, 6110j935xFSL, 6110j935xJFDC, 6110j1038xJFDC, 6110j1038xJFDC2, 6110j1038xPJFDC, 6110j1054xFSS, 6110j1054xJFDC2, 6110j1070xJFDC, 6110j1085xFMC, 6110j1085xFJFDC, 6110j1085xFS, 6110j1085xFSF, 6110j1089xFS, 6110j1089xDP, 6110j1107xFS, 6110j1107xJFDC, 6110j1164xFSF, 6110j1179xJFDC, 6110j1179xFSS, 6110j1179xFJFDC, 6110j1185xFSP, 6110j1185xFIF, 6110j1206xFMC, 6110j1206xFMC2, 6110j1206xFSF, 6110j1206xFJSF, 6110j1206xFCE, 6110j1206xFJFDC, 6110j1206xFSHC, 6110j1206xFIF
Real updates: 6110j1164, 6110j1179
Real ID changes:
Summary of Comparison Table Results for Category Maximum Cards
Of the 34 imported lines, 31 were FOUND in L1 by ID, leading to 2 UPDATES, and 29 PRESERVED.
Of the rest (3 ADDITIONS) vs. 0 DELETIONS), there are 3 REAL ADDITIONS, 0 REAL DELETIONS, and 0 ID CHANGES.
Real additions: 6110m30ip, 6110m31ip, 6110m32ip
Real deletions:
Real updates: 6110m20, 6110m50c
Real ID changes:
Summary of Comparison Table Results for Category Ministry of Defense Covers
Of the 64 imported lines, 61 were FOUND in L1 by ID, leading to 0 UPDATES, and 61 PRESERVED.
Of the rest (3 ADDITIONS) vs. 0 DELETIONS), there are 3 REAL ADDITIONS, 0 REAL DELETIONS, and 0 ID CHANGES.
Real additions: 6110d62, 6110d63, 6110d64
Real deletions:
Real updates:
Real ID changes:
Summary of Comparison Table Results for Category New Year Greeting Cards
Of the 33 imported lines, 32 were FOUND in L1 by ID, leading to 5 UPDATES, and 27 PRESERVED.
Of the rest (1 ADDITIONS) vs. 0 DELETIONS), there are 1 REAL ADDITIONS, 0 REAL DELETIONS, and 0 ID CHANGES.
Real additions: 6110n14
Real deletions:
Real updates: 6110n88, 6110n10n, 6110n12, 6110n13, 6110n20
Real ID changes:
No existing INFO records to compare
No existing INFO records to compare
Summary of Comparison Table Results for Category Postal Bank Stamps
Of the 2 imported lines, 2 were FOUND in L1 by ID, leading to 0 UPDATES, and 2 PRESERVED.
Of the rest (0 ADDITIONS) vs. 0 DELETIONS), there are 0 REAL ADDITIONS, 0 REAL DELETIONS, and 0 ID CHANGES.
Real additions:
Real deletions:
Real updates:
Real ID changes:
Summary of Comparison Table Results for Category Postal Stationery
Of the 397 imported lines, 378 were FOUND in L1 by ID, leading to 112 UPDATES, and 266 PRESERVED.
Of the rest (19 ADDITIONS) vs. 1 DELETIONS), there are 18 REAL ADDITIONS, 0 REAL DELETIONS, and 1 ID CHANGES.
Real additions: psPC13m, psPC15m, psPC19m, psPC21m, psPC27m, psPC28m, psPC40m, psPC41m, psPC42m, psPC43m, psPC60m, psPC61m, psPC62m, psPC104m, psPC105m, psPC106m, psPC107m, psPC110m
Real deletions:
Real updates: psAL61, psAL67, psAL110, psAL111, psAL112, psAL113, psAL114, psAL115, psAL155, psAL156, psAL157, psAL158, psAL159, psAL170, psAL171, psAL172, psAL173, psAL174, psAL175, psAL176, psAL177, psAL178, psAL179, psAL180, psAL181, psAL182, psAL183, psAL184, psAL185, psAL186, psAL187, psAL188, psIE16, psIE17A, psIE17B, psIE18, psIE19, psIE21, psIE22, psIE27, psIE30, psPC3, psPC31a, psPC76, psPC77, psPC79, psPC80, psPC81, psPC82, psPC86, psPC87, psPC88, psPC89, psPC90, psPC91, psPC92, psPC93, psPC94, psPC1m, psPC2m, psPC3m, psPC4m, psPC5m, psPC6m, psPC7m, psPC8m, psPC9m, psPC10m, psPC11m, psPC12m, psPC14m, psPC16m, psPC17m, psPC20m, psPC24m, psPC26m, psPC50m, psPC51m, psPC52m, psPC53m, psPC54m, psPC55m, psPC56m, psPC57m, psPC58m, psPC59m, psPC64m, psPC65m, psPC66m, psPC67m, psPC68m, psPC69m, psPC84m, psPC85m, psPC87m, psPC88m, psPC89m, psPC90m, psPC91m, psPC93m, psPC94m, psPC95m, psPC96m, psPC97m, psPC98m, psPC99m, psPC100m, psPC101m, psPC102m, psPC103m, psPC120m, psPC121m
Real ID changes: psPC44m
Summary of Comparison Table Results for Category Revenue Stamps
Of the 22 imported lines, 21 were FOUND in L1 by ID, leading to 2 UPDATES, and 19 PRESERVED.
Of the rest (1 ADDITIONS) vs. 0 DELETIONS), there are 1 REAL ADDITIONS, 0 REAL DELETIONS, and 0 ID CHANGES.
Real additions: 6110rCT
Real deletions:
Real updates: 6110r10p, 6110r20p
Real ID changes:
Summary of Comparison Table Results for Category Souvenir Folders
Of the 83 imported lines, 83 were FOUND in L1 by ID, leading to 0 UPDATES, and 83 PRESERVED.
Of the rest (0 ADDITIONS) vs. 15 DELETIONS), there are 0 REAL ADDITIONS, 15 REAL DELETIONS, and 0 ID CHANGES.
Real additions:
Real deletions: 6110h2010, 6110h2005, 6110h2001, 6110h2002, 6110h2003, 6110h2004, 6110h2006, 6110h2007, 6110h2008, 6110h2009, 6110h2011, 6110h2012, 6110h2013, 6110h2014, 6110h2015
Real updates:
Real ID changes:
Summary of Comparison Table Results for Category Souvenir Leaves
Of the 142 imported lines, 135 were FOUND in L1 by ID, leading to 6 UPDATES, and 129 PRESERVED.
Of the rest (7 ADDITIONS) vs. 2 DELETIONS), there are 7 REAL ADDITIONS, 2 REAL DELETIONS, and 0 ID CHANGES.
Real additions: 6110lne11, 6110lne12, 6110lne13, 6110lne14, 6110lne15, 6110lne16, 6110lne17
Real deletions: 6110l474, 6110l516
Real updates: 6110l577, 6110l634, 6110lne7, 6110lne8, 6110lne9, 6110lne10
Real ID changes:
Summary of Comparison Table Results for Category Special Sheets-Sheetlets-Combination
Of the 300 imported lines, 261 were FOUND in L1 by ID, leading to 25 UPDATES, and 236 PRESERVED.
Of the rest (39 ADDITIONS) vs. 1 DELETIONS), there are 39 REAL ADDITIONS, 1 REAL DELETIONS, and 0 ID CHANGES.
Real additions: ---------, 6110e809, 6110e845B, 6110e845J, 6110e845N, 6110e845O, 6110e845P, 6110e845R, 6110e845S, 6110e845T, 6110e845U, 6110e845V, 6110e113A, 6110e191I, 6110e191J, 6110e191K, 6110e191L, 6110e191M, 6110e191N, 6110e229A, 6110e229B, 6110e235A, 6110e1240, 6110e1242, 6110e1244, 6110e1249, 6110e1253, 6110e253A, 6110e1256, 6110e1259, 6110e1261, 6110e1268, 6110e1277, 6110eBRA, 6110eHAN3, 6110ePES7, 6110ePES8, 6110ePOP3, 6110ePOP4
Real deletions: 6110e845G
Real updates: 6110e153, 6110e198, 6110e845A, 6110e845C, 6110e845D, 6110e845E, 6110e845F, 6110e845H, 6110e845I, 6110e845K, 6110e845L, 6110e845M, 6110e994, 6110e1062, 6110e1082, 6110e191A, 6110e191B, 6110e191C, 6110e191D, 6110e191E, 6110e191F, 6110e191G, 6110e191H, 6110e225A, 6110eMEJ
Real ID changes:
Summary of Comparison Table Results for Category Varieties and Variants
Of the 130 imported lines, 123 were FOUND in L1 by ID, leading to 22 UPDATES, and 101 PRESERVED.
Of the rest (7 ADDITIONS) vs. 2 DELETIONS), there are 5 REAL ADDITIONS, 0 REAL DELETIONS, and 2 ID CHANGES.
Real additions: 6110e1229, 6110e235B, 6110e1243, 6110e1252, 6110e253B
Real deletions:
Real updates: 6110e2a, 6110e2b, 6110e2c, 6110e2d, 6110e443B, 6110e443D, 6110e443G, 6110e443I, 6110e443J, 6110e443K, 6110e496A, 6110e629B, 6110e711B, 6110e742D, 6110e1056, 6110e082A, 6110e1115, 6110e148A, 6110e148C, 6110e1180, 6110e1225, 6110e225B
Real ID changes: 6110e845B, 6110e845J
Summary of Comparison Table Results for Category Vending Machine Labels
Of the 226 imported lines, 211 were FOUND in L1 by ID, leading to 3 UPDATES, and 208 PRESERVED.
Of the rest (15 ADDITIONS) vs. 285 DELETIONS), there are 15 REAL ADDITIONS, 285 REAL DELETIONS, and 0 ID CHANGES.
Real additions: 6110k91-3, 6110k1405, 6110k1406, 6110k1407, 6110k1408, 6110k1409, 6110k1410, 6110k1411, 6110k1412, 6110k1413, 6110k1414, 6110k1501, 6110k1502, 6110k1503, 6110k1504
Real deletions: 6110k0401bl, 6110k0401m002, 6110k0401m003, 6110k0401m004, 6110k0401m005, 6110k0401m006, 6110k0401m007, 6110k0401m008, 6110k0401m009, 6110k0401m010, 6110k0401m011, 6110k0401m012, 6110k0401m013, 6110k0401m015, 6110k0403bl, 6110k0403m014, 6110k0407bl, 6110k0407m015, 6110k0501bl, 6110k0501m005, 6110k0503bl, 6110k0503m004, 6110k0503m006, 6110k0503m008, 6110k0503m009, 6110k0503m010, 6110k0503m012, 6110k0505bl, 6110k0505m015, 6110k0601bl, 6110k0601m002, 6110k0601m004, 6110k0601m005, 6110k0601m006, 6110k0601m008, 6110k0601m009, 6110k0601m010, 6110k0601m011, 6110k0601m012, 6110k0601m013, 6110k0601m015, 6110k0601m016, 6110k0605bl, 6110k0605m017, 6110k0610bl, 6110k0610m011, 6110k0612bl, 6110k0612m010, 6110k0612m015, 6110k0701bl, 6110k0701m004, 6110k0701m006, 6110k0701m008, 6110k0701m009, 6110k0701m010, 6110k0701m012, 6110k0701m013, 6110k0701m015, 6110k0703bl, 6110k0703m018, 6110k0705bl, 6110k0701RC1m001, 6110k0701RC1m004, 6110k0701RC1m006, 6110k0701RC1m008, 6110k0701RC1m009, 6110k0701RC1m010, 6110k0701RC1m012, 6110k0701RC1m013, 6110k0701RC1m015, 6110k0610RC1m001, 6110k0610RC1m011, 6110k0705RC1m001, 6110k0705RC1m013, 6110k0703RC1m001, 6110k0703RC1m018, 6110k0709bl, 6110k0709m010, 6110k0709m015, 6110k0801bl, 6110k0801m060, 6110k0804RC1Bm004, 6110k0804RC1Bm006, 6110k0804RC1Bm008, 6110k0804RC1Bm009, 6110k0804RC1Bm010, 6110k0804RC1Bm012, 6110k0804RC1Bm013, 6110k0804RC1Bm015, 6110k0803RC1Bm011, 6110k0806RC1Bm013, 6110k0805RC1Bm018, 6110k0701RC2m001, 6110k0701RC2m004, 6110k0701RC2m006, 6110k0701RC2m008, 6110k0701RC2m009, 6110k0701RC2m010, 6110k0701RC2m012, 6110k0701RC2m013, 6110k0701RC2m015, 6110k0803RC2m001, 6110k0803RC2m011, 6110k0806RC2m001, 6110k0806RC2m013, 6110k0805RC2m001, 6110k0805RC2m018, 6110k0401RCm004, 6110k0601RCm012, 6110k0810bl, 6110k0810m010, 6110k0810m015, 6110k0901bl, 6110k0901m004, 6110k0901m006, 6110k0901m008, 6110k0901m010, 6110k0901m011, 6110k0901m012, 6110k0901m013, 6110k0901m015, 6110k0901m018, 6110k0903bl, 6110k0903m006, 6110k0907bl, 6110k0907m010, 6110k0909bl, 6110k0909m010, 6110k0909m015, 6110k0911bl, 6110k0911m012, 6110k0901RCm001, 6110k0901RCm004, 6110k0901RCm008, 6110k0901RCm011, 6110k0901RCm013, 6110k0901RCm015, 6110k0901RCm018, 6110k0903RCm001, 6110k0903RCm006, 6110k0907RCm001, 6110k0907RCm010, 6110k0909RCm001, 6110k0909RCm012, 6110k0913bl, 6110k0913m004, 6110k0915bl, 6110k0915m010, 6110k0915m015, 6110k1001bl, 6110k1001m004, 6110k1001m006, 6110k1001m008, 6110k1001m010, 6110k1001m011, 6110k1001m012, 6110k1001m013, 6110k1001m015, 6110k1001m018, 6110k1003bl, 6110k1003m008, 6110k1005bl, 6110k1005m013, 6110k1007bl, 6110k1007m018, 6110k1001RCm001, 6110k1001RCm004, 6110k1001RCm006, 6110k1001RCm010, 6110k1001RCm011, 6110k1001RCm012, 6110k1001RCm015, 6110k1003RCm001, 6110k1003RCm008, 6110k1005RCm001, 6110k1005RCm013, 6110k1007RCm001, 6110k1007RCm018, 6110k1011bl, 6110k1011m011, 6110k1013bl, 6110k1013m010, 6110k1013m015, 6110k1013m062, 6110k1015bl, 6110k1015m061, 6110k1101bl, 6110k1101m004, 6110k1101m006, 6110k1101m008, 6110k1101m010, 6110k1101m011, 6110k1101m012, 6110k1101m013, 6110k1101m015, 6110k1101m018, 6110k1103bl, 6110k1103m006, 6110k1105bl, 6110k1105m004, 6110k1107bl, 6110k1107m013, 6110k1101RCm001, 6110k1101RCm004, 6110k1101RCm006, 6110k1101RCm008, 6110k1101RCm010, 6110k1101RCm011, 6110k1101RCm012, 6110k1101RCm013, 6110k1101RCm015, 6110k1101RCm018, 6110k1103RCm001, 6110k1103RCm006, 6110k1105RCm001, 6110k1105RCm004, 6110k1107RCm001, 6110k1107RCm013, 6110k1109bl, 6110k1109m006, 6110k1113bl, 6110k1113m012, 6110k1115bl, 6110k1115m010, 6110k1115m015, 6110k1201bl, 6110k1201m004, 6110k1201m006, 6110k1201m008, 6110k1201m010, 6110k1201m011, 6110k1201m012, 6110k1201m013, 6110k1201m015, 6110k1201m018, 6110k1203bl, 6110k1203m013, 6110k1201RCm001, 6110k1201RCm004, 6110k1201RCm006, 6110k1201RCm008, 6110k1201RCm010, 6110k1201RCm011, 6110k1201RCm012, 6110k1201RCm013, 6110k1201RCm015, 6110k1201RCm018, 6110k1203RCm001, 6110k1203RCm013, 6110k1205bl, 6110k1205m006, 6110k1207bl, 6110k1207m008, 6110k1201RC2m001, 6110k1201RC2m004, 6110k1201RC2m010, 6110k1201RC2m011, 6110k1201RC2m012, 6110k1201RC2m015, 6110k1201RC2m018, 6110k1203RC2m001, 6110k1203RC2m013, 6110k1205RCm001, 6110k1205RCm006, 6110k1207RCm001, 6110k1207RCm008, 6110k1209bl, 6110k1209m006, 6110k1209m018, 6110k1211bl, 6110k1211m010, 6110k1211m015, 6110k1301bl, 6110k1301m004, 6110k1301m006, 6110k1301m008, 6110k1301m010, 6110k1301m011, 6110k1301m012, 6110k1301m015, 6110k1301m018, 6110k1303bl, 6110k1303m012, 6110k1305bl, 6110k1305m004
Real updates: 6110k9003, 6110k9103, 6110k1113
Real ID changes:
Summary of Comparison Table Results for Category Year Sets
Of the 74 imported lines, 72 were FOUND in L1 by ID, leading to 14 UPDATES, and 58 PRESERVED.
Of the rest (2 ADDITIONS) vs. 0 DELETIONS), there are 2 REAL ADDITIONS, 0 REAL DELETIONS, and 0 ID CHANGES.
Real additions: 6110y13, 6110y14
Real deletions:
Real updates: 6110y57, 6110y81, 6110y83, 6110y84, 6110y86, 6110y87, 6110y88, 6110y93, 6110y94, 6110y95, 6110y96, 6110y11, 6110y12, 6110y4899
Real ID changes:
Summary of Comparison Table Results for Category (X)Austria Judaica Tabs
Of the 68 imported lines, 68 were FOUND in L1 by ID, leading to 68 UPDATES, and 0 PRESERVED.
Of the rest (0 ADDITIONS) vs. 0 DELETIONS), there are 0 REAL ADDITIONS, 0 REAL DELETIONS, and 0 ID CHANGES.
Real additions:
Real deletions:
Real updates: AUI001, AUI002, AUI002.1, AUI003, AUI003.1, AUI004, AUI004.1, AUI004.2, AUI004.3, AUI005, AUI006, AUI007, AUI007.1, AUI008, AUI009, AUI010, AUI011, AUI012, AUI013, AUI014, AUI015, AUI016, AUI017, AUI017.1, AUI018, AUI019, AUI020, AUI021, AUI021.1, AUI021.2, AUI022, AUI023, AUI024, AUI024.1, AUI024.2, AUI025, AUI026, AUI026.1, AUI027, AUI027.1, AUI028, AUI029, AUI030, AUI031, AUI031.1, AUI032, AUI033, AUI034, AUI035, AUI036, AUI037, AUI038, AUI039, AUI040, AUI041, AUI042, AUI043, AUI044, AUI045, AUI046, AUI047, AUI048, AUI049, AUI050, AUI051, AUI052, AUI053, AUI054
Real ID changes:
Summary of Comparison Table Results
Of the 2888 imported lines, 2750 were FOUND in L1 by ID, leading to 359 UPDATES, and 2391 PRESERVED.
Of the rest (138 ADDITIONS) vs. 502 DELETIONS), there are 135 REAL ADDITIONS, 499 REAL DELETIONS, and 3 ID CHANGES.
*/
