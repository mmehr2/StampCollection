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

typealias CompRecord = [String:CompareStatus]

private func compareWithTC( lhs: String, rhs: String ) -> Bool {
    var output = false
    // we know the strings are unequal here, but PHP would try to convert them to numbers, so let's try that
    // use double conversion if either string contains a '.', else integers
    let hasPdA = lhs.contains(".")
    let hasPdB = rhs.contains(".")
    if hasPdA || hasPdB {
        if let dblA = lhs.toDouble(), dblB = rhs.toDouble() {
            if dblA == dblB {
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
func compareInfoRecords( oldRec: [String:String], newRec: [String:String] ) -> CompRecord {
    var output : CompRecord = [:]
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

func getCRReport(oldRec: [String:String], newRec: [String:String], comprec: CompRecord) -> String {
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
    case SameItem // new item matched an existing item entirely
    case ChangedItem // new item matched an existing item ID with different data
    case ChangedItemID(String) // new item matched an existing item's essential data but with different ID (includes existing ID)
    case AddedItem // new item does not match an existing item
    case RemovedItem // an existing item which did not get a match from any new item
}

typealias UpdateComparisonTable = [String:UpdateComparisonResult]

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
func processComparison(oldRecs: [DealerItem]) -> UpdateComparisonTable {
    var output = UpdateComparisonTable()
    if oldRecs.count == 0 {
        println("No existing INFO records to compare")
        return output
    }
    // get the category number from the first item (assume that all are the same for efficiency)
    let category = oldRecs.first!.catgDisplayNum
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
    let foundIDs = newIDs.intersect(oldIDs) // common IDs
    // we need to classify the found items into same or different; count the same set, compare the different one for updates
    // to do this we need to run the comparison on the object's dictionary forms
    // NOTE: this loop is the largest for most normal situations (updating existing database)
    var samecount = 0
    var updatedIDs = Set<String>()
    for id in foundIDs {
        // get the new and old objects referred by this ID
        let oldObj = oldIndex[id]!
        let newObj = newIndex[id]!
        // run the comparison, and see if it's equal or not
        let oldData = oldObj.makeDataFromObject()
        let newData = newObj.createInfoItem(webtcat)
        let comprec = compareInfoRecords(oldData, newData)
        let compResult = isEqualCR(comprec, false)
        // if equal, just bump the equality counter
        if compResult {
            ++samecount
        }
        // else we should save the ID in the updated set
        else {
            updatedIDs.insert(id)
        }
    }
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
    // if either of these sets (added, deleted) is empty, the other is all "real"
    if addedIDs.isEmpty {
        realdeletedIDs = deletedIDs
//    } else if deletedIDs.isEmpty {
//        realaddedIDs = addedIDs
    } else {
        // we need to identify added objects that have a common description with an existing/old object
        // the code above checks each added object and scans the deletion descriptions until the first match is found
        // if so, the ID is in the set of updates; if no descriptions match, the ID is considered a real addition
        for addID in addedIDs {
            let addObj = newIndex[addID]!
            var matched = false
            // for each added object, find if any deleted object has the same description and/or other fields in common
            for delID in deletedIDs {
                ++opcounter // double check the size of the set; should be half of count(addedIDs) * count(deletedIDs)
               // get the two objects represented by the two IDs
                let delObj = oldIndex[delID]!
                // analyze their similarities:
                // current rule: descriptions must be equal
                // TBD: could also look at catalog fields (2), pic ID codes, or combinations)
                let compResult = delObj.descriptionX == addObj.descr
                // if this comparison passes, it's an ID change with possible other updates: add to the realchangedX dictionaries
                if compResult {
                    realchangedIDsByNew[addID] = delID
                    realchangedIDsByOld[delID] = addID
                    matched = true
                    break
                }
            }
            if !matched {
                // if it fails the whole loop, add the the new ID to the realadded set
                realaddedIDs.insert(addID)
            }
        }
        // once this process is over, any deletions that haven't been matched as updates are really "deletions"
        // we may only choose to mark them in the DB rather than actually delete, depending on if any inventory uses the item
        let delsWhichWereUpdates = Set(realchangedIDsByOld.keys)
        realdeletedIDs = deletedIDs.subtract(delsWhichWereUpdates)
    }
    // create the output table
    let realIDChangesByNew = Set(realchangedIDsByNew.keys)
    for id in newIDs {
        // new IDs could be Added, Removed, Changed (2 types), or same; only existing IDs can be deleted
        if realaddedIDs.contains(id) { output[id] = .AddedItem }
        //else if realdeletedIDs.contains(id) { output[id] = .RemovedItem } // see below
        else if updatedIDs.contains(id) { output[id] = .ChangedItem }
        else if realIDChangesByNew.contains(id) { output[id] = .ChangedItemID(realchangedIDsByNew[id]!) }
        else { output[id] = .SameItem }
    }
    // add the deletions to the list
    for id in realdeletedIDs {
        output[id] = .RemovedItem
    }
    printSummaryStats(output)
    return output
}

func printSummaryStats(table: UpdateComparisonTable) {
    var incount = 0
    var samecount = 0
    var addcount = 0
    var foundcount = 0
    var deletedcount = 0
    var updatedcount = 0
    var addcount2 = 0
    var updatedcount2 = 0
    var deletedcount2 = 0
    for (id, result) in table {
        ++incount
        switch result {
        case .SameItem:
            ++foundcount
            ++samecount
        case .ChangedItem:
            ++foundcount
            ++updatedcount
        case .ChangedItemID:
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
    println("Summary of Comparison Table Results")
    println("Of the \(incount) imported lines, \(foundcount) were FOUND in L1 by ID, leading to \(updatedcount) UPDATES, and \(samecount) PRESERVED.")
    println("Of the rest (\(addcount) ADDITIONS) vs. \(deletedcount) DELETIONS), there are \(addcount2) REAL ADDITIONS, \(deletedcount2) REAL DELETIONS, and \(updatedcount2) ID CHANGES.")
}