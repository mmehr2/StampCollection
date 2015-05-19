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
func processComparison(category: Int16, mode: Int, oldRecs: [DealerItem]) {
    if oldRecs.count == 0 {
        println("No CoreData records to compare in category \(category)")
        return
    }
    var okToWrite = mode > 0
    var okToDelete = mode == 3
    // get the corresponding category and item data from the live BT website (assumed to be done loading)
    let webtcatnum = BTCategory.translateNumberFromInfoCategory(category)
    let webtcat = BTDealerStore.model.getCategoryByNumber(webtcatnum)!
    let newRecs: [BTDealerItem] = webtcat.dataItems
    if newRecs.count == 0 {
        println("No Website records to compare in category \(category) = website category \(webtcatnum)")
        return
    }
    // comparison loop
    println("Comparing \(oldRecs.count) CoreData records with \(newRecs.count) website records.")
    var added : [String:Int] = [:]
    var updated : [String:(Int, CompRecord)] = [:]
    var deleted : [String:Int] = [:]
    var found : [String:Int] = [:]
    var samecount = 0
    for (irow, input) in enumerate(newRecs) {
        // for each candidate item from the live website, convert it to dictionary form, and get the ID code
        let irecord = input.createInfoItem(webtcat)
        let id = irecord["id"]!
        // TBD: also need to convert the cat1 and cat2 catalog fields in category 2 (Sets,...) to fix data issues with the input
        // (LEGACY PHP CODE DETECTED THIS - ARTIFACT OF CONVERSION PROCESS OR OUTRIGHT TYPOS IN BT DATA!)
        // check if ID is present in existing supplied CoreData records
        var (orow, idf): (Int, String) = (-1, "")
        for (rownum, rec) in enumerate(oldRecs) {
            if rec.id == id {
                (orow, idf) = (rownum, id)
                break
            }
        }
        let foundID = !idf.isEmpty
        if !foundID {
            // NO: must be added (we think)
            added[id] = irow
        } else {
            // YES: we have an ID match, send it to the updates table and run the comparison
            // must be an update
            // mark it as found (unfound items at end of scan are deletions)
            found[id] = irow;
            // compare record to existing record, and if not the same, put it in updates array
            let orecord = oldRecs[orow].makeDataFromObject()
            let comprec = compareInfoRecords(orecord, irecord)
            if (!isEqualCR(comprec, false)) {
                updated[id] = (irow, comprec) // save both irow# and comparisons array
            } else {
                ++samecount
            }
        }
    }
    // scan for deletions
    for (orowX, recX) in enumerate(oldRecs) //foreach ($index as $id => $orow)
    {
        // check all existing CoreData records
        let idf = recX.id
        // if the ID is not in the found set, it must be a deletion
        if found[idf] == nil {
            deleted[idf] = orowX // remember row number of deleted row in index
        }
    }
    // now find deletions and additions that share the same description and treat them as updates with identity change
    var realadditions : [String:Int] = [:]
    var realdeletions : [String:Int] = [:]
    var adddelupdates : [String:(String, Int, String, String, Int, String, CompRecord)] = [:]
    var adddelupdatesbyd : [String:(String, Int, String, String, Int, String, CompRecord)] = [:]
    for (id, irow) in added //foreach ($added as $id => $irow)
    {
        let record = newRecs[irow].createInfoItem(webtcat) //$input[$irow];
        let idesc = record["description"]!
        var matched = false
        for (idd, drow) in deleted //foreach ($deleted as $idd => $drow)
        {
            let drecord = oldRecs[drow].makeDataFromObject()
            let ddesc = drecord["description"]!
            if (ddesc == idesc)
            {
                let comprec = compareInfoRecords(drecord, record)
                // save matching corresponding info (idd, drow, id, irow) - index by idd(old) and id(new)
                let x = (idd, drow, ddesc, id, irow, idesc, comprec)
                adddelupdates[id] = x
                adddelupdatesbyd[idd] = x
                matched = true
                break
            }
        }
        if matched
        {
            // this is an entry for update between the DB record in deleted and the addition row info (new)
            // array addition has already been made
            //            $idd = $adddelupdates[$id]['idd'];
            //            $drow = $adddelupdates[$id]['drow'];
            //            $ddesc = $adddelupdates[$id]['ddesc'];
            // later            $message .=  "<h4>Matched add/del ID-change record $irow(ID=$id): $idesc<br />";
            // later            $message .=  " Corresponds to $drow(ID=$idd): $ddesc<br/></h4>";
        }
        else
        {
            // this is really an addition, that should go to the real additions table
            realadditions[id] = irow
            // later           $message .=  "<h4>Added input record $irow(ID=$id): $idesc<br /></h4>";
        }
    }
    // scan for the real deletions (not found in adddelupdates)
    for (idd, drow) in deleted //foreach ($deleted as $idd => $drow)
    {
        if adddelupdatesbyd[idd] == nil //(!array_key_exists($idd, $adddelupdatesbyd))
        {
            realdeletions[idd] = drow
        }
    }
    // time to summarize what we've done!
    let incount = newRecs.count //$incount = count($input);
    let oldcount = oldRecs.count
    if incount < oldcount {
        println("More deletions than insertions.")
    } else if incount > oldcount {
        println("More insertions than deletions.")
    } else if incount == oldcount {
        println("Same number of deletions and insertions.")
    }
    let addcount = count(added)
    let foundcount = count(found)
    let deletedcount = count(deleted)
    let updatedcount = count(updated)
    let addcount2 = count(realadditions)
    let updatedcount2 = count(adddelupdates)
    let deletedcount2 = count(realdeletions)
    println("Of the \(incount) imported lines, \(foundcount) were FOUND in L1 by ID, leading to \(updatedcount) UPDATES, and \(samecount) PRESERVED.")
    println("Of the rest (\(addcount) ADDITIONS) vs. \(deletedcount) DELETIONS), there are \(addcount2) REAL ADDITIONS, \(deletedcount2) REAL DELETIONS, and \(updatedcount2) ID CHANGES.")
    // TBD: function is now half translated; the code then proceeds to actually make the changes to the data, which we REALLY need to translate into CoreData terms
    println("MORE TO COME ...")
}

/*
TEST OUTPUT 5/19/15 - FIRST VERSION
// NOTE how nothing is preserved. Comparing apples with oranges maybe? Check fieldnames match for comparison function.
Showing Sets, SS, FDC (#2) Info Items
Comparing 1041 CoreData records with 1072 website records.
More insertions than deletions.
Of the 1072 imported lines, 1041 were FOUND in L1 by ID, leading to 1041 UPDATES, and 0 PRESERVED.
Of the rest (31 ADDITIONS) vs. 0 DELETIONS), there are 31 REAL ADDITIONS, 0 REAL DELETIONS, and 0 ID CHANGES.
MORE TO COME ...
Showing Booklets (#3) Info Items
Comparing 136 CoreData records with 141 website records.
More insertions than deletions.
Of the 141 imported lines, 136 were FOUND in L1 by ID, leading to 136 UPDATES, and 0 PRESERVED.
Of the rest (5 ADDITIONS) vs. 0 DELETIONS), there are 5 REAL ADDITIONS, 0 REAL DELETIONS, and 0 ID CHANGES.
MORE TO COME ...
Showing International Reply Coupons (#12) Info Items
Comparing 162 CoreData records with 20 website records.
More deletions than insertions.
Of the 20 imported lines, 19 were FOUND in L1 by ID, leading to 19 UPDATES, and 0 PRESERVED.
Of the rest (1 ADDITIONS) vs. 143 DELETIONS), there are 1 REAL ADDITIONS, 143 REAL DELETIONS, and 0 ID CHANGES.
MORE TO COME ...
Showing Joint Issues (#13) Info Items
Comparing 91 CoreData records with 42 website records.
More deletions than insertions.
Of the 42 imported lines, 38 were FOUND in L1 by ID, leading to 38 UPDATES, and 0 PRESERVED.
Of the rest (4 ADDITIONS) vs. 53 DELETIONS), there are 4 REAL ADDITIONS, 53 REAL DELETIONS, and 0 ID CHANGES.
MORE TO COME ...
Showing Maximum Cards (#14) Info Items
Comparing 31 CoreData records with 34 website records.
More insertions than deletions.
Of the 34 imported lines, 31 were FOUND in L1 by ID, leading to 31 UPDATES, and 0 PRESERVED.
Of the rest (3 ADDITIONS) vs. 0 DELETIONS), there are 3 REAL ADDITIONS, 0 REAL DELETIONS, and 0 ID CHANGES.
MORE TO COME ...
Showing Ministry of Defense Covers (#15) Info Items
Comparing 61 CoreData records with 64 website records.
More insertions than deletions.
Of the 64 imported lines, 61 were FOUND in L1 by ID, leading to 61 UPDATES, and 0 PRESERVED.
Of the rest (3 ADDITIONS) vs. 0 DELETIONS), there are 3 REAL ADDITIONS, 0 REAL DELETIONS, and 0 ID CHANGES.
MORE TO COME ...
Showing New Year Greeting Cards (#16) Info Items
Comparing 32 CoreData records with 33 website records.
More insertions than deletions.
Of the 33 imported lines, 32 were FOUND in L1 by ID, leading to 32 UPDATES, and 0 PRESERVED.
Of the rest (1 ADDITIONS) vs. 0 DELETIONS), there are 1 REAL ADDITIONS, 0 REAL DELETIONS, and 0 ID CHANGES.
MORE TO COME ...
Showing Postal Bank Stamps (#19) Info Items
Comparing 2 CoreData records with 2 website records.
Same number of deletions and insertions.
Of the 2 imported lines, 2 were FOUND in L1 by ID, leading to 2 UPDATES, and 0 PRESERVED.
Of the rest (0 ADDITIONS) vs. 0 DELETIONS), there are 0 REAL ADDITIONS, 0 REAL DELETIONS, and 0 ID CHANGES.
MORE TO COME ...
Showing Postal Stationery (#20) Info Items
Comparing 379 CoreData records with 397 website records.
More insertions than deletions.
Of the 397 imported lines, 378 were FOUND in L1 by ID, leading to 378 UPDATES, and 0 PRESERVED.
Of the rest (19 ADDITIONS) vs. 1 DELETIONS), there are 18 REAL ADDITIONS, 0 REAL DELETIONS, and 1 ID CHANGES.
MORE TO COME ...
Showing Revenue Stamps (#21) Info Items
Comparing 21 CoreData records with 22 website records.
More insertions than deletions.
Of the 22 imported lines, 21 were FOUND in L1 by ID, leading to 21 UPDATES, and 0 PRESERVED.
Of the rest (1 ADDITIONS) vs. 0 DELETIONS), there are 1 REAL ADDITIONS, 0 REAL DELETIONS, and 0 ID CHANGES.
MORE TO COME ...
Showing Souvenir Folders (#22) Info Items
Comparing 98 CoreData records with 83 website records.
More deletions than insertions.
Of the 83 imported lines, 83 were FOUND in L1 by ID, leading to 83 UPDATES, and 0 PRESERVED.
Of the rest (0 ADDITIONS) vs. 15 DELETIONS), there are 0 REAL ADDITIONS, 15 REAL DELETIONS, and 0 ID CHANGES.
MORE TO COME ...
Showing Souvenir Leaves (#23) Info Items
Comparing 137 CoreData records with 142 website records.
More insertions than deletions.
Of the 142 imported lines, 135 were FOUND in L1 by ID, leading to 135 UPDATES, and 0 PRESERVED.
Of the rest (7 ADDITIONS) vs. 2 DELETIONS), there are 7 REAL ADDITIONS, 2 REAL DELETIONS, and 0 ID CHANGES.
MORE TO COME ...
Showing Special Sheets-Sheetlets-Combination (#24) Info Items
Comparing 262 CoreData records with 300 website records.
More insertions than deletions.
Of the 300 imported lines, 261 were FOUND in L1 by ID, leading to 261 UPDATES, and 0 PRESERVED.
Of the rest (39 ADDITIONS) vs. 1 DELETIONS), there are 39 REAL ADDITIONS, 1 REAL DELETIONS, and 0 ID CHANGES.
MORE TO COME ...
Showing Varieties and Variants (#25) Info Items
Comparing 125 CoreData records with 130 website records.
More insertions than deletions.
Of the 130 imported lines, 123 were FOUND in L1 by ID, leading to 123 UPDATES, and 0 PRESERVED.
Of the rest (7 ADDITIONS) vs. 2 DELETIONS), there are 5 REAL ADDITIONS, 0 REAL DELETIONS, and 2 ID CHANGES.
MORE TO COME ...
Showing Vending Machine Labels (#26) Info Items
Comparing 496 CoreData records with 226 website records.
More deletions than insertions.
Of the 226 imported lines, 211 were FOUND in L1 by ID, leading to 211 UPDATES, and 0 PRESERVED.
Of the rest (15 ADDITIONS) vs. 285 DELETIONS), there are 15 REAL ADDITIONS, 285 REAL DELETIONS, and 0 ID CHANGES.
MORE TO COME ...
Showing Year Sets (#27) Info Items
Comparing 72 CoreData records with 74 website records.
More insertions than deletions.
Of the 74 imported lines, 72 were FOUND in L1 by ID, leading to 72 UPDATES, and 0 PRESERVED.
Of the rest (2 ADDITIONS) vs. 0 DELETIONS), there are 2 REAL ADDITIONS, 0 REAL DELETIONS, and 0 ID CHANGES.
MORE TO COME ...
Showing (X)Austria Judaica Tabs (#28) Info Items
Comparing 68 CoreData records with 68 website records.
Same number of deletions and insertions.
Of the 68 imported lines, 68 were FOUND in L1 by ID, leading to 68 UPDATES, and 0 PRESERVED.
Of the rest (0 ADDITIONS) vs. 0 DELETIONS), there are 0 REAL ADDITIONS, 0 REAL DELETIONS, and 0 ID CHANGES.
MORE TO COME ...

*/
