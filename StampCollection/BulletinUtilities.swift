//
//  BulletinUtilities.swift
//  StampCollection
//
//  Created by Michael L Mehr on 7/8/17.
//  Copyright © 2017 Michael L. Mehr. All rights reserved.
//

import Foundation

let CATEG_BULLETINS:Int16 = 30

// U4, Utility to add a pictfile ref to blanks in INFO items in the bulletins category (30)
// NOTE: as of running this July 10, 2017, the following bulletins after 150 were NOT scanned by the BT site folks:
///  131,301-8,321-34,348,355,355a,366,368a,373,384,392a,404,406-8,411a,417-20,433a,428,445,448-50,458-9,463-478,480-501
///  Listings don't exist in Morgenstein for: 391,495
class U4Task: NSObject, UtilityTaskRunnable {
    
    var task: UtilityTask! {
        didSet(old) {
            // set up the proxy once we know the object's reference
            task.reportedTaskUnits = TU
            task.isEnabled = isEnabled
            task.taskName = taskName
            // protocol: set initial taskUnits to non-0 if we have work, 0 if we don't (database category empty)
            task.taskUnits = !isEnabled ? 0 : task.countCategories([CATEG_BULLETINS]) > 0 ? 1 : 0
        }
    }
    
    // protocol: UtilityTaskRunnable
    let TU: Int64 = 2000 // generate this as approx msec execution time on my device; only relative size matters
    var isEnabled: Bool { return false }
    var taskName: String { return "UT2017_07_09_BULLETINS_ADD_PICREFS" }

    var shouldOverwrite = true // set to true to make it overwrite existing pictid fields (we know better now)
    static let substitutions = [
        //"":"", // place holder: will be filled in by U6 task
        "bu001":"bulN1",
        "bu002":"bulN2",
        "bu003":"bul5e",
        "bu003a":"bulN2",
        "bu004":"bulN2",
        "bu005":"bulN5",
        "bu006":"bulN5",
        "bu009":"bul9e",
        "bu021":"bul21e",
        "bu023":"bul23e",
        "bu040":"bul40e",
        "bu044":"bul44e",
        "bu047":"bul47e",
        "bu049":"bul49e",
        "bu051":"bul51e",
        "bu052":"bul52e",
        "bu050":"bul50e",
        "bu063":"bul63e",
        "bu067":"bul67e",
        "bu069":"bul69e",
        "bu072":"bul72e",
        "bu074":"bul74e",
        "bu075":"bul75e",
        "bu081":"bul81e",
        "bu084":"bul84e",
        "bu085":"bul85e",
        "bu146":"bul146e",
        "bu112":"bul112e",
        "bu135":"bul135e",
        "bu134":"bul134e",
        "bu136":"bul136e",
        "bu137":"bul137e",
        "bu138":"bul138e",
        "bu139":"bul139e",
        "bu141":"bul141e",
        "bu140":"bul140e",
        "bu145":"bul145e",
        "bu143":"bul143e",
        "bu142":"bul142e",
        "bu147":"bul147e",
        "bu148":"bul148e",
        "bu149":"bul149e",
        "bu150":"bul150e",
        "bu240A":"bul240",
        "bu307A":"bul307",
        "bu378A":"bul378",
        "bu421A":"bul421"
    ]
    
    func run() -> String {
        var result = ""
        if true {
            let objects = task.model.fetchInfoInCategory(CATEG_BULLETINS, withSearching: [], andSorting: .none, fromContext: task.contextToken)
            let objects2: [DealerItem]
            if !shouldOverwrite {
                // look for only fields with empty pictid (original situation)
                objects2 = objects.filter() { x in
                    return x.pictid! == ""
                }
            } else {
                // modify all items
                objects2 = objects
            }
            let objects3 = objects2.map{fixTheEmptyPictfile($0)}.map{$0.pictid!}
            let objects4 = objects3.joined(separator: " ")
            task.updateTask(step: 1, of: 1)
            if objects3.count > 0 {
                result = "Found \(objects3.count) info bulletin objects with empty pictfile refs out of total \(objects.count) objects."
                print("\(result)\n\(objects4)")
            }
        }
        return result
    }
    
    private func fixTheEmptyPictfile(_ item: DealerItem) -> DealerItem {
        var nameToUse = U4Task.getThePictidFixup(item.id!)
        if let subbedName = U4Task.substitutions[nameToUse] {
            nameToUse = subbedName
        } else {
            print ("Skipping update for bulletin \(nameToUse)")
        }
        item.pictid = nameToUse
        return item
    }
    
    static func getThePictidFixup(_ x: String) -> String {
        // special case: info bulletin category: BT now has pics up under the name "bulNNN.jpg" for bulletin NNN, same place as regular pics
        // the pictid is like "bu234" or "bu001", the name should be "bul234" or "bul1" (yes lower-case L AND 1 :)
        var nameToUse = x
        var finalSuffix = ""
        if getCharacterClass(nameToUse.last!) != .numeric {
            finalSuffix = String(nameToUse.last!)
            nameToUse = String(nameToUse.dropLast())
        }
        let (_, numS) = splitNumericEndOfString(nameToUse)
        if let num = Int(numS) {
            nameToUse = "bul\(num)\(finalSuffix)"
        }
        return nameToUse
    }
}

// U5, Utility to remove duplicate dates YYYY YYYY at start of InfoBulletin descriptionX fields (code buXXXX in category 30)
class U5Task: NSObject, UtilityTaskRunnable {
    
    var task: UtilityTask! {
        didSet(old) {
            // set up the proxy once we know the object's reference
            task.reportedTaskUnits = TU
            task.isEnabled = isEnabled
            task.taskName = taskName
            // protocol: set initial taskUnits to non-0 if we have work, 0 if we don't (database category empty)
            task.taskUnits = !isEnabled ? 0 : task.countCategories([CATEG_BULLETINS]) > 0 ? 1 : 0
        }
    }
    
    // protocol: UtilityTaskRunnable
    let TU: Int64 =  1000 // generate this as approx msec execution time on my device; only relative size matters
    var isEnabled: Bool { return false }
    var taskName: String { return "UT2017_07_09_BULLETINS_W_DUPLICATE_YEARS" }
    
    func run() -> String {
        var result = ""
        if true {
            let objects = task.model.fetchInfoInCategory(CATEG_BULLETINS, withSearching: [], andSorting: .none, fromContext: task.contextToken)
            let objects2 = objects.filter() { x in
                return filterDuplicateDatePrefix(x.descriptionX!)
            }
            let objects3 = objects2.map{fixTheDuplicatePrefix($0)}.map{$0.descriptionX!}
            let objects4 = objects3.joined(separator: "\n")
            task.updateTask(step: 1, of: 1)
            if objects3.count > 0 {
                result = "Found \(objects3.count) info bulletin objects with duplicate dates out of total \(objects.count) objects."
                print("\(result)\n\(objects4)")
            }
        }
        return result
    }
    
    private func filterDuplicateDatePrefix(_ test: String) -> Bool {
        var result = false
        guard test.count >= 9 else { return result }
        guard let c1 = test.first, getCharacterClass(c1) == .numeric else { return result }
        let splitPt1 = test.index(test.startIndex, offsetBy: 4)
        let splitPt2 = test.index(splitPt1, offsetBy: 1)
        let splitPt3 = test.index(splitPt2, offsetBy: 4)
        let firstFour = test[..<splitPt1]
        let nextFour = test[splitPt2..<splitPt3]
        if firstFour == nextFour {
            result = true
        }
        return result
    }
    
    private func fixTheDuplicatePrefix(_ x: DealerItem) -> DealerItem {
        let item = x
        item.descriptionX = String(x.descriptionX.dropFirst(5))
        return item
        
    }
}

// U6, Utility to scan the bulletins cat.30 to detect diffs between ID and PICTID and write a code table that can be used to modify task U4 so that it will still work if run again
class U6Task: NSObject, UtilityTaskRunnable {
    
    var task: UtilityTask! {
        didSet(old) {
            // set up the proxy once we know the object's reference
            task.reportedTaskUnits = TU
            task.isEnabled = isEnabled
            task.taskName = taskName
            // protocol: set initial taskUnits to non-0 if we have work, 0 if we don't (database category empty)
            task.taskUnits = !isEnabled ? 0 : task.countCategories([CATEG_BULLETINS]) > 0 ? 1 : 0
        }
    }
    
    // protocol: UtilityTaskRunnable
    let TU: Int64 =  1000 // generate this as approx msec execution time on my device; only relative size matters
    var isEnabled: Bool { return false }
    var taskName: String { return "UT2017_07_10_BULLETINS_REGEN_U4_SOURCE_PICTID_DIFFTABLE" }
    
    func run() -> String {
        var result = ""
        if true {
            let objects = task.model.fetchInfoInCategory(CATEG_BULLETINS, withSearching: [], andSorting: .none, fromContext: task.contextToken)
            let objects2 = objects.filter() { x in
                return x.pictid! != U4Task.getThePictidFixup(x.id!)
            }
            let objects3 = objects2.map() { item in
                return "\"\(item.id!)\":\"\(item.pictid!)\""
            }
            let objects4 = objects3.joined(separator: ",\n")
            task.updateTask(step: 1, of: 1)
            if objects3.count > 0 {
                result = "Found \(objects3.count) info bulletin objects with different PICTIDs out of total \(objects.count) objects."
                print("\(result)\n\(objects4)\n")
            }
        }
        return result
    }
}
