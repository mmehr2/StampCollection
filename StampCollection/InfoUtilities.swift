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

fileprivate let monthEnds = [ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 ]
func endDayOfMonth(_ mm: Int) -> Int {
    guard mm >= 1 && mm <= 12 else {
        return 31
    }
    return monthEnds[mm-1]
}

func extractDateRangesFromDescription( _ descr: String ) -> (Int, ClosedRange<Date>) {
    // NOTE: these defaults are picked to prevent a crash if no date exists in the input descr
    var fmtFound = 0
    var startYear = 1948
    var endYear = 1948
    var found = ""
    //var descr2 = "" // DEBUG
    var startMonth = 1
    var startDay = 1
    var endMonth = 1
    var endDay = 1
    // begin testing here; order of tests IS IMPORTANT
    if let match = descr.range(of: "[0-9][0-9][0-9][0-9]\\.[0-9][0-9]?\\.[0-9][0-9]?$", options: .regularExpression) {
        fmtFound = 11 // which is YYYY.MM.DD at the END of the description; this is from Folders and Bulletins (cat.29,30), Morgenstein format
        // this MUST precede format 1,2 finds, because these strings always start with a YYYY date as well
        // if this is found in another category, it is probably mistaken (but let's see what happens)
        // in this format the size of DD and YY is always 2, since leading zeroes are used
        found = descr.substring(with: match)
        let dmy = found.components(separatedBy: ".")
        let yyyy = Int(dmy[0])!
        startYear = yyyy
        endYear = startYear
        let mm = Int(dmy[1])!
        startMonth = mm
        endMonth = startMonth
        let dd = Int(dmy[2])!
        startDay = dd
        endDay = startDay
    }
    else if let match = descr.range(of: "^[0-9][0-9]?\\.[0-9][0-9]?\\.[0-9][0-9][0-9][0-9]\\-[0-9][0-9]?\\.[0-9][0-9]?\\.[0-9][0-9][0-9][0-9]", options: .regularExpression) {
        fmtFound = 14 // which is dd.mm.yyyy-DD.MM.YYYY
        found = descr.substring(with: match)
        let dmy = found.components(separatedBy: ".")
        let yyyy2 = Int(dmy[4])!
        endYear = yyyy2
        let mm2 = Int(dmy[3])!
        endMonth = mm2
        let yyyydd = dmy[2].components(separatedBy: "-")
        let yyyy = Int(yyyydd[0])!
        startYear = yyyy
        let dd2 = Int(yyyydd[1])!
        endDay = dd2
        let mm = Int(dmy[1])!
        startMonth = mm
        let dd = Int(dmy[0])!
        startDay = dd
    }
    else if let match = descr.range(of: "^[0-9][0-9]?\\.[0-9][0-9]?\\.[0-9][0-9]\\-[0-9][0-9]?\\.[0-9][0-9]?\\.[0-9][0-9]", options: .regularExpression) {
        fmtFound = 15 // which is dd.mm.yy-DD.MM.YY
        found = descr.substring(with: match)
        let dmy = found.components(separatedBy: ".")
        let yy2 = Int(dmy[4])!
        endYear = yy2 + fixupCenturyYY(yy2)
        let mm2 = Int(dmy[3])!
        endMonth = mm2
        let yydd = dmy[2].components(separatedBy: "-")
        let yy = Int(yydd[0])!
        startYear = yy + fixupCenturyYY(yy)
        let dd2 = Int(yydd[1])!
        endDay = dd2
        let mm = Int(dmy[1])!
        startMonth = mm
        let dd = Int(dmy[0])!
        startDay = dd
    }
    else if let match = descr.range(of: "^[0-9][0-9]?\\.[0-9][0-9]?\\-[0-9][0-9]?\\.[0-9][0-9]?\\.[0-9][0-9][0-9][0-9]", options: .regularExpression) {
        fmtFound = 12 // which is dd.mm-DD.MM.YYYY
        found = descr.substring(with: match)
        let dmy = found.components(separatedBy: ".")
        let yyyy = Int(dmy[3])!
        startYear = yyyy
        endYear = startYear
        let mm2 = Int(dmy[2])!
        endMonth = mm2
        let ddmm = dmy[1].components(separatedBy: "-")
        let mm = Int(ddmm[0])!
        startMonth = mm
        let dd2 = Int(ddmm[1])!
        endDay = dd2
        let dd = Int(dmy[0])!
        startDay = dd
    }
    else if let match = descr.range(of: "^[0-9][0-9]?\\.[0-9][0-9]?\\-[0-9][0-9]?\\.[0-9][0-9]?\\.[0-9][0-9]", options: .regularExpression) {
        fmtFound = 13 // which is dd.mm-DD.MM.YY
        found = descr.substring(with: match)
        let dmy = found.components(separatedBy: ".")
        let yy = Int(dmy[3])!
        startYear = yy + fixupCenturyYY(yy)
        endYear = startYear
        let mm2 = Int(dmy[2])!
        endMonth = mm2
        let ddmm = dmy[1].components(separatedBy: "-")
        let mm = Int(ddmm[0])!
        startMonth = mm
        let dd2 = Int(ddmm[1])!
        endDay = dd2
        let dd = Int(dmy[0])!
        startDay = dd
    }
    else if let match = descr.range(of: "^[0-9][0-9][0-9][0-9][s ]", options: .regularExpression) {
        found = descr.substring(with: match)
        let yyyy = Int(String(found.characters.prefix(4)))!        //let yyyy = Int(found[0...3])!
        startYear = yyyy
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
    else if let match = descr.range(of: "^[0-9][0-9]?\\.[0-9][0-9]?\\.[0-9][0-9][0-9][0-9]", options: .regularExpression) {
        fmtFound = 5 // which is DD.MM.YYYY - this MUST precede the format 4 YY counterpart, which would match all of these strings too
        found = descr.substring(with: match)
        let dmy = found.components(separatedBy: ".")
        let yyyy = Int(dmy[2])!
        startYear = yyyy
        endYear = startYear
        let mm = Int(dmy[1])!
        startMonth = mm
        endMonth = startMonth
        let dd = Int(dmy[0])!
        startDay = dd
        endDay = startDay
    }
    else if let match = descr.range(of: "^-[-]?\\.[0-9][0-9]?\\.[0-9][0-9][0-9][0-9]", options: .regularExpression) {
        fmtFound = 16 // which is -.MM.YYYY - this MUST precede its YY counterpart, which would match all of these strings too
        found = descr.substring(with: match)
        let dmy = found.components(separatedBy: ".")
        let yyyy = Int(dmy[2])!
        startYear = yyyy
        endYear = startYear
        let mm = Int(dmy[1])!
        startMonth = mm
        endMonth = startMonth
        startDay = 1
        endDay = endDayOfMonth(startMonth)
    }
    else if let match = descr.range(of: "^[0-9][0-9]?\\.[0-9][0-9]?\\.[0-9][0-9]", options: .regularExpression) {
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
    else if let match = descr.range(of: "^[0-9][0-9]?\\-[0-9][0-9]?\\.[0-9][0-9]?\\.[0-9][0-9][0-9][0-9]", options: .regularExpression) {
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
    else if let match = descr.range(of: "^[0-9][0-9]?\\-[0-9][0-9]?\\.[0-9][0-9]?\\.[0-9][0-9]", options: .regularExpression) {
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
    // this code will prevent crashes, but points up the real limitations of this data format
//    var swapY = false
//    var dmy = ""
//    if startYear > endYear { swap(&startYear, &endYear); swapY = true; dmy += "Y" }
//    if startMonth > endMonth { swap(&startMonth, &endMonth); swapY = true; dmy += "M" }
//    if startDay > endDay { swap(&startDay, &endDay); swapY = true; dmy += "D" }
//    // TBD: invent a proper date range format to use, and replace this
//    if swapY {
//        print("Swapped date range! \(dmy)")
//    }
    if let d1 = Date(gregorianString: "\(startYear).\(startMonth).\(startDay)"),
        let d2 = Date(gregorianString: "\(endYear).\(endMonth).\(endDay)") {
        return (fmtFound, d1...d2)
    } else {
        return (0, Date(gregorianString: "1948.1.1")!...Date(gregorianString: "1948.1.1")!)
    }
}

fileprivate let dtests : [String: (Int, String, String)] = [
    // in no particular order...
    "1985 Tester": (1, "1985.1.1", "1985.12.31"),//
    "1985 Tester 2005.06.03": (11, "2005.6.3", "2005.6.3"),
    "1985 Tester 2005.6.3": (11, "2005.6.3", "2005.6.3"),
    "1980s Tester": (2, "1980.1.1", "1989.12.31"),
    "2001-2002 Tester": (3, "2001.1.1", "2002.12.31"),
    "1887-1987 Marc Chagall Centennary": (3, "1987.1.1", "1987.12.31"),
    //"": (5, yy...yy, mm...mm, dd...dd), // DD.MM.YYYY
    "29.11.2003 Tester": (5, "2003.11.29", "2003.11.29"),//2003...2003, 11...11, 29...29),
    "9.11.2003 Tester": (5, "2003.11.9", "2003.11.9"),//2003...2003, 11...11, 9...9),
    "29.3.2003 Tester": (5, "2003.3.29", "2003.3.29"),//2003...2003, 3...3, 29...29),
    "09.11.2003 Tester": (5, "2003.11.9", "2003.11.9"),//2003...2003, 11...11, 9...9),
    "29.03.2003 Tester": (5, "2003.3.29", "2003.3.29"),//2003...2003, 3...3, 29...29),
    //"": (4, yy...yy, mm...mm, dd...dd), // DD.MM.YY
    "29.11.03 Tester": (4, "2003.11.29", "2003.11.29"),//2003...2003, 11...11, 29...29),
    "9.11.03 Tester": (4, "2003.11.9", "2003.11.9"),//2003...2003, 11...11, 9...9),
    "29.3.03 Tester": (4, "2003.3.29", "2003.3.29"),//2003...2003, 3...3, 29...29),
    "09.11.03 Tester": (4, "2003.11.9", "2003.11.9"),//003...2003, 11...11, 9...9),
    "29.03.03 Tester": (4, "2003.3.29", "2003.3.29"),//2003...2003, 3...3, 29...29),
    //"": (6, yy...yy, mm...MM, dd...DD), // dd-DD.MM.YYYY
    "22-29.11.2003 Tester": (6, "2003.11.22", "2003.11.29"),//2003...2003, 11...11, 22...29),
    "9-13.11.2003 Tester": (6, "2003.11.9", "2003.11.13"),//2003...2003, 11...11, 9...13),
    "09-14.11.2003 Tester": (6, "2003.11.9", "2003.11.14"),//2003...2003, 11...11, 9...14),
    "3-29.03.2003 Tester": (6, "2003.3.3", "2003.3.29"),//2003...2003, 3...3, 3...29),
    "03-29.03.2003 Tester": (6, "2003.3.3", "2003.3.29"),//2003...2003, 3...3, 3...29),
    //"": (7, yy...yy, mm...MM, dd...DD), // dd-DD.MM.YY
    "22-29.11.03 Tester": (7, "2003.11.22", "2003.11.29"),//2003...2003, 11...11, 22...29),
    "9-13.11.03 Tester": (7, "2003.11.9", "2003.11.13"),//2003...2003, 11...11, 9...13),
    "09-14.11.03 Tester": (7, "2003.11.9", "2003.11.14"),//2003...2003, 11...11, 9...14),
    "3-29.03.03 Tester": (7, "2003.3.3", "2003.3.29"),//2003...2003, 3...3, 3...29),
    "03-29.03.03 Tester": (7, "2003.3.3", "2003.3.29"),//2003...2003, 3...3, 3...29),
    //"": (8, yy...yy, mm...MM, dd...DD), // 'YY preceded by space, anywhere in string
    "Real '85 Tester": (8, "1985.1.1", "1985.12.31"),//1985...1985, 1...12, 1...31),
    "Real '48 Tester": (8, "1948.1.1", "1948.12.31"),//1948...1948, 1...12, 1...31),
    "Real '47 Tester": (8, "2047.1.1", "2047.12.31"),//2047...2047, 1...12, 1...31),
    //"": (9, yy...yy, mm...MM, dd...DD), // YY' preceded by space, anywhere in string
    "Real 85' Tester": (9, "1985.1.1", "1985.12.31"),//1985...1985, 1...12, 1...31),
    "Real 48' Tester": (9, "1948.1.1", "1948.12.31"),//1948...1948, 1...12, 1...31),
    "Real 47' Tester": (9, "2047.1.1", "2047.12.31"),//2047...2047, 1...12, 1...31),
    //"": (10, yy...yy, mm...MM, dd...DD), // which is 'Date DDMMYY', anywhere in string (also accepts 1st letter LC
    "Intense date 010577 Tester": (10, "1977.5.1", "1977.5.1"),//1977...1977, 5...5, 1...1),
    "Intense Date 010577 Tester": (10, "1977.5.1", "1977.5.1"),//1977...1977, 5...5, 1...1),
    // new format 12: overlapping months dd.mm-DD.MM.YYYY
    //"13.3-9.11.2003 Tester": (12, yy...yy, mm...MM, dd...DD), // dd.mm-DD.MM.YYYY
    // NOTE: This points up a total inadequacy of the date representation used
    // Ranges must always be ordered m<=n for m...n
    // However date ranges of the form 13.3-9.11.2000 have to be ordered M=3...11 but D=9...13, which is Mar 9-Nov 13, NOT Mar 13-Nov 9 as originally stated (else the range of days will crash) - same with the months and prob years too
    // consider Dec 31, 1999 - Jan 1, 2000 in dd.mm.yy-DD.MM.YY format - years will be fine, but days and months will crash
    "22.11-29.12.2003 Tester": (12, "2003.11.22", "2003.12.29"),//2003...2003, 11...12, 22...29),
    "9.3-13.11.2003 Tester": (12, "2003.3.9", "2003.11.13"),//2003...2003, 3...11, 9...13),
    "09.3-13.11.2003 Tester": (12, "2003.3.9", "2003.11.13"),//2003...2003, 3...11, 9...13),
    // new format 13: overlapping months dd.mm-DD.MM.YY (2-digit year variant)
    "22.11-29.12.03 Tester": (13, "2003.11.22", "2003.12.29"),//2003...2003, 11...12, 22...29),
    "9.3-13.11.03 Tester": (13, "2003.3.9", "2003.11.13"),//2003...2003, 3...11, 9...13),
    "09.3-13.11.03 Tester": (13, "2003.3.9", "2003.11.13"),//2003...2003, 3...11, 9...13),
    // new format 14 - full dd.mm.yyyy-DD.MM.YYYY range
    "9.3.2001-13.11.2003 Tester": (14, "2001.3.9", "2003.11.13"),//2001...2003, 3...11, 9...13),
    "09.03.2001-13.11.2003 Tester": (14, "2001.3.9", "2003.11.13"),//2001...2003, 3...11, 9...13),
    // new format 15 - full dd.mm.yy-DD.MM.YY range (year variant)
    "9.3.01-13.11.03 Tester": (15, "2001.3.9", "2003.11.13"),//2001...2003, 3...11, 9...13),
    "09.03.01-13.11.03 Tester": (15, "2001.3.9", "2003.11.13"),//2001...2003, 3...11, 9...13),
    // now that we have fixed the date bug above, here are tests for the split date ranges that test this
    "29.11-2.12.2003 Tester": (12, "2003.11.29", "2003.12.2"),//2003...2003, 11...12, 29...2(crash!),
    "13.3-9.11.2003 Tester": (12, "2003.3.13", "2003.11.9"),//2003...2003, 3...11, 13...9(crash!),
    "13.3-09.11.2003 Tester": (12, "2003.3.13", "2003.11.9"),//2003...2003, 3...11, 13...9(crash!),
    "This string has no date": (0, "1948.1.1", "1948.1.1"),
    "-.12.1977 Info details of 6110s320": (16, "1977.12.01", "1977.12.31"), // stolen from 6110s320 (1977 0.75 StandBy)
    "--.6.1992 Tester": (16, "1992.06.01", "1992.06.30"),
]

func UnitTestDateRanges() {
    var count = 0
    var pc = 0
    var fc = 0
    var result = ""
    var failed = false
    
    for (test, answer) in dtests {
        result = ""
        failed = false
        result += ("Test #\(count+1): Range to String of [\(test)] to [\(answer)]")
        let cand = extractDateRangesFromDescription(test)
        let (f, str1, str2) = answer
        if let d1 = Date(gregorianString: str1), let d2 = Date(gregorianString: str2), d1 <= d2 {
            let anscvt = (f, d1...d2)
            if cand == anscvt { result += ("PASSED"); pc += 1 } else { result += ("FAILED: \(cand)"); fc += 1; failed = true }
        } else { result += ("FAILED(bad pgmg): \(cand) for \(str1) <= \(str2)"); fc += 1; failed = true }
        count += 1
        if failed {
            print(result)
        }
    }
    print("Performed \(count) DateRange parse unit tests: \(pc) passed, \(fc) failed.")
}

// Functions dealing with numeric ranges (ignoring literal suffixes for now)
typealias XlationRange = Int // hope to make this generic when I learn how
func translateNumberToRange(_ input: String) -> CountableClosedRange<XlationRange>? {
    // accepts numeric strings of a single number "N"
    // returns the range N...N
    // accepts numeric strings of two single numbers "M-N"
    // returns the range M...N, where N is adjusted so it is >= M
    let comps = input.components(separatedBy: "-")
    if comps.count > 2 || comps.count == 0 {
        return nil
    }
    // also want to weed out non-numeric subparts for now
    let first = comps.first!
    let numstr = String(first.characters.filter{getCharacterClass($0) == .numeric})
    if numstr != first {
        return nil
    }
    // first part OK: convert to int
    let m = XlationRange(first)!
    if comps.count == 1 {
        // if only one part, return it as a complete range
        return m...m
    }
    let second = comps[1]
    let numstr2 = String(second.characters.filter{getCharacterClass($0) == .numeric})
    if numstr2 != second {
        return nil
    }
    var n = XlationRange(second)!
    if m > n {
        // string could have been like 120-4 or 120-24, or even 1234-5 oe 1234-42 or 1234-311
        // we want to parse individual characters of the input to compensate, I believe
        // we have access to comps0 and comps1 characters individually
        // basically, to get N', we substitute the last len(N) digits of M with 0's and add the resulting number to N
        let lenM = first.characters.count
        let lenN = second.characters.count
        let diffN = lenM - lenN
        if diffN == 0 {
            return nil
        } // disallow items of form 234-223 or 29-12 where a range cannot be formed
        // ALT: we could just swap M and N to get the range, hmmm, no too hard to get decent input
        let part1 = String(first.characters.prefix(diffN))
        let part2 = String("00000".characters.suffix(lenN))
        let factor = XlationRange(part1 + part2)!
        n += factor
    }
    return m...n
}

func translateNumberListToRanges(_ input: String) -> [CountableClosedRange<XlationRange>] {
    let comps = input.components(separatedBy: ",")
    var result = [CountableClosedRange<XlationRange>]()
    for comp in comps {
        if let rng = translateNumberToRange(comp) {
            result += [ rng ]
        }
    }
    return result
}

// outputs a string with all the numbers listed in the numeric range, separated by spaces
func printRange(_ input: CountableClosedRange<XlationRange>) -> String {
    let result = input.flatMap{String($0)}.joined(separator: " ")
    return result
}

// outputs a single string formed from multiple ranges of numbers
func printRanges(_ input: [CountableClosedRange<XlationRange>]) -> String {
    let result = input.map{printRange($0)}.joined(separator: " ")
    return result
}

// in order to handle suffixes and other string-based entities in the list, we provide a better function
// if a number component ("2-4" or "12a") isn't convertible to a range, it passes through as-is
func expandNumberList(_ input: String) -> String {
    let comps = input.components(separatedBy: ",")
    var result = [String]()
    for comp in comps {
        if let range = translateNumberToRange(comp) {
            result.append(printRange(range))
        } else {
            result.append(comp)
        }
    }
    let endresult = result.joined(separator: " ")
    return endresult
}

// parse tests: to see if the right range (or nil) can be created from the left string
fileprivate let tests = [
    "1": 1...1,
    "1m": nil,
    "13": 13...13,
    "10-15": 10...15,
    "11-5": 11...15,
    "19-23": 19...23,
    "32-19": nil,
    "123-4": 123...124,
    "1123-4": 1123...1124,
    "136-8": 136...138,
    "139-42": 139...142,
    "1139-42": 1139...1142,
    "32A-191": nil,
    "32-191x": nil,
]

// print tests: to see if the left string can get created by the right range
fileprivate let rtests = [
    "1": [1...1],
    "123 124": [123...124],
    "1139 1140 1141 1142": [1139...1142],
    "1 2 3 5 6 7 8": [1...3, 5...8]
]

func UnitTestRanges() {
    UnitTestDateRanges()
    var count = 0
    var pc = 0
    var fc = 0
    var result = ""
    var failed = false
    for (answer, test) in tests {
        result = ""
        failed = false
        if let test = test {
            result += ("Test #\(count+1): String to Range of [\(answer)] to [\(test.description)]")
            if let cand1 = translateNumberToRange(answer) {
                if cand1 == test { result += ("PASSED"); pc += 1 } else { result += ("FAILED"); fc += 1; failed = true }
            } else { result += ("FAILED(nil)"); fc += 1; failed = true }
        } else {
            // check for failure
            result += ("Test #\(count): String to Range of \(answer) to nil")
            if let _ = translateNumberToRange(answer) {
                result += ("FAILED"); fc += 1; failed = true
            } else { result += ("PASSED"); pc += 1 }
        }
        if failed {
            print(result)
        }
        count += 1
    }
    for (answer, test) in rtests {
        result = ""
        failed = false
        result += ("Test #\(count+1): Range to String of [\(test.description)] to [\(answer)]")
        let cand = printRanges(test)
        if !cand.isEmpty {
            if cand == answer { result += ("PASSED"); pc += 1 } else { result += ("FAILED"); fc += 1; failed = true }
        } else { result += ("FAILED(empty)"); fc += 1; failed = true }
        count += 1
        if failed {
            print(result)
        }
    }
    print("Performed \(count) Range parse/print unit tests: \(pc) passed, \(fc) failed.")
}
