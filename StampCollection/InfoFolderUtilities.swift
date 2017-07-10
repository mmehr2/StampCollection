//
//  InfoFolderUtilities.swift
//  StampCollection
//
//  Created by Michael L Mehr on 7/6/17.
//  Copyright © 2017 Michael L. Mehr. All rights reserved.
//

import Foundation

let CATEG_INFOLDERS:Int16 = 29

// U1, Utility to remove duplicate dates YYYY YYYY at start of InfoBulletin descriptionX fields (code feXXXX in category 29)
class U1Task: UtilityTaskRunnable {
    static let defaultTask = U1Task()
    var isEnabled: Bool { return false }
    var taskName: String { return "UT2017_07_02_INFOLDERS_W_DUPLICATE_YEARS" }
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
            let objects = model.fetchInfoInCategory(CATEG_INFOLDERS)
            let objects2 = objects.filter() { x in
                return filterDuplicateDatePrefix(x.descriptionX!)
            }
            let objects3 = objects2.map{fixTheDuplicatePrefix($0)}.map{$0.descriptionX!}
            let objects4 = objects3.joined(separator: "\n")
            result = "Found \(objects3.count) info folder objects with duplicate dates out of total \(objects.count) objects."
            print("\(result)\n\(objects4)")
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


// U2, Utility to create missing CSV folders.
// Once the starting set code and folder number are determined (hard coded for now), it scans the Sets category (sorted in code order) and prints lines (intended for INFO.CSV) to combine
//   the description from the set with the next folder number. Experience from the last 3 years indicated this worked in all but one case, easily fixable by hand (short sequence out of order around fe0953).
// end of CSV line for info folder creation (field template)
let CATEG_SETS:Int16 = 2
// RESULTS: (paste from run, then update starting C and F numbers below for next run
// Created 83 entries of missing folders #943 to #1025 for sets from 6110s1236: 2014 Mateh Yehuda to 6110s1353: 2017 Music Love Songs with 40 gap codes from set of 123.
// RESULT MISNUMBERS:
// 953 rabbi ovadiah comes after 954-957 (fix by hand needed)

class U2Task: UtilityTaskRunnable {
    static let defaultTask = U2Task()
    var isEnabled: Bool { return true }
    var taskName: String { return "UT2017_07_05_ADD_MISSING_INFO_FOLDERS" }
    func runUtilityTask(_ model: CollectionStore) -> String {
        return createMissingFoldersCSV(model)
    }
    
    func register(with: UtilityTaskRunner) {
        // register with the runner object
        with.registerUtilityTask(self as UtilityTaskRunnable)
    }
    
    private func createMissingFoldersCSV(_ model: CollectionStore) -> String {
        let startingFolderNumber = 927 // Greenland S/S, first one not in old Morgenstein catalog
        let startingCodeNumber = 1215
        var folderNum = startingFolderNumber
        var setCodeNum = startingCodeNumber
        var result = ""
        var missingCounter = 0
        var totalExamined = 0
        var totalMissing = 0
        var total = 0
        var firstCode = ""
        var lastCode = ""
        var firstDesc = ""
        var lastDesc = ""
        while true {
            total += 1
            let codeID = "6110s\(setCodeNum)"
            if let item = model.fetchInfoItemByID(codeID) {
                // make sure folder doesn't already exist for this set
                let fecode = getFolderCode(from: folderNum)
                if model.fetchInfoItemByID(fecode) == nil {
                    printFolderCSVEntry(folderNum, fromSetItem: item)
                    if firstCode.isEmpty {
                        firstCode = codeID
                    }
                    lastCode = codeID
                    if firstDesc.isEmpty {
                        firstDesc = item.descriptionX!
                    }
                    lastDesc = item.descriptionX!
                    totalExamined += 1
                } else {
                    // else this has already been done, don't count it, just on to the next one
                }
                folderNum += 1
                missingCounter = 0
            } else {
                // count missed items in a row, if we miss 3 in a row, stop
                totalMissing += 1
                missingCounter += 1
                // NOTE: BT usually leaves gaps in set numbering for special sheets in 6110e - largest gap I've seen is 2, but this may need to be adjusted upward; 5 is probably better
                if missingCounter >= 5 {
                    break
                }
            }
            setCodeNum += 1
        }
        if totalExamined > 0 {
            result = "Created \(totalExamined) entries of missing folders #\(startingFolderNumber) to #\(folderNum-1) for sets from \(firstCode): \(firstDesc) to \(lastCode): \(lastDesc) with \(totalMissing) gap codes from set of \(total)."
            print(result)
        }
        return result
    }
    
    private func getFolderCode(from folderNum:Int) -> String {
        let fepref = folderNum > 999 ? "" : "0"
        let fecode = "fe\(fepref)\(folderNum)"
        return fecode
    }
    
    private func printFolderCSVEntry(_ folderNum:Int, fromSetItem item: DealerItem) {
        let fecode = getFolderCode(from: folderNum)
        print("\(fecode),\"\(item.descriptionX!)\",Unavailable,feuillet2,0,\"(X)Information Folders\",,,0.65,0.00,,,1,0,0,0,,,,,29")
    }
}