//
//  FullSheetUtilities.swift
//  StampCollection
//
//  Created by Michael L Mehr on 7/20/17.
//  Copyright © 2017 Michael L. Mehr. All rights reserved.
//

import Foundation

/*
 The two tasks here (U7, U8) involve creating CSV listings for full sheets using derived data from BTItemDetails and sets (cat 2)
 The first task (U7) deals with correcting entries for existing inventory.
 The second task (U8) deals with creating new entries as web data additions are detected.
 Theoretically, U7 should only need to be run once. However, if BT changes the basic set descriptions or data, we may need to rerun it.
 U8 should be run every time updates with new set items are detected.
 Currently, all output goes to the debug console for capture and inclusion in INFO.CSV and subsequent import.
 TBD - eventually this needs to be automated and triggered by the Updates process incrementally (4-5x / yr as IPS releases occur).
 
 Set cardinality - how many sheets are in the published set
 This is typically determined from BTItemDetails plateNumbers list.
 Certain sets (Anemone, SongBirds, Shekel Stand-by) have no plate numbers (p--) so a table of exceptions is needed.
 Also certain other sets (Doar Ivri, '49 Flag, others) reused the same plate number multiple times
 This is probably best implemented in the BTItemDetails class itself by a static ID-code table.
 NOTE: Cat1 or cat2 fields could also be used, but don't exist after certain dates (currently, mid-2013). This no doubt requires labor by the BT site team whenever a new Carmel catalog is released.
 
 Further notes on cat1, cat2:
 This also needs to be done in BTItemDetails. It is similar to the plate number list parsing, but complicated by several things:
   1. Alphanumeric prefix/suffix conventions: consider C numbers like B88 or 431,432 or 1893-96, or S numbers 1708a-c or J6-J11
   2. Errors (see fixCatField() in BTDealerItem.swift)
   3. Anomalies such as 6110s323 "1978 Memorial Day": "C ---" and "S 694a-" (could poss.be fixed by new rule tho)
 
 An ideal example: 6110s352,"1980 Thistles"
 The original PHP code created (old way):
 6110t352_01,"1980 Thistles- Full sheet",Unavailable,6110s352,0,"(X)Full Sheets","C 867full","S 745full",10.00,0.00,,,0,0,0,0,,,,,31
 6110t352_02,"1980 Thistles- Full sheet",Unavailable,6110s352,0,"(X)Full Sheets","C 868full","S 746full",10.00,0.00,,,0,0,0,0,,,,,31
 6110t352_03,"1980 Thistles- Full sheet",Unavailable,6110s352,0,"(X)Full Sheets","C 869full","S 747full",10.00,0.00,,,0,0,0,0,,,,,31
 from:
 6110s352,"1980 Thistles","In Stock",6110s352,0,"Sets, SS, FDC","C 867-869","S 745-747",0.73,0.98,0.73,0.63,1,1,1,1,,,,,2
 This code should at minimum be able to add the BTItemDetails sheet info so it looks like this:
 6110t352_01,"1980 Thistles- Full sheet (#1/3) [Pl.No.587(1960+) Format=(3x5)] Designer A.Glaser",Unavailable,6110s352,0,"(X)Full Sheets","C 867full","S 745full",10.00,0.00,,,0,0,0,0,,,,,31
 6110t352_02,"1980 Thistles- Full sheet (#2/3) [Pl.No.588(1960+) Format=(3x5)] Designer A.Glaser",Unavailable,6110s352,0,"(X)Full Sheets","C 868full","S 746full",10.00,0.00,,,0,0,0,0,,,,,31
 6110t352_03,"1980 Thistles- Full sheet (#3/3) [Pl.No.589(1960+) Format=(3x5)] Designer A.Glaser",Unavailable,6110s352,0,"(X)Full Sheets","C 869full","S 747full",10.00,0.00,,,0,0,0,0,,,,,31


 The tasks involved:
 Modify (or create) a family of 6110t full sheet entries for each 6110s set which is not a Souvenir Sheet:
    For set cardinality N, create N entries modifying the fields from the original
        id: change 's' to 't' and add suffix "_nn" where nn goes from '01' to '0N' or 'NN' (if N>=10)
        pictid: set equal to 6110s id
        group: set to "(X)Full Sheets"
        cat1,cat2: After every individual cat item, add the word "full" (my convention)
 */

let CATEG_SHEETS:Int16 = 31
class U7Task: NSObject, UtilityTaskRunnable {
    
    var task: UtilityTask! {
        didSet {
            // set up the proxy once we know the object's reference
            task.reportedTaskUnits = TU
            task.isEnabled = isEnabled
            task.taskName = taskName
            // protocol: set initial taskUnits to non-0 if we have work, 0 if we don't (database category empty)
            task.taskUnits = task.countCategories([CATEG_SHEETS])
        }
    }
    
    let TU:Int64 = 35000 // generate this as approx msec execution time on my device; only relative size matters
    // protocol: UtilityTaskRunnable
    var isEnabled = false
    var taskName: String { return "UT2017_07_20_MODIFY_EXISTING_FULL_SHEETS" }
    
    private weak var runner: UtilityTaskRunner! // prevent circular refs, we're in each other's tables
    
    // MARK: Task data and functions
    func run() -> String {
        return ""
    }
}

class U8Task: NSObject, UtilityTaskRunnable {
    
    var task: UtilityTask! {
        didSet {
            // set up the proxy once we know the object's reference
            task.reportedTaskUnits = TU
            task.isEnabled = isEnabled
            task.taskName = taskName
            // protocol: set initial taskUnits to non-0 if we have work, 0 if we don't (database category empty)
            // NOTE: this will be way off, so a better estimate method should be designed
            // We want to count how many unique 6110t entries there are, ignoring the "_NN" part,
            // and subtract this from the number of 6110s entries (ignoring S/S but that's probably a small adjustment)
            // Alternatively, if we could count on bulk BTItemDetails, we could use the set cardinality concept.
            //   This basically counts plate numbers OR (if none) uses indications in the description (see Stand-by issues)
            //   These would include a number in parens at the end of the string, e.g. "(5)" or "Coins 5)", indicating 5 items
            //   Several times the denominations are listed, separated by spaces, e.g. "10 20 50" for 3 values
            // NOTE: This would still require a table of exceptions for issues like Songbirds or Anemone (no pl.nos.)
            task.taskUnits = task.countCategories([CATEG_SETS])
        }
    }
    
    let TU:Int64 = 35000 // generate this as approx msec execution time on my device; only relative size matters
    // protocol: UtilityTaskRunnable
    var isEnabled = false
    var taskName: String { return "UT2017_07_20_ADD_MISSING_FULL_SHEETS" }
    
    private weak var runner: UtilityTaskRunner! // prevent circular refs, we're in each other's tables
    
    // MARK: Task data and functions
    func run() -> String {
        return ""
    }
}
