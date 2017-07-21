//
//  ATMUtilities.swift
//  StampCollection
//
//  Created by Michael L Mehr on 7/6/17.
//  Copyright © 2017 Michael L. Mehr. All rights reserved.
//

import Foundation

// U3, Utility to generate missing INFO entries for ATM labels (blanco labels, machine sets).
// Method (labels):
// 1. Search for Category 26 (ATM labels) with keywords like 'Sima' and 'Inbar' (filter? search criteria?) - filter out descriptionX containing "FDC"
// 2. For each item, add 'bl' to the code, modify the description (use up to ',' and add ", blanco label"), and use the appropriate value/price line to generate and print the CSV entries
// 3. Print the stats as results (#mods, #examined)
//
// 6110k1313bl,"26.08.13 'Sima 49' Nymphaea caerulea, blanco label",Unavailable,6110k1313,-1,"Vending Machine Labels",,,45.00,,,,0,0,0,0,,,,,26
//
// RUN RESULTS:
// There are several varieties included in the BT main list here that should also be avoided:
/*
 6110k0707bl,"27.08.07 'Sima 13' Eilat, blanco label",Unavailable,6110k0707,-1,"Vending Machine Labels",,,45.00,,,,0,0,0,0,,,,,26
 6110k0708bl,"27.08.07 'Sima 13' Eilat, blanco label",Unavailable,6110k0708,-1,"Vending Machine Labels",,,45.00,,,,0,0,0,0,,,,,26
 6110k0803bl,"14.05.08 'Sima 9' Rehovot, blanco label",Unavailable,6110k0803,-1,"Vending Machine Labels",,,45.00,,,,0,0,0,0,,,,,26
 6110k0804bl,"14.05.08 'Sima 11' 'Doarmat 11' Doar Israel II, blanco label",Unavailable,6110k0804,-1,"Vending Machine Labels",,,45.00,,,,0,0,0,0,,,,,26
 6110k0805bl,"14.05.08 'Sima 12' Ashdod, blanco label",Unavailable,6110k0805,-1,"Vending Machine Labels",,,45.00,,,,0,0,0,0,,,,,26
 6110k0806bl,"14.05.08 'Sima 13' Eilat, blanco label",Unavailable,6110k0806,-1,"Vending Machine Labels",,,45.00,,,,0,0,0,0,,,,,26
 from base entries:
 6110k0707,"27.08.07 'Sima 13' Eilat, full set of 8 values, Eilat machine 013 1.50/2.20/2.40/2.50/2.90/3.00/4.30/4.90",Available,6110k0707,0,"Vending Machine Labels",,,14.00,,,,1,0,0,0,,,,,26
 6110k0708,"27.08.07 'Sima 13' Eilat, full set of 8 values, Carmiel machine 004 1.50/2.20/2.40/2.50/2.90/3.00/4.30/4.90",Available,6110k0708,0,"Vending Machine Labels",,,14.00,,,,1,0,0,0,,,,,26
 6110k0803,"14.05.08 'Sima 9' Rehovot, full set of 8 values 1.55/2.25/2.80/3.30/3.40/4.50/4.60/5.80 Black Ink",Available,6110k0803,0,"Vending Machine Labels","C --","B M.09",14.00,,,,1,0,0,0,,,,,26
 6110k0804,"14.05.08 'Sima 11' 'Doarmat 11' Doar Israel II, full set of 8 values 1.55/2.25/2.80/3.30/3.40/4.50/4.60/5.80 Black Ink",Available,6110k0804,0,"Vending Machine Labels","C --","B M.11",14.00,,,,1,0,0,0,,,,,26
 6110k0805,"14.05.08 'Sima 12' Ashdod, full set of 8 values 1.55/2.25/2.80/3.30/3.40/4.50/4.60/5.80 Black Ink",Available,6110k0805,0,"Vending Machine Labels","C --","B M.12",14.00,,,,1,0,0,0,,,,,26
 6110k0806,"14.05.08 'Sima 13' Eilat, full set of 8 values 1.55/2.25/2.80/3.30/3.40/4.50/4.60/5.80 Black Ink",Available,6110k0806,0,"Vending Machine Labels","C --","B M.13",14.00,,,,1,0,0,0,,,,,26
 */
// Rather than find a pattern here, just exclude these IDs directly
// Basically these are where BT is offering a popular variety of an ATM issue rate set that I would normally base expanded sets on
//
// UPDATE: This was so useful, I decided to add the detection and generation of machine sets (derived from the main sets) as well
// Method:
// 1. Once the list of basic 6110k sets has been filtered appropriately to generate a label, it can also be the basis for a family of machine sets
// 2. The simplest ones are alternate machines for the IPS sets sold by BT dealer; we just need to know the machine number
// 3. Since many issues have several alternative machine numbers, this should be an array.
// 4. EXTENSION - Sima issues in the mid-2010s had several rate changes throughout the year, all of which were collectible; Bale2016 provides most of these on page 320, though some of their data is erroneous
// 4a. The machine numbers array (indexed by set ID), must be augmented to include several arrays, each of which is a set of machines using the given rate set
// 4b. The rate sets (lists of values as a string) are indexed by a code that is the year number (like '13' for 2013) followed by a period ('.') and the code to use ("RC", "RC2")
// 4c. When running, the machine number array in use determines which rate code set to use; default is to use the values defined by BT dealer in the description.
// This relies on splitting the descriptionX field into two parts at the word "values", and adding the machine description there; the subsequent value list might be replaced by a rate set change.

let CATEG_ATM:Int16 = 26
class U3Task: NSObject, UtilityTaskRunnable {
    
    var task: UtilityTask! {
        didSet {
            // set up the proxy once we know the object's reference
            task.reportedTaskUnits = TU
            task.isEnabled = isEnabled
            task.taskName = taskName
            // protocol: set initial taskUnits to non-0 if we have work, 0 if we don't (database category empty)
            task.taskUnits = !isEnabled ? 0 : task.countCategories([CATEG_ATM])
        }
    }
    
    let TU:Int64 = 5000 // generate this as approx msec execution time on my device; only relative size matters
    // protocol: UtilityTaskRunnable
    var isEnabled = false
    var taskName: String { return "UT2017_07_05_ADD_MISSING_ATM_BLANCO_LABELS_AND_SETS" }
    
    private weak var runner: UtilityTaskRunner! // prevent circular refs, we're in each other's tables
    
    // MARK: Task data and functions
    
    let ignores = [ "6110k0707", "6110k0708", "6110k0803", "6110k0804", "6110k0805", "6110k0806", ]
    
    func run() -> String {
        var result = ""
        var firstCode = ""
        var lastCode = ""
        var firstDesc = ""
        var lastDesc = ""
        var totalAdded = 0
        let objects1 = task.model.fetchInfoInCategory(CATEG_ATM, withSearching: [.keyWordListAny(["Sima", "Inbar"])], andSorting: .byImport(true), fromContext: task.contextToken)
        let objects2 = objects1.filter() { x in
            return !(x.descriptionX!.contains("FDC") || x.id!.contains("m") || x.id!.contains("bl"))
        }
        let objects3 = objects2.filter() { x in
            return !ignores.contains(x.id!)
        }
        let totalSteps = Int64(objects3.count)
        task.taskUnits = totalSteps
        var stepCount:Int64 = 0
        for item in objects3 {
            // test for and create blanco label if needed
            let blIdCode = "\(item.id!)bl"
            let descCore = getCoreOfATMDescription(item)
            if task.model.fetchInfoItemByID(blIdCode, inContext: task.contextToken) == nil {
                printATMBlancoCSVEntry(fromSetItem: item)
                totalAdded += 1
                if firstCode.isEmpty {
                    firstCode = item.id!
                }
                lastCode = item.id!
                if firstDesc.isEmpty {
                    firstDesc = descCore
                }
                lastDesc = descCore
            } else {
                //print("\(item.id!): \(descCore) already has a blanco label.")
                //continue
            }
            // also test for and create related machine sets for the same base sets
            printATM_MachineSets_CSVEntries(fromSetItem: item)
            stepCount += 1
            task.updateTask(step: stepCount, of: totalSteps)
        }
        if totalAdded > 0 {
            result = "Created \(totalAdded) CSV entries for ATM blanco labels for sets from \(firstCode): \(firstDesc) to \(lastCode): \(lastDesc)."
            print(result)
        }
        return result
    }
    
    private func getCoreOfATMDescription(_ item: DealerItem) -> String {
        let desclines = item.descriptionX!.components(separatedBy: ",")
        return desclines[0]
    }
    
    private func printATMBlancoCSVEntry(fromSetItem item: DealerItem) {
        let idCode = item.id!
        let desc = getCoreOfATMDescription(item)
        print("\(idCode)bl,\"\(desc), blanco label\",Unavailable,\(idCode),-1,\"Vending Machine Labels\",,,45.00,,,,0,0,0,0,,,,,26")
    }
    
    // Utility 3a, derived from above to add machine sets interleaved with the blanco labels
    /* REPRESENTATIVE SAMPLE
     6110k1001m004,"03.01.10 'Sima 24' Yellow birds, full set of 8 values, Carmiel machine 004 - 1.60/2.40/3.60/3.80/4.60/5.30/6.50/6.70",Unavailable,6110k1001,-1,"Vending Machine Labels","C --","B --",55.00,,,,0,0,0,0,,,,,26
     6110k1001m006,"03.01.10 'Sima 24' Yellow birds, full set of 8 values, Haifa machine 006 - 1.60/2.40/3.60/3.80/4.60/5.30/6.50/6.70",Unavailable,6110k1001,-1,"Vending Machine Labels","C --","B --",55.00,,,,0,0,0,0,,,,,26
     6110k1001m008,"03.01.10 'Sima 24' Yellow birds, full set of 8 values, Netanya machine 008 - 1.60/2.40/3.60/3.80/4.60/5.30/6.50/6.70",Unavailable,6110k1001,-1,"Vending Machine Labels","C --","B --",55.00,,,,0,0,0,0,,,,,26
     6110k1001m010,"03.01.10 'Sima 24' Yellow birds, full set of 8 values, Jerusalem machine 010 - 1.60/2.40/3.60/3.80/4.60/5.30/6.50/6.70",Unavailable,6110k1001,-1,"Vending Machine Labels","C --","B --",55.00,,,,0,0,0,0,,,,,26
     6110k1001m011,"03.01.10 'Sima 24' Yellow birds, full set of 8 values, Rehovot machine 011 - 1.60/2.40/3.60/3.80/4.60/5.30/6.50/6.70",Unavailable,6110k1001,-1,"Vending Machine Labels","C --","B --",55.00,,,,0,0,0,0,,,,,26
     6110k1001m012,"03.01.10 'Sima 24' Yellow birds, full set of 8 values, Beer Sheva machine 012 - 1.60/2.40/3.60/3.80/4.60/5.30/6.50/6.70",Unavailable,6110k1001,-1,"Vending Machine Labels","C --","B --",55.00,,,,0,0,0,0,,,,,26
     6110k1001m013,"03.01.10 'Sima 24' Yellow birds, full set of 8 values, Eilat machine 013 - 1.60/2.40/3.60/3.80/4.60/5.30/6.50/6.70",Unavailable,6110k1001,-1,"Vending Machine Labels","C --","B --",55.00,,,,0,0,0,0,,,,,26
     6110k1001m015,"03.01.10 'Sima 24' Yellow birds, full set of 8 values, Nazareth machine 015 - 1.60/2.40/3.60/3.80/4.60/5.30/6.50/6.70",Unavailable,6110k1001,-1,"Vending Machine Labels","C --","B --",55.00,,,,0,0,0,0,,,,,26
     6110k1001m018,"03.01.10 'Sima 24' Yellow birds, full set of 8 values, Ashdod machine 018 - 1.60/2.40/3.60/3.80/4.60/5.30/6.50/6.70",Unavailable,6110k1001,-1,"Vending Machine Labels","C --","B --",55.00,,,,0,0,0,0,,,,,26
     taken from
     6110k1001,"03.01.10 'Sima 24' Birds of Israel 2, full set of 8 values 1.60/2.40/3.60/3.80/4.60/5.30/6.50/6.70","1 In Stock",6110k1001,0,"Vending Machine Labels","C --","B --",17.50,,,,1,0,0,0,,,,,26
     OR
     6110k1511,"24.11.15 'Inbar 4' Christmas, full set of 6 values 2.20/4.10/6.50/7.40/8.30/9.00",Available,6110k1511,0,"Vending Machine Labels",,,19.00,,,,1,0,0,0,,,,,26
     
     */
    
    let machineListSima = [
        "001":"Jaffa IPS",
        "002":"Nahariya",
        "003":"Acre",
        "004":"Carmiel", // Tari's preferred spelling of Carmel
        "005":"Tiberia",
        "006":"Haifa",
        "007":"Hadera",
        "008":"Netanya",
        "009":"Tel Aviv",
        "010":"Jerusalem", // replaced with 020 in 2014+
        "011":"Rehovot",
        "012":"Beer Sheva",
        "013":"Eilat", // retired in 2013+
        "014":"Exhibition",
        "015":"Nazareth",
        "016":"Exhibition?",
        "017":"Exhibition",
        "018":"Ashdod",
        "020":"Jerusalem", // replaces 010 in 2014+
        "061":"Exhibition",
        "062":"Exhibition",
        "065":"Exhibition",
        ]
    
    let machineListInbar = [
        "001":"Tel Aviv IPS",
        "101":"Jerusalem",
        "220":"Beer Sheva",
        "300":"Ashdod",
        "326":"Rishon LeZion",
        "450":"Rehovot",
        "636":"Netanya",
        "714":"Haifa",
        "900":"Tiberia",
        "920":"Acre",
        "987":"Nazareth",
        "1601":"Exhibition",
        "1602":"Exhibition",
        "1603":"Exhibition",
        ]
    
    // catalog of what to actually add (no real pattern here to exploit that I can see)
    let issues = [
        // 2013
        "6110k1301": [["004","006","008","010","011","012","015","018"], // base rate given by desc2 from BT
            ["001","004","006","008","010","011","012","015","018"], //13.RC
            ["001","006","008","010","011","015","018"], //13.RC2
        ],
        "6110k1303": [["012"],["001","012"],["001","012"],],
        "6110k1305": [["004"],["001","004"],["001","004"],],
        "6110k1307": [["011"],["001","011"],["001","011"],],
        "6110k1309": [["065"],],
        "6110k1313": [["006"],],
        "6110k1315": [["010","015"],],
        // 2014
        "6110k1401": [["004","006","010","011","012","015","018","020"], // base rate given by desc2 from BT
            ["001","004","006","011","012","015","018","020"], //14.RC
            ["001","004","006","011","012","015","018","020"], //14.RC2
        ],
        "6110k1403": [["008","010","020"],["001","008"],["001","008"],],
        "6110k1405": [["004"],["001","004"],["001","004"],],
        "6110k1407": [["020"],],
        "6110k1409": [["011"],["001","011"],["001","011"],],
        "6110k1411": [["015"],[],["001","015"]],
        "6110k1413": [["015","020"],],
        // 2015 Sima
        "6110k1501": [["004", "008", "011", "015", "020"],],
        "6110k1503": [["004"],],
        // 2015 Inbar
        "6110k1505": [["101","220","300","326","450","636","714","900","920","987"],],
        "6110k1507": [["300"],],
        "6110k1509": [["900"],],
        "6110k1511": [["101","987"],],
        "6110k1513": [["220"],],
        // 2016 Inbar
        "6110k1601": [["101","220","300","326","450","636","714","900","920","987","1603"],],
        "6110k1603": [["220"],],
        "6110k1605": [["450"],],
        "6110k1607": [["101"],],
        "6110k1609": [["714"],],
        "6110k1613": [["1601"],],
        "6110k1611": [["101","987","1602"],],
        // 2017 Inbar
        "6110k1701": [["101","220","300","326","450","636","714","900","920","987"],],
        "6110k1703": [["300"],],
        "6110k1705": [["326"],],
        "6110k1707": [["636"],],
        ]
    
    let rateSets = [
        "13.RC": " 2.00/3.10/3.50/4.20/4.60/5.00/6.10/6.20",
        "13.RC2": " 2.00/3.10/3.20/3.90/4.60/5.20/5.60/5.70", // also base rates for 2014
        "14.RC": " 2.00/3.10/3.20/3.80/4.60/5.10/5.50/5.60",
        "14.RC2": " 1.80/2.70/3.20/3.80/4.00/5.10/5.50/5.60",
        ]
    
    private func printATM_MachineSets_CSVEntries(fromSetItem item: DealerItem) {
        let idCode = item.id!
        let kRange = idCode.range(of: "6110k")!
        let ycodeX = idCode.substring(from: kRange.upperBound)
        let ycode = String(ycodeX.characters.prefix(2))
        
        let desc = item.descriptionX!
        let isSima = desc.range(of: "'Sima ") != nil
        let isInbar = desc.range(of: "'Inbar ") != nil
        guard isSima != isInbar else { return } // just one or the other
        let macnames = isSima ? machineListSima : machineListInbar
        
        if let macnumsets = issues[idCode] {
            // primary rates (desc2) used for these machine numbers
            printATM_SingleMachineSet_CSVEntries(fromSetItem: item, forMachines: macnumsets[0], withNames: macnames)
            if macnumsets.count > 1 {
                // first secondary rates used with these numbers
                printATM_SingleMachineSet_CSVEntries(fromSetItem: item, forMachines: macnumsets[1], withNames: macnames, andRateSet: ycode+".RC")
            }
            if macnumsets.count > 2 {
                // second secondary rates used with these numbers
                printATM_SingleMachineSet_CSVEntries(fromSetItem: item, forMachines: macnumsets[2], withNames: macnames, andRateSet: ycode+".RC2")
            }
        }
    }
    
    private func printATM_SingleMachineSet_CSVEntries(fromSetItem item: DealerItem, forMachines macnums:[String], withNames macnames:[String:String], andRateSet rsCode: String = "") {
        let idCode = item.id!
        let desc = item.descriptionX!
        if let valRange = desc.range(of: "values") {
            let desc1 = desc.substring(to: valRange.upperBound)
            var desc2 = desc.substring(from: valRange.upperBound)
            var rcString = ""
            if !rsCode.isEmpty {
                desc2 = rateSets[rsCode]!
                let rcss = rsCode.components(separatedBy: ".")
                if rcss.count > 1 {
                    rcString = rcss[1]
                }
            }
            for macnum in macnums {
                let msetCode = "\(idCode)\(rcString)m\(macnum)"
                // probe for existence of individual mset entry and only add if not already exists
                if task.model.fetchInfoItemByID(msetCode, inContext: task.contextToken) == nil {
                    if let macname = macnames[macnum] {
                        print("\(msetCode),\"\(desc1), \(macname) machine \(macnum) -\(desc2)\",Unavailable,\(idCode),-1,\"Vending Machine Labels\",\"C --\",\"B --\",55.00,,,,0,0,0,0,,,,,26")
                    }
                }
            }
        }
    }
}
