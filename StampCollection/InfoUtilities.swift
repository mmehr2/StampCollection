//
//  InfoUtilities.swift
//  StampCollection
//
//  Created by Michael L Mehr on 5/2/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//
// functions to help deal with understanding the basic components of DealerItem, the component of INFO (L1)
// See documentation in README.md for the project.

import Foundation

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
    if let match = descr.range(of: "[0-9][0-9][0-9][0-9]\\.[0-9][0-9]\\.[0-9][0-9]$", options: .regularExpression) {
        fmtFound = 11 // which is YYYY.MM.DD at the END of the description; this is from Folders and Bulletins (cat.29,30), Morgenstein format
        // this MUST precede format 1,2 finds, because these strings always start with a YYYY date as well
        // if this is found in another category, it is probably mistaken (but let's see what happens)
        // in this format the size of DD and YY is always 2, since leading zeroes are used
        found = descr.substring(with: match)
        let dmy = found.components(separatedBy: ".")
        let yyyy = Int(dmy[0])!
        startYear = yyyy;
        endYear = startYear
        let mm = Int(dmy[1])!
        startMonth = mm;
        endMonth = startMonth
        let dd = Int(dmy[2])!
        startDay = dd;
        endDay = startDay
    }
    else if let match = descr.range(of: "^[0-9][0-9][0-9][0-9][s ]", options: .regularExpression) {
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
