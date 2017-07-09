//
//  BulletinUtilities.swift
//  StampCollection
//
//  Created by Michael L Mehr on 7/8/17.
//  Copyright © 2017 Michael L. Mehr. All rights reserved.
//

import Foundation

//let CATEG_BULLETINS:Int16 = 30
let CATEG_BULLETINS:Int16 = 30

// U4, Utility to add a pictfile ref to blanks in INFO items in the bulletins category (30)
class U4Task: UtilityTaskRunnable {
    static let defaultTask = U4Task()
    var isEnabled: Bool { return false }
    var taskName: String { return "UT2017_07_09_BULLETINS_ADD_PICREFS" }
    func runUtilityTask(_ model: CollectionStore) -> String {
        return addPictfileRefToBulletins(model)
    }
    
    func register(with: UtilityTaskRunner) {
        // register with the runner object
        with.registerUtilityTask(self as UtilityTaskRunnable)
    }
    
    private func addPictfileRefToBulletins(_ model: CollectionStore) -> String {
        var result = ""
        if true {
            let objects = model.fetchInfoInCategory(CATEG_BULLETINS)
            let objects2 = objects.filter() { x in
                return x.pictid! == ""
            }
            let objects3 = objects2.map{fixTheEmptyPictfile($0)}.map{$0.pictid!}
            let objects4 = objects3.joined(separator: " ")
            if objects3.count > 0 {
                result = "Found \(objects3.count) info bulletin objects with empty pictfile refs out of total \(objects.count) objects."
                print("\(result)\n\(objects4)")
            }
        }
        return result
    }
    
    private func fixTheEmptyPictfile(_ x: DealerItem) -> DealerItem {
        let item = x
        // special case: info bulletin category: BT now has pics up under the name "bulNNN.jpg" for bulletin NNN, same place as regular pics
        // the pictid is like "bu234" or "bu001", the name should be "bul234" or "bul1" (yes lower-case L AND 1 :)
        var nameToUse = item.id!
        var finalSuffix = ""
        if getCharacterClass(nameToUse.characters.last!) != .numeric {
            finalSuffix = String(nameToUse.characters.last!)
            nameToUse = String(nameToUse.characters.dropLast())
        }
        let (_, numS) = splitNumericEndOfString(nameToUse)
        if let num = Int(numS) {
            nameToUse = "bul\(num)\(finalSuffix)"
            item.pictid = nameToUse
        } else {
            print ("Skipping update for bulletin \(nameToUse)")
        }
        return item
    }
}


// U5, Utility to remove duplicate dates YYYY YYYY at start of InfoBulletin descriptionX fields (code buXXXX in category 30)
class U5Task: UtilityTaskRunnable {
    static let defaultTask = U5Task()
    var isEnabled: Bool { return false }
    var taskName: String { return "UT2017_07_09_BULLETINS_W_DUPLICATE_YEARS" }
    func runUtilityTask(_ model: CollectionStore) -> String {
        return removeInfoFoldersDuplicateDates(model)
    }
    
    func register(with: UtilityTaskRunner) {
        // register with the runner object
        with.registerUtilityTask(self as UtilityTaskRunnable)
    }
    
    private func removeInfoFoldersDuplicateDates(_ model: CollectionStore) -> String {
        var result = ""
        if true {
            let objects = model.fetchInfoInCategory(CATEG_BULLETINS)
            let objects2 = objects.filter() { x in
                return filterDuplicateDatePrefix(x.descriptionX!)
            }
            let objects3 = objects2.map{fixTheDuplicatePrefix($0)}.map{$0.descriptionX!}
            let objects4 = objects3.joined(separator: "\n")
            if objects3.count > 0 {
                result = "Found \(objects3.count) info bulletin objects with duplicate dates out of total \(objects.count) objects."
                print("\(result)\n\(objects4)")
            }
        }
        return result
    }
    
    private func filterDuplicateDatePrefix(_ test: String) -> Bool {
        var result = false
        guard test.characters.count >= 9 else { return result }
        guard let c1 = test.characters.first, getCharacterClass(c1) == .numeric else { return result }
        let splitPt1 = test.index(test.startIndex, offsetBy: 4)
        let splitPt2 = test.index(splitPt1, offsetBy: 1)
        let splitPt3 = test.index(splitPt2, offsetBy: 4)
        let firstFour = test.substring(to: splitPt1)
        let nextFour = test.substring(with: splitPt2..<splitPt3)
        if firstFour == nextFour {
            result = true
        }
        return result
    }
    
    private func fixTheDuplicatePrefix(_ x: DealerItem) -> DealerItem {
        let item = x
        item.descriptionX = String(x.descriptionX.characters.dropFirst(5))
        return item
        
    }
}
