//
//  ViewUtilities.swift
//  StampCollection
//
//  Created by Michael L Mehr on 4/25/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import UIKit

func getDateFromFormattedString(input: String) -> NSDate {
    let nf = NSDateFormatter()
    nf.dateStyle = .MediumStyle
    nf.timeStyle = .NoStyle
    return nf.dateFromString(input) ?? NSDate()
}

func getFormattedStringFromDate(input: NSDate, withTime: Bool = false) -> String {
    let nf = NSDateFormatter()
    nf.dateStyle = .MediumStyle
    nf.timeStyle = withTime ? .MediumStyle : .NoStyle
    return nf.stringFromDate(input) ?? ""
}

func messageBoxWithTitle( title: String, andBody body: String, forController vc: UIViewController ) {
    messageBoxWithTitle(title, andBody: body, forController: vc) { ac in
        let act = UIAlertAction(title: "OK", style: .Default) { x in
            // dismiss but do nothing
        }
        ac.addAction(act)
    }
}

func messageBoxWithTitle( title: String, andBody body: String, forController vc: UIViewController, configuration: ((inout UIAlertController) -> Void)? = nil ) {
    var ac = UIAlertController(title: title, message: body, preferredStyle: .Alert)
    if let configHandler = configuration {
        configHandler(&ac)
    }
    vc.presentViewController(ac, animated: true, completion: nil)
}

func formatBTDetail(item: BTDealerItem) -> String {
    var text = "\(item.code)"
    if item.catalog1 != "" {
        text += " [" + item.catalog1
        if item.catalog2 != "" {
            text += ", " + item.catalog2
        }
        text += "]"
    }
    var output = "\(text) - \(item.status): \(item.price1) \(item.price2) \(item.price3) \(item.price4)"
    return output
}

func formatDealerDetail(item: DealerItem) -> String {
    var text = "\(item.id)"
    if item.cat1 != "" {
        text += " [" + item.cat1
        if item.cat2 != "" {
            text += ", " + item.cat2
        }
        text += "]"
    }
    var output = "\(text) - \(item.status): \(item.price1) \(item.price2) \(item.price3) \(item.price4)"
    return output
}

/*
LOCATION:
var albumPage: String
var albumRef: String
var albumSection: String
var albumType: String

BASE ITEM SELECTION:
var baseItem: String
var itemType: String // as "priceN" where N can be 1,2,3, or 4 - Mint[Tab], Used, FDC, Other

CATEGORY:
var catgDisplayNum: Int16

VARIETY, CONDITION:
var desc: String // OPT (identifies variant)
var notes: String // OPT (identifies specific condition)

OTHER ITEM REFERENCE:
var refItem: String // OPT - identifies associated base item code

WANTED vs HAVE-IT:
var wantHave: String // "w" for want list item, "h" for have it in the collection
*/
private func formatInventoryWantField(item: InventoryItem) -> String {
    return item.wantHave == "w" ? "WL/" : ""
}

private func formatInventoryLocation(item: InventoryItem) -> String {
    return "IN \(item.albumRef)p.\(item.albumPage) (S:\(item.albumSection))"
}

private func formatInventoryValue(item: InventoryItem) -> String {
    // determine whether to return
    //  Mint v Used (cat.prices == PU)
    //  Mint(tab) v Used v FDC v Other (PUFS)
    //  Mint v FDC (PF)
    //  "" (P only)
    var output = "Val"
    let baseItem = item.dealerItem
    let cat = baseItem.category
    let price = baseItem.valueForKey(item.itemType) as! String
    switch (cat.prices, item.itemType) {
    case ("P", "price1"): output += ""
    case ("PU", "price1"): output += ":Mint"
    case ("PU", "price2"): output += ":Used"
    case ("PF", "price1"): output += ":Mint"
    case ("PF", "price2"): output += ":FDC"
    case ("PUFS", "price1"): output += ":Mint(tab)"
    case ("PUFS", "price2"): output += ":Used"
    case ("PUFS", "price3"): output += ":OnFDC"
    case ("PUFS", "price4"): output += ":Mint(NT)"
    default: output = ""
    }
    if !output.isEmpty {
        output += "=\(price)" // maybe format this better
    }
    return output
}

func makeStringFit(input: String, length: Int) -> String {
    if count(input) > length-2 {
        return input[0..<length-2] + ".."
    }
    return input
}

private func formatInventoryVarCondition(item: InventoryItem) -> String {
    let variety = item.desc.isEmpty ? "" : makeStringFit("V: \(item.desc)", 40)
    let condct = count(item.notes)
    let condlimited = min(condct, 40)
    let condition = item.notes.isEmpty ? "" : makeStringFit("C: \(item.notes)", 40)
    return "\(variety) \(condition)"
}

func formatInventoryMain(item: InventoryItem) -> String {
    if let cat = CollectionStore.sharedInstance.fetchCategory(item.catgDisplayNum)
        , info = CollectionStore.sharedInstance.getInfoItem(item.baseItem) {
            let basedes = makeStringFit(info.descriptionX, 60)
            return "\(basedes) \(formatInventoryWantField(item)) \(formatInventoryLocation(item))"
    }
    return "\(formatInventoryWantField(item)) \(formatInventoryLocation(item))"
}

func formatInventoryDetail(item: InventoryItem) -> String {
    return "\(item.baseItem) \(formatInventoryValue(item)) \(formatInventoryVarCondition(item))"
}

extension CollectionStore.DataType : Printable {
    
    var description : String {
        switch self {
        case .Categories: return "Categories"
        case .Info: return "Info"
        case .Inventory: return "Inventory"
        }
    }
    
}

// following was stolen from: http://stackoverflow.com/questions/24092884/get-nth-character-of-a-string-in-swift-programming-language
extension String {
    
    subscript (i: Int) -> Character {
        return self[advance(self.startIndex, i)]
    }
    
    subscript (i: Int) -> String {
        return String(self[i] as Character)
    }
    
    subscript (r: Range<Int>) -> String {
        return substringWithRange(Range(start: advance(startIndex, r.startIndex), end: advance(startIndex, r.endIndex)))
    }
}

// NOTES ON CODE PARSING SPECIAL CASES BY CATEGORY
/*
2/Sets 6110s
- just numeric (?? REALLY??)
3/Booklets 6110b or 6110e
- for 6110b there is an s prefix that should be sorted at top (before other b #s); max.number is 19
- there is one PR prefix that appears in the middle here (before 6110e)
*M)- uses 6110e needing missing digit fixup if 3-digit number followed by nonempty alpha suffix
9/Show cards 6110x
- just numeric
12/Reply coupons ILrc
- numeric with opt.LC suffix (single letter)
13/Joint 6110j
*M2)- needs missing digit fixup if 3-digit number followed by nonempty alpha suffix NOT starting with 'x'
- suffixes containing x (after numeric suffix) have multiletter UC code addition w opt numeric and letter suffix e.g. 6110j142ExJFDC2
14/Maxi cards 6110m
- normal listing has suffix 'ip'
- packet of 20 diff is missing suffix and must sort to end of cat
15/Defense Ministry 6110d
- just numeric
16/New Year cards 6110n
**Y)- 1st field is YY (2-digit numeric) representing year in need of century fixup
- opt 'n' suffix for national card (same year) should sort after
19/Postal bank 6110pb
- only two exist, although full sheets should be added (saw set on Sam Adicoff's eBay site)
20/Postal stationery ps
- 1st field alpha is: AL, IL, IE, PC (in order! - NOT alphabetic yet)
-- AL has two subsections, govt and Ministry of Tourism (code #s after 100)
- sort each subcat numerically within, except...
**X)- PC with suffix 'm' must sort all the way at end after PC with other ('a','bk' exist) or missing suffix
21/Revenue 6110r
- just numeric
22/Souv.Folders 6110h
- numeric with single letter suffix (LC)
- my additions are numbered after 2000
- possible subcats numbered after 300, 400, 500, 700 (see category Notes from BT site)
23/Souv.Leaves 6110l (that's a lower case L)
- numeric as Carmel Catalog number (disjoint) with opt UC single letter suffix A,B,...
- when no catalog assigned, uses 'ne' prefix with numeric field 1-10+ (TEMPORARY - will later be assigned by BT after Carmel updates)
24/Sheetlets,Combinations 6110e
*M)- uses 6110e needing missing digit fixup if 3-digit number followed by nonempty alpha suffix (see cat.3 and 25)
-- numbers dovetail in between s numbers (cat.2) usually
- if prefix (alpha) is nonempty, indicates the subcat for preprinted generic sheets e.g. 6110eJET for Jetix, etc.
-- these sort after the plain (no prefix) items
25/Varieties 6110e
- numeric w opt suffix (LC or UC)
*M)- uses 6110e needing missing digit fixup if 3-digit number followed by nonempty alpha suffix (see cat.3 and 25)
26/Vending 6110k
- base is format 6110kYYNN where
*Y3)-- YY represents year in need of century fixup (2 to 4 digit format)
-- NN is item within year, normalize to 2 digits (unless we ever think we'll get 100 or more sets a year!) then concatenate
-> opt RC field for rate changes may have both numeric and letter suffixes
-- RC (1st or only rate change in year), RC2 (second), RC1 (1st RC in blue ink), RC1B (RC1 black print variety)
- opt additional suffix for my extensions: 'bl' is blanco, 'mNNN' is machine number set where NNN is numeric sorted
- two special items sort at end - 6110k9k and 6110k30, in that order - both have "Represent" at start of descr. - represents packets/sets
27/Year sets 6110y
- numeric with two formats: YY and YYYY
**Y)-- for YY, needs a single-year fixup to 4-digit format
*Y2)-- for YYYY, each pair represents a year string for individual 4-digit fixup and then concatenation into 8-digit string format YYYYZZZZ
28/Austrian AUI
- numeric but with optional ".1" suffix (could be treated as a double, but suffix notation works)
-- numbers are always 3 digits padded with leading zeroes (only 54 sets, so there's always one 0)
29/Info folders fe
- from Morgenstin catalog scan
- often in a dual-number form e.g. fe0016/0017, which should sort after fe0016
-- this will probably sort fine with split at the '/'; check it
- optional single letter UC suffix 'A', can be assigned to entire dual format
30/Info bulletins bu
- simple numeric with optional single letter LC suffix
31/Full sheets 6110t (those not covered by BT in cat.24)
- simple numeric with optional suffix of form "_NN" where N is cardinal sequence # in set of >1 value
- should sort fine as split fields
*/

enum CodeFieldClass { case Unknown, Alpha, Numeric }

extension CodeFieldClass: Printable {
    var description: String {
        switch self {
        case .Numeric: return "num"
        case .Alpha: return "alp"
        default: break
        }
        return "unk"
    }
}

private func getClass( ch: Character ) -> CodeFieldClass {
    // assumes old-style ASCII - okay for what I have used so far
    if ch >= "0" && ch <= "9" {
        return .Numeric
    }
    return .Alpha
}

func splitDealerCode( code: String, special: Bool = false ) -> [String] {
    // accepts code numbers of the following forms:
    //  "6110xNNNyy"
    //  "psNNNyy"
    // splits them into fields of homogenous type (alpha or numeric)
    var output: [String] = []
    var field = ""
    var state: CodeFieldClass = .Unknown
    for char in code {
        let charClass = getClass(char)
        if special {
            // detect field == "RC" and wait until "m" is detected, accumulating digits and suffixes into field
            if count(field) >= 2 && field[0...1] == "RC" {
                if char != "m" {
                    field.append(char)
                    continue
                }
                state = .Numeric // even if RC ends in a non-digit
            }
        }
        if charClass != state {
            // save old field if not 1st time
            if state != .Unknown {
                output.append(field)
            }
            // creat new field from char
            field = ""
            state = charClass
        }
        // in any case, append char to field
        field.append(char)
    }
    // when exiting, there should be one unsaved field
    output.append(field)
    return output
}

private func splitCatCode( code: String, forCat catnum: Int16 ) -> (String, String) {
    let firstCharClass = getClass(code[0])
    let shorthand = code[0...1]
    let splitAt: Int
    if firstCharClass == .Numeric {
        // assumes 6110z where z is single character alpha
        if code[0...5] == "6110pb" {
            splitAt = 6
        } else {
            splitAt = 5
        }
    } else if shorthand == "IL" {
        // assumes 4-digit alpha (ILrc)
        splitAt = 4
    } else if shorthand == "AU" {
        // assumes 3-digit alpha (AUI)
        splitAt = 3
    } else {
        // assumes 2-digit alpha (ps, fe, bu)
        splitAt = 2
    }
    let len = count(code)
    let part1 = code[0..<splitAt]
    let part2 = code[splitAt..<len]
    return (part1, part2)
}

func padIntegerString( input: Int, toLength outlen: Int) -> String {
    var fmt = NSNumberFormatter()
    fmt.paddingCharacter = "0"
    fmt.minimumIntegerDigits = outlen
    fmt.maximumIntegerDigits = outlen
    fmt.allowsFloats = false
    fmt.minimumFractionDigits = 0
    fmt.maximumFractionDigits = 0
    return fmt.stringFromNumber(input) ?? ""
}

func padDoubleString( input: Double, toLength outlen: Int, withFractionDigits places: Int = 2) -> String {
    var fmt = NSNumberFormatter()
    fmt.paddingCharacter = "0"
    fmt.minimumIntegerDigits = outlen
    fmt.maximumIntegerDigits = outlen
    fmt.allowsFloats = true
    fmt.minimumFractionDigits = places
    fmt.maximumFractionDigits = places
    return fmt.stringFromNumber(input) ?? ""
}

func normalizeCatCode( codePart: String, forCat catnum: Int16 ) -> String {
    return "NCAT" + padIntegerString(Int(catnum), toLength: 4)
}

private func paddington( len: Int, input: String, char: Character = " ", trailing: Bool = false ) -> String {
    let inlen = count(input)
    if inlen >= len {
        return input
    }
    var output = trailing ? input : ""
    // add specified number of padding characters
    for _ in 0..<(len-inlen) {
        output.append(char)
    }
    if !trailing {
        output += input
    }
    return output
}

/*
SHORTHAND RULES:
Needing YY fixups:
16 = 6110n YY [s] - create 4 digit YYYY
26 = 6110k YYNN [RC 1 B] [bl] [m NNN] - create 6 digit YYYYNN
27 = 6110y YY - create 4 digit YYYY *OR*
= 6110y YYZZ - create 8 digit YYYYZZZZ
Needing M fixups:
3 = 6110e NNN s where 1st N can be 0...3 (but NOT 6110e NNN plain or with suffix) hmmmmm... ONLY NEED THIS AFTER e1000 happens
13= 6110j NNN s (complicated by x suffixes?)
24= 6110e NNN s same as 3
25= 6110e NNN s same as 3
Needing special handling:
3 = 6110b s N should sort BEFORE 6110b NN (empty prefix)
14 = 6110m NN ip sort before 6110m NN (no suffix) or with other suffix
20 = psPC NN must sort before psPC NN m (m suffix)
21 = 6110r NN p must sort after all others
26 = 6110k 9 k sorts after all, exc 6110k 30 (final one)
*/
// TBD: NEED TO REMOVE HARDCODED CATEGORY NUMBERS!! WHAT IF BT RENUMBERS? (IT ALREADY DID)
func normalizeIDCode( code: String, forCat catnum: Int16, isPostE1K: Bool = false ) -> String {
    let (catcode, rest) = splitCatCode(code, forCat: catnum)
    let normcat = normalizeCatCode(catcode, forCat: catnum)
    let lenrest = count(rest)
    let finrest = lenrest < 2 ? "  " : rest[lenrest-2...lenrest-1]
    let fields = splitDealerCode(rest, special: catnum == 26) // special handling invoked for Vending category 6110kNNNRC[..]mMMM case
    let data = fields.map { x in
        (normcat, catcode, x, getClass(x[0]))
    }
    //println("Data for normID \(data)")
    var output = ""
    var fieldnum = 0
    var skip = false
    let numFields = data.count
    let padder : Character = "-"
    for (normcat, catcode, field, fieldClass) in data {
        if output.isEmpty {
            output += normcat
            // special handling for sorting items at end
            if catnum == 14 && finrest != "ip" {
                // special handling for  Max Cards (cat 14)
                // if the last field isn't an alpha == "ip", then add an alpha prefix to make it sort after the plan ones
                output += paddington(8, "ZZPACKET", char: padder)
            }
            else if catnum == 20 && rest[0...1] == "PC" && finrest[1] == "m" {
                // special handling for Military Post Cards (cat 20) psPC NNN m
                // if the last field is an alpha == "m", then add an alpha prefix to make it sort after the plan ones
                output += paddington(8, "PC_MIL", char: padder, trailing: true)
                skip = true // prevent the PC from becoming another prefix
            }
            else if catnum == 21 && finrest[1] == "p" {
                // special handling for Revenue (cat 21) 6110r NNN p
                // if the last field is an alpha == "p", then add an alpha prefix to make it sort after the plan ones
                output += paddington(8, "ZZPACKET", char: padder)
            }
            else if catnum == 26 && rest == "9k" {
                // special handling for Vending (cat 26) 6110k 9 k
                output += paddington(8, "ZZPACKET", char: padder)
            }
            else if catnum == 26 && rest == "30" {
                // special handling for Vending (cat 26) 6110k 9 k
                output += paddington(8, "ZZPACKET", char: padder)
            }
            else if catnum == 3 && catcode == "6110b" {
                // special handling for Booklets (cat 26) 6110b s NN to go before 6110b NN [...]
                var prefix = "BOOKLET"
                if rest[0] == "s" {
                    prefix = "_SBKLT"
                    skip = true // prevent the "s" from becoming a prefix field
                }
                if rest[0] == "P" {
                    prefix = "BPRBKLT" // after "BOOKLET" but before "EBOOKLET"
                    skip = true // prevent the "PR" from becoming a prefix field
                }
                output += paddington(8, prefix, char: padder, trailing: true)
            }
            else if catnum == 3 && catcode == "6110e" {
                // special handling for Booklets (cat 26) 6110e [...] to go after 6110b [...]
                output += paddington(8, "EBOOKLET", char: padder)
            }
            else if fieldClass != .Alpha {
                // missing prefix field - normalize by adding empty one
                output += paddington(8, "", char: padder)
            }
        }
        let flen = count(field)
        switch fieldClass {
        case .Alpha: if !skip { output += paddington(8, field, char: padder, trailing: true) }
        case .Numeric:
            var num = field.toInt()!
            // insert YEAR fixups here
            if catnum == 16 {
                num += fixupCenturyYY(num)
            }
            if catnum == 27 && flen == 2 {
                num += fixupCenturyYY(num)
            }
            if catnum == 27 && flen == 4 {
                var num1 = field[0...1].toInt()!
                var num2 = field[2...3].toInt()!
                num1 += fixupCenturyYY(num1) // now between 1948 and 2047
                num2 += fixupCenturyYY(num2) // now between 1948 and 2047
                num = num1 * 10000 + num2
            }
            if catnum == 26 && fieldnum == 0 {
                if field == "9" && finrest == "9k" { num = 99999998 }
                else if field == "30" && finrest == "30" { num = 99999999 }
                else if flen == 2 {
                    // field is a 2-digit year fixup YY
                    num += fixupCenturyYY(num)
                }
                else if flen == 4 {
                    // split YYNN in two to make a 6-digit century fixup field
                    var num1 = field[0...1].toInt()! // YY
                    var num2 = field[2...3].toInt()! // NN
                    num1 += fixupCenturyYY(num1) // now between 1948 and 2047
                    num = num1 * 100 + num2
                }
            }
            // insert Missing-1 Fixups here
            // ASSUMES THAT there is a good cutoff, i.e., if num<500, it's a candidate for missing-1, but not if num>500
            // This depends on the actual earliest category split - in 6110j, that is 595, but in 6110e, it's probably smaller
            // NOTE: 6110e has to deal with the difference between 6110e190A (meaning 190) and 6110e190A (same thing, meaning 1190)
            // To do this, we provide date-related info in the form of the isPostE1K flag (date such that e-numbers over 1000 are likely)
            // 6110j only deals with the cutoff number, since no joint numbers exist before 595 (the s-number of the 1993 Poland joint issue) - FORTUNATELY!
            if fieldnum == 0 && flen == 3 && ((isPostE1K && catcode == "6110e") || catcode == "6110j") {
                let thr = catnum == 13 ? 595 : 350
                if fieldnum + 1 < numFields {
                    let (_, _, nextField, nextFieldClass) = data[fieldnum + 1]
                    if nextFieldClass == .Alpha && nextField[0] != "x" && num < thr {
                        num += 1000
                    }
                }
            }
            output += padIntegerString(num, toLength: 8)
        default: break
        }
        ++fieldnum
        skip = false
    }
    return output
}

func extractDateFromDesc( desc: String) -> String {
    // accepts different description formats:
    // 1) leading year "NNNN non-space-chars", just returns the year
    // 2) leading date (Euro) "DD.MM.YY non-space-chars", returns day month and year
    // 3) trailing date (Euro) "non-space-chars DD.MM.YY", returns day, month, and year
    var output = ""
    return output
}
