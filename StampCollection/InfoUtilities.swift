//
//  InfoUtilities.swift
//  StampCollection
//
//  Created by Michael L Mehr on 5/2/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import Foundation

/*
 functions to help deal with understanding the basic components of DealerItem, the component of INFO (L1)
 INFO is the Level 1 layer of collection data, representing the valuation and cataloging facilities of dealers.
 INVENTORY is the Level 2 (L2) layer, representing which dealer items I have (or want) in my collection.
 The original design had an implied Level 3 (L3) layer that would include info on inventory acquisition and disposition, but I never implemented that in the website project (2011-2013).
 Currently I plan to add that function to L2 itself eventually in the Mac/IOS design here.

 So this file will draw mostly on the contents of UTCommon.PHP, MOProcess.PHP, and maybe BTProcess or UICommon.PHP.
 These files will be split across several utility files here, tho, and I don't currently have plans to allow for
   the re-creation of the web data from scratch, so some features are eliminated. That, and with the direct data 
   access ability from the live website ("scraping") provided by the NetworkModel module group here, I really 
   don't need a lot of the functionality that was provided in the PHP system to deal with BAITTOVxx.TXT files 
   that were really just copied and pasted from the website in a browser on Windows.

 I may need to revisit the decision about re-creating from scratch. First I must decide about the need for extending the additional info (not carried by the website). Consider each in turn:
---
Folders and bulletins: (MOProcess)
---
The Morgenstin catalog was scanned in and tweaked into a CSV file (via OCR project). This only took us up to 2009.
So I added folder info for 2009-2013 in the PHP system and tweaked it by filling in from the website data.
Check again how this goes, but I think the PHP code provided basic description data, some assumptions about ID codes, and continuation of feXXX bulletin numbering (referring directly to the number on the bulletin itself).
This is a live issue (FE), but the BU catalog is complete (finished in 1988 or so) and should not change.
There is a newer Morgenstin catalog available in online form, but not clear how easy it would be to use that.
The 2009 catalog used Bale catalog numbers for reference, but prob.from Bale 2006. My extension data in PHP used Bale 2013 references (I think). In 2016 this will again be a problem, no doubt. :)
Moving forward, usage of the FE folder with new FDC shipment entry is well understood. Each FDC and FE item share a page in my FDC albums. Data entry must continue to allow updating of FE data alongside FDC data, some of which may not yet be available in the Sets base category either.

---
SIMA data: (MOProcess)
---
The website category for SIMA provides basic items (code 6110m) for a full set of mint labels and for the FDC of a single label, from IPS machine 001. This is in the same category with data from Klussendorf, Frama, MASSAD, and other vending labels (not DALIA). Only MASSAD is still being produced, so these items change the numbering.
So as I wish to collect extra varieties (blanco, other machine sets, FDC of all machine labels on one cover), I need to add a few things to the cataloging system.
In my correspondence with Tari Chelouche, he had developed a private catalog of all things SIMA as an XLS file. So I input that catalog v2.0 as a CSV file, and tried to keep that up to date.
I created a never version of it, in which I kept adding as much as I knew about new issues, and whether or not I had them. I also added support for blanco labels (now a hot area of collection effort 5/2015).
Moving forward, I would like to have the ability to import this data from the CSV as I change it. Alternatively, I could have a way of entering the needed L1 data from the presence of website data, but I would need to implement a screen for determining which machines were involved, and what rate sets were in use (these change throughout the year). Plus, the SIMA machines are being replaced this year, and this may have major consequences. At first, Yuval Assif at IPS said they wouldn't ship these, but then they arrived in my April shipment. The machines are dying and need to be replaced, since the manufacturer has obsoleted the design. So only time will tell how the changes will affect me.

---
IRCs (International Reply Coupons)
---
The website only sells 20 of these. Bale lists ~150. I've tried to gather a collection, so there was a need to add more info.
Currently there is only one standardized coupon in use, and its design changes seldom (once or twice a decade). This is done by the UPU and not by the IPC.
The PHP code was designed to fill in the blanks by supplementing the BT data enough to make the Bale equivalent. This had to account for anomalies in the Bale numbering scheme as well as the fact that I didn't want to re-enter all the Bale data. So I only used generic prices and descriptions that would need fixups later. Only I never got around to writing the fixup code. Editing could be performed one item at a time.
Moving forward, this is mostly about editing the 100 or so fixups in some easier fashion. A batch editing screen would be useful here. The ongoing changes could be dealt with by a single-item editor. Pricing data would mostly have to come from Bale (3 year updates) when BT was not available (only 20, a lot less than were on the site when I scanned it back in 2013). Of course, if BT started selling more of these, the needs could change.

---
Full Sheet data
---
This is a major project. I doubt BT will ever sell these, and no comprehensive dealer has emerged. But I have amassed a nearly complete collection back to the early days, so this is worth indexing properly.
BT provides the PHP code with the basic set data, including catalog descriptions in many cases (see FE data). The Sets category uses Scott and Carmel catalog data. I parsed these fields in the PHP code to tell how many denominations were in each set, and provided an entry in L1 (coded 6110t) for each individual denom in the set. I made some extensions to the description fields generated, and created these generically. However, I wanted more in the inventory, so I added screens to easily update the basic entries with more info regarding plate numbers and dates, as well as layout formats (rows, cols). I had only completed fixup of maybe the first few years, so this work is ongoing.
Moving forward, each new shipment from IPC contains all relevant sheets as well. Any irregular (non 5x3 format) sheets will also have FDCs generated (and some 5x3 as well) that I may be interested in. BT will sell these special sheets in a separate category (the only sheets they sell), with mint and FDC versions in most cases.
So I need to deal with the facts of BT selling some sheets (code 6110e) and the rest needing regular entries in my 6110t category.
--
Bul Sheli Extensions (My Own Stamp sheets)
--
Plus there is the issue of My Own Stamp sheets, of which BT sells some (generic and preprinted by IPC), but not the full set of what I collect (date varieties). I never really dealt with that in the PHP code so far. There are more dates needed than on regular sheets. The same basic design (stamp portion) gets reused for years and only the designs of the pictures and inner stamps change, and sometimes the layout changes (WITHOUT a plate number change).

---
Souvenir Folders
---
IPC generates these ongoing. There are two types (at least): 
    Joint Issue items issued by IPC, usually containing the FE folder, souvenir leaf, and mint items (set or S/S), in a velveteen folder. 
    Bigger folders, usually containing a preprinted Bul Sheli sheet and some CDs or other items.

======
NOTE ON ID CODE USAGE FOR THESE EXTENSIONS
This can use the refItem field (in INV records) to link these, but ideally that should be in L1 data. In the PHP code, I managed to generate the ID codes for the base set from the given code in the BT data directly. There was one case where a fixup was needed (joint issue item didn't match its base set number for some reason).
======

---
Souvenir Leaves
---
In general, these are produced a lot by IPC but I am only interested in those related to Joint Issues. (See which)

---
Joint Issue items
---
This is a complex topic and I am interested in a lot of it. So much detail needed here.
BT provides some basic data and a numbering scheme that seemed to work for the basics. So my PHP code added a lot of data, but I decided early on there were just too many possible item combinations to deal with. So I created screens that would add L1 data on demand, as the L2 item showed up for entry.
The system was quite complicated, and could generate special coded ID numbers for 6110jNNNxZZZZZ, where the 'x' was the special character indicating my new ID. Tables would allow me to pick all the various item types that were relevant to this particular issue, and generate wants for the things if not directly entering a location.
Moving forward, IPC continues to do 3-4 of these a year, and sometimes the foreign country takes a while to get its issues out. (Ecuador has yet to issue its orchids joint, which Israel came out with last Oct.) Often FDCs are issued by both countries (not always), and even joint FDCs (with both countries items) can have designs by both Israel and the foreign country. So there is rich variety here to support. The Joint Issues category is for all items issued by the foreign government, plus any Israel items that contain both countries' items. Typically I want a Scott catalog number for the foreign stamp when available, although this may take years to find out.

---
Varieties and Variants
---
The ongoing output from IPC showing up on BT site here includes:
   imperf sets, FDCs, sheets, and sheet FDCs taken from collectible printers sheets
   self adhesive booklet/sheet individual items (used)
*/

/*
On extraction of dates for Year filtering:
See function GetBTDescriptionYearRange in UTCommon.PHP.
Here is the main comment info from there:
// returns the parsed year range from the various formats of the description field provided
// returns an array of 3 items:
//  'fmt' = format code (1-4) recognized, or 0 if nothing is recognized
//  'year0' = starting year
//  'year1' = ending year (diff.from year0 for ranges >1 yr.long)
// NOTE: there are several date formats accepted here
// 1: XXXX[space], 5ch, X are digits - this is a given year (range 1948-present)
// 2: XXXXs[space], 6ch, X are digits - this is a given decade, e.g. 1970s
// 3: XXXX-YYYY[space], 9ch, X and Y digits - this is a year range, YYYY > XXXX
// 4: DD.MM.YY[space], 8ch, DMY are digits - date in day.month.yr format
// 5: DD.MM.YYYY[space], 10ch, DMY are digits - date in day.month.yr format
// UPDATE: added format similar to #4 but at end of line

However, it seems like some things about this are too fragile.
Studying the current BT website data, the format at the end (for Ex Show Cards) seems to appear in the middle of about 1/3 of the records (less than 10 total). So it may not be important to get these filtered out, except maybe for AllCategories comparisons.
The most important formats are #1 and #4 or 5. Thing to note, the DD and MM fields are D or M if the number is less than 10.
So perhaps RegExps are the way to go here?
I'll start simple with #1-3 and see how many that works for.
*/

// constants needed
let startEpoch = 1948 // 1st year of Israel stamps
let endEpoch = 2047 // last year that this two-digit year scheme will work unambiguously
let yearsInCentury = 100
let startCentury = startEpoch / yearsInCentury * yearsInCentury
let endCentury = endEpoch / yearsInCentury * yearsInCentury
let startEpochYY = startEpoch - startCentury

func fixupCenturyYY( _ yy: Int ) -> Int {
    return yy >= startEpochYY ? startCentury : endCentury
}

func extractDateRangesFromDescription( _ descr: String ) -> (Int, ClosedRange<Int>, ClosedRange<Int>, ClosedRange<Int>) {
    var startYear = 0
    var endYear = 0
    var fmtFound = 0
    var found = ""
    //var descr2 = "" // DEBUG
    var startMonth = 0
    var startDay = 0
    var endMonth = 0
    var endDay = 0
    // begin testing here; order of tests IS IMPORTANT
    if let match = descr.range(of: "^[0-9][0-9][0-9][0-9][s ]", options: .regularExpression) {
        found = descr.substring(with: match)
        let yyyy = Int(String(found.characters.prefix(4)))!        //let yyyy = Int(found[0...3])!
        startYear = yyyy;
        let sep = String(found.characters.suffix(1))        //let sep = found[4...4]
        endYear = sep == "s" ? startYear+9 : startYear // such as 1960...1969, ten years long
        fmtFound = sep == "s" ? 2 : 1 // which is either YYYYs (2) or YYYY (1)
        // specify range of an entire year or range of years
        startMonth = 1; startDay = 1
        endMonth = 12; endDay = 31
    }
    else if let match = descr.range(of: "^[0-9][0-9][0-9][0-9]\\-[0-9][0-9][0-9][0-9]", options: .regularExpression) {
        fmtFound = 3 // which is YYYY-YYYY
        found = descr.substring(with: match)
        let years = found.components(separatedBy: "-")
        let yyyy = Int(years[0])!
        startYear = yyyy;
        let zzzz = Int(years[1])!
        endYear = zzzz
        // special case: if interval is 100 years or over, just use the 2nd year as the single rep.year
        // This is the case for 6110h602-4, where the string "1887-1987 Marc Chagall Centennary" actually happened in 1987
        if (endYear - startYear >= yearsInCentury) {
            startYear = endYear
        }
        // specify range of an entire year or range of years
        startMonth = 1; startDay = 1
        endMonth = 12; endDay = 31
    }
    else if let match = descr.range(of: "^[0-9][0-9]\\.[0-9][0-9]\\.[0-9][0-9][0-9][0-9]", options: .regularExpression) {
        fmtFound = 5 // which is DD.MM.YYYY - this MUST precede the format 4 YY counterpart, which would match all of these strings too
        found = descr.substring(with: match)
        let dmy = found.components(separatedBy: ".")
        let yyyy = Int(dmy[2])!
        startYear = yyyy;
        endYear = startYear
        let mm = Int(dmy[1])!
        startMonth = mm;
        endMonth = startMonth
        let dd = Int(dmy[0])!
        startDay = dd;
        endDay = startDay
    }
    else if let match = descr.range(of: "^[0-9][0-9]\\.[0-9][0-9]\\.[0-9][0-9]", options: .regularExpression) {
        fmtFound = 4 // which is DD.MM.YY - this must follow format 5 YYYY counterpart, so that it doesn't pre-empt that test
        found = descr.substring(with: match)
        let dmy = found.components(separatedBy: ".")
        let yy = Int(dmy[2])!
        startYear = yy + fixupCenturyYY(yy);
        endYear = startYear
        let mm = Int(dmy[1])!
        startMonth = mm;
        endMonth = startMonth
        let dd = Int(dmy[0])!
        startDay = dd;
        endDay = startDay
    }
    else if let match = descr.range(of: "^[0-9][0-9]\\-[0-9][0-9]\\.[0-9][0-9]\\.[0-9][0-9][0-9][0-9]", options: .regularExpression) {
        fmtFound = 6 // which is DD-DD.MM.YYYY (same note for YYYY preceding YY as above)
        found = descr.substring(with: match)
        let dmy = found.components(separatedBy: ".")
        let yyyy = Int(dmy[2])!
        startYear = yyyy;
        endYear = startYear
        let mm = Int(dmy[1])!
        startMonth = mm;
        endMonth = startMonth
        let ddd = dmy[0].components(separatedBy: "-")
        let dd = Int(ddd[0])!
        startDay = dd;
        let dd2 = Int(ddd[1])!
        endDay = dd2
    }
    else if let match = descr.range(of: "^[0-9][0-9]\\-[0-9][0-9]\\.[0-9][0-9]\\.[0-9][0-9]", options: .regularExpression) {
        fmtFound = 7 // which is DD-DD.MM.YY (same note for YY following YYYY as above)
        found = descr.substring(with: match)
        let dmy = found.components(separatedBy: ".")
        let yy = Int(dmy[2])!
        startYear = yy + fixupCenturyYY(yy);
        endYear = startYear // but diff days
        let mm = Int(dmy[1])!
        startMonth = mm;
        endMonth = startMonth
        let ddd = dmy[0].components(separatedBy: "-")
        let dd = Int(ddd[0])!
        startDay = dd;
        let dd2 = Int(ddd[1])!
        endDay = dd2
    }
    else if let match = descr.range(of: " \\'[0-9][0-9]", options: .regularExpression) {
        fmtFound = 8 // which is 'YY preceded by space, anywhere in string
        found = descr.substring(with: match)
        let yy = Int(String(found.characters.suffix(2)))!
        startYear = yy + fixupCenturyYY(yy);
        endYear = startYear
        //descr2 = descr // DEBUG
        // specify range of an entire year or range of years
        startMonth = 1; startDay = 1
        endMonth = 12; endDay = 31
    }
    else if let match = descr.range(of: " [0-9][0-9]\\'", options: .regularExpression) {
        fmtFound = 9 // which is YY' preceded by space, anywhere in string
        // NOTE: this will create false positives in Vending Labels, where the strings often contain things like 'Klussendorf 11' or 'Doarmat 23'
        found = descr.substring(with: match)
        let yidx1 = found.index(found.startIndex, offsetBy: 1)
        let yidx2 = found.index(found.startIndex, offsetBy: 3)
        let yy = Int(found[yidx1..<yidx2])!
        startYear = yy + fixupCenturyYY(yy);
        endYear = startYear
        //descr2 = descr // DEBUG
        // specify range of an entire year or range of years
        startMonth = 1; startDay = 1
        endMonth = 12; endDay = 31
    }
    else if let match = descr.range(of: "[Dd]ate.[0-9][0-9][0-9][0-9][0-9][0-9]", options: .regularExpression) {
        fmtFound = 10 // which is 'Date DDMMYY', anywhere in string (also accepts 1st letter LC)
        // NOTE: this is used by one booklet item that specifies nothing but "print date 100989" for 10 Sep 1989 (Olive Branch booklet reprint)
        found = descr.substring(with: match)
        let yidx1 = found.index(found.startIndex, offsetBy: 9)
        let yidx2 = found.index(found.startIndex, offsetBy: 10)
        let yy = Int(found[yidx1...yidx2])!
        startYear = yy + fixupCenturyYY(yy);
        endYear = startYear
        //descr2 = descr // DEBUG
        let midx1 = found.index(found.startIndex, offsetBy: 7)
        let midx2 = found.index(found.startIndex, offsetBy: 8)
        let mm = Int(found[midx1...midx2])!
        startMonth = mm;
        endMonth = startMonth
        let didx1 = found.index(found.startIndex, offsetBy: 5)
        let didx2 = found.index(found.startIndex, offsetBy: 6)
        let dd = Int(found[didx1...didx2])!
        startDay = dd;
        endDay = startDay
    }
    else if let match = descr.range(of: " [0-9][0-9][0-9][0-9][^0-9]", options: .regularExpression) {
        // NOTE: this causes some false positives in AUI class (no dates given), only one of which is a date (e.g., "Jerusalem 3000")
        // SANITY RANGE CHECK REQUIRED - we only want dates between 1948 and 2015 (or current year, whatever it is!)
        found = descr.substring(with: match)
        let yidx1 = found.index(found.startIndex, offsetBy: 1)
        let yidx2 = found.index(found.startIndex, offsetBy: 4)
        let yyyy = Int(found[yidx1...yidx2])!
        //descr2 = descr // DEBUG
        if yyyy >= startEpoch && yyyy <= endEpoch {
            fmtFound = 11 // which is YYYY preceded by space, anywhere in string
            startYear = yyyy;
            endYear = startYear
            // specify range of an entire year or range of years
            startMonth = 1; startDay = 1
            endMonth = 12; endDay = 31
        }
    } else {
        //descr2 = descr // DEBUG
    }
    //println("Found [\(found)] as YearRange[fmt=\(fmtFound), \(startYear)...\(endYear)]") //\(descr2)")
    return (fmtFound, startYear...endYear, startMonth...endMonth, startDay...endDay)
}

/*
 ONE-TIME TASK UTILITIES
 This is the place to add functionality to scan and fix parts of the INFO or INVENTORY databases that shouldn't need to be repeated often.
 The calls can be placed at the appropriate point in the runtime code, but can be cut off here, funneled through the master funcion.
 */

enum OneTimeTaskType: CustomStringConvertible {
    case OTT2017_07_02_INFOLDERS_W_DUPLICATE_YEARS
    , OTT2017_07_05_ADD_MISSING_INFOLDERS
    , OTT2017_07_05_ADD_MISSING_ATM_BLANCO_LABELS
    
    var description: String {
        switch self {
        case .OTT2017_07_02_INFOLDERS_W_DUPLICATE_YEARS:
            return "OTT2017_07_02_INFOLDERS_W_DUPLICATE_YEARS"
        case .OTT2017_07_05_ADD_MISSING_INFOLDERS:
            return "OTT2017_07_05_ADD_MISSING_INFOLDERS"
        case .OTT2017_07_05_ADD_MISSING_ATM_BLANCO_LABELS:
            return "OTT2017_07_05_ADD_MISSING_ATM_BLANCO_LABELS"
        }
    }
}

// map of types to their functions (use nil to prevent execution)
// NOTE: In spite of the name, the facility can be used with multiple calls and/or even running them every time. It's all in the source code here.
typealias TaskFunc = ((CollectionStore) -> String)
fileprivate let ottPolicies:[String:TaskFunc?] = [
    OneTimeTaskType.OTT2017_07_02_INFOLDERS_W_DUPLICATE_YEARS.description: nil, //(removeInfoFoldersDuplicateDates as! TaskFunc),
    OneTimeTaskType.OTT2017_07_05_ADD_MISSING_INFOLDERS.description: createMissingFoldersCSV,
    OneTimeTaskType.OTT2017_07_05_ADD_MISSING_ATM_BLANCO_LABELS.description: createMissingATMBlancoLabelsCSV,
]

func callUtilityTasks(forModel model: CollectionStore) -> String {
    var result = ""
    for (tasktype, taskfunc) in ottPolicies {
        if let taskfunc = taskfunc {
            print("Running Task \(tasktype)")
            result = taskfunc(model)
        }
    }
    return result
}

let CATEG_INFOLDERS:Int16 = 29

// U1, Utility to remove duplicate dates YYYY YYYY at start of InfoBulletin descriptionX fields (code feXXXX in category 29)
fileprivate func removeInfoFoldersDuplicateDates(_ model: CollectionStore) -> String {
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

fileprivate func filterDuplicateDatePrefix(_ test: String) -> Bool {
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

fileprivate func fixTheDuplicatePrefix(_ x: DealerItem) -> DealerItem {
    let item = x
    item.descriptionX = String(x.descriptionX.characters.dropFirst(5))
    return item
    
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

fileprivate func createMissingFoldersCSV(_ model: CollectionStore) -> String {
    let startingFolderNumber = 1026
    let startingCodeNumber = 1354
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
            printFolderCSVEntry(folderNum, fromSetItem: item)
            folderNum += 1
            if firstCode.isEmpty {
                firstCode = codeID
            }
            lastCode = codeID
            if firstDesc.isEmpty {
                firstDesc = item.descriptionX!
            }
            lastDesc = item.descriptionX!
            missingCounter = 0
            totalExamined += 1
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

fileprivate func printFolderCSVEntry(_ folderNum:Int, fromSetItem item: DealerItem) {
    let fepref = folderNum > 999 ? "" : "0"
    let fecode = "fe\(fepref)\(folderNum)"
    print("\(fecode),\"\(item.descriptionX!)\",Unavailable,feuillet2,0,\"(X)Information Folders\",,,0.65,0.00,,,1,0,0,0,,,,,29")
}

// U3, Utility to generate missing Blanco ATM labels.
// Method:
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
//

let CATEG_ATM:Int16 = 26
let ignores = [ "6110k0707", "6110k0708", "6110k0803", "6110k0804", "6110k0805", "6110k0806", ]
fileprivate func createMissingATMBlancoLabelsCSV(_ model: CollectionStore) -> String {
    var result = ""
    var firstCode = ""
    var lastCode = ""
    var firstDesc = ""
    var lastDesc = ""
    var totalAdded = 0
    let objects1 = model.fetchInfoInCategory(CATEG_ATM, withSearching: [.keyWordListAny(["Sima", "Inbar"])], andSorting: .byImport(true))
    let objects2 = objects1.filter() { x in
        return !(x.descriptionX!.contains("FDC") || x.id!.contains("m") || x.id!.contains("bl"))
    }
    let objects3 = objects2.filter() { x in
        return !ignores.contains(x.id!)
    }
    for item in objects3 {
        let blIdCode = "\(item.id!)bl"
        let descCore = getCoreOfATMDescription(item)
        if let _ = model.fetchInfoItemByID(blIdCode) {
            //print("\(item.id!): \(descCore) already has a blanco label.")
            continue
        }
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
    }
    if totalAdded > 0 {
        result = "Created \(totalAdded) CSV entries for ATM blanco labels for sets from \(firstCode): \(firstDesc) to \(lastCode): \(lastDesc)."
        print(result)
    }
    return result
}

fileprivate func getCoreOfATMDescription(_ item: DealerItem) -> String {
    let desclines = item.descriptionX!.components(separatedBy: ",")
    return desclines[0]
}

fileprivate func printATMBlancoCSVEntry(fromSetItem item: DealerItem) {
    let idCode = item.id!
    let desc = getCoreOfATMDescription(item)
    print("\(idCode)bl,\"\(desc), blanco label\",Unavailable,\(idCode),-1,\"Vending Machine Labels\",,,45.00,,,,0,0,0,0,,,,,26")
}


