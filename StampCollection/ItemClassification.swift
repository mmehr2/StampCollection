//
//  ItemClassification.swift
//  StampCollection
//
//  Created by Michael L Mehr on 9/25/19.
//  Copyright © 2019 Michael L. Mehr. All rights reserved.
//

import Foundation

// DealerItem categories

enum ItemClassification {
    // from CATEG_SETS:
    case Set // set of stamps issued together as a unit at one point in time, usually to commemorate an event or topic
    case DefinitiveSet // set of stamps issued together, but intending to be reprinted on multiple dates
    case SouvenirSheet // this item has no plate number, usually contains one or multiple stamp designs, and has perforations
    // from CATEG_SHEETS and CATEG_SPECIAL_SHEETS
    case Sheet // individual full sheet of commemorative stamps, normal 3x5 layout, no special margins or features, single design, 15s, 5t
    case SheetSet(Int) // same, but set of N full sheets of stamps related by a common set number (6110s)
    case DefinitiveSheet // these are sheets that use menorahs to indicate subsequent printings, usually self-adhesive
    case ImperfSouvenirSheet // sasme as S/S but is imperforated (and usually numbered)
    case ImperfSheet // single sheet, imperforated
    case ImperfSheetSet(Int) // set of imperf sheets related by a common design, usually issued as a unit
    case ImperfDesignerSheet // BAD NAME: basically the gigantic boxed-set sheet of multiple sheets that imperf sets are cut from
}


func extractSheetDetailsFromSheetDescription( _ descr: String ) -> (String) {
    var result = ""
    // get the details string out of a Full Sheet auto-generated description (cat.31)
    // 1. (multi) "1989 Tourism- Full sheet (#1/4) [Pl.No.71 (1986+), Format=(3x5)] Design:O.E. Schwarz"
    // 2. (single) "2004 TELABUL 2004 - 'Design a Stamp'- Full sheet [Pl.No.570 (1986+), Format=(3x5)] Design:Michel Kishka"
    let pnr = descr.components(separatedBy: "- Full sheet ")
    if (pnr.count > 1) {
        // pnr[0] is the main title, while pnr[1] is what we want
        result = pnr[1]
    }
    return result
}
