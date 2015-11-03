//
//  ViewUtilities.swift
//  StampCollection
//
//  Created by Michael L Mehr on 4/25/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import UIKit

// MARK: image downloading
// clever hack from here: http://stackoverflow.com/questions/24231680/swift-loading-image-from-url
// NOTE: had to update it to use NSURLSession() due to iOS9 deprecations
// NOTE: to make this work for IOS9+, need to add stuff to Info.plist from here: http://stackoverflow.com/questions/31254725/transport-security-has-blocked-a-cleartext-http/32560433#32560433
/*
NOTE: THIS IS A HACK! WE REALLY NEED TO CHANGE THINGS TO USE HTTPS: IN THE URLS INSTEAD.. HOW?
<key>NSAppTransportSecurity</key>
<dict>
<key>NSAllowsArbitraryLoads</key>
<false/>
<key>NSExceptionDomains</key>
<dict>
<key>bait-tov.com</key>
<dict>
<key>NSIncludesSubdomains</key>
<true/>
<key>NSTemporaryExceptionAllowsInsecureHTTPLoads</key>
<true/>
<key>NSTemporaryExceptionMinimumTLSVersion</key>
<string>TLSv1.1</string>
</dict>
<key>judaicasales.com</key>
<dict>
<key>NSIncludesSubdomains</key>
<true/>
<key>NSTemporaryExceptionAllowsInsecureHTTPLoads</key>
<true/>
<key>NSTemporaryExceptionMinimumTLSVersion</key>
<string>TLSv1.1</string>
</dict>
</dict>
</dict>
*/
public typealias CompHandler = ((UIImage?) -> Void)
private var completionHandlersForImageTask: [String:CompHandler] = [:]
// a pure URL index is not enough, we get two or three simultaneous requests for the same pic url in real life to different views
// SO.. we need to get a unique hash from the URL and if it's in the table already, we need to extend it until we find one that's not
// this could cause a race too, unless we can insure that the hashing is atomic
// still, it should really only need to test once, or at most twice, so maybe it's okay...
private func installHandler(url: NSURL, completion: CompHandler) -> String {
    var code = url.path!
    repeat {
    guard completionHandlersForImageTask[code] != nil else {
        completionHandlersForImageTask[code] = completion // this is the final case, not in the DB
        print("Installed handler for code \(code)")
        return code
    }
    code += ("X") // try it with another X on the end, until we have a hit
    } while true
}

extension UIImageView {
    public func imageFromUrlString(urlString: String) {
        if let url = NSURL(string: urlString) {
            imageFromUrl(url)
        }
    }
    public func imageFromUrl(url: NSURL?, completion: CompHandler? = nil) {
        if let url = url, completion = completion {
            print("Requesting pic file at \(url)")
            let code = installHandler(url, completion: completion)
            let task = NSURLSession.sharedSession().dataTaskWithURL(url) { (data, response, error) in
                if let error = error {
                    print("Pic data received with error \(error)")
                } else {
                    let image = UIImage(data: data!)
                    print("Pic data received with image \(image)")
                    if let completion = completionHandlersForImageTask[code] {
                        NSOperationQueue.mainQueue().addOperationWithBlock() {
                            completion(image)
                            completionHandlersForImageTask[code] = nil
                            print("Removed handler for code \(code)")
                        }
                    }
                }
            }
            task.resume()
        }
    }
}

// MARK: determine if running on simulator or not (checking if runtime features such as email are available)
func isRunningOnSimulator() -> Bool {
    var result = false
    let devmodel = UIDevice.currentDevice().model
    if devmodel.hasSuffix("Simulator") {
        result = true
    }
    return result
}

func isEmailAvailable() -> Bool {
    return !isRunningOnSimulator()
}

// MARK: UI date formatting services
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

func dateFromComponents( year: Int, month: Int, day: Int ) -> NSDate {
    let gregorian = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
    let comp = NSDateComponents()
    comp.year = year
    comp.month = month
    comp.day = day
    return gregorian.dateFromComponents(comp)!
}

func componentsFromDate( date: NSDate ) -> (Int, Int, Int) { // as Y, M, D
    let gregorian = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
    let comp = gregorian.components(
        [NSCalendarUnit.Year, NSCalendarUnit.Month, NSCalendarUnit.Day], fromDate: date)
    return (comp.year, comp.month, comp.day)
}

func normalizedStringFromDateComponents( year: Int, month: Int, day: Int ) -> String {
    if year == 0 || month == 0 || day == 0 {
        return ""
    }
    return String(format: "%4d.%02d.%02d", year, month, day) // as YYYY.MM.DD
}

func dateComponentsFromNormalizedString( date: String ) -> (Int, Int, Int) { // as Y, M, D
    if !date.isEmpty {
        let yyyy = Int(date[0...3])!
        let mm = Int(date[5...6])!
        let dd = Int(date[8...9])!
        return (yyyy, mm, dd)
    }
    return (0, 0, 0)
}


// MARK: message box services
typealias MenuBoxEntry = (String, (UIAlertAction!)->Void)
func menuBoxWithTitle( title: String, andBody body: [MenuBoxEntry], forController vc: UIViewController ) {
    messageBoxWithTitleEx(title, andBody: "", forController: vc) { ac in
        var act = UIAlertAction(title: "Cancel", style: .Cancel) { x in
            // dismiss but do nothing
        }
        ac.addAction(act)
        for (menuItem, menuFunc) in body {
            var menuTitle = menuItem
            var style = UIAlertActionStyle.Default
            // any provided title string that starts with a "!" will be Destructive style (and the "!" will be removed)
            if menuItem[0] == "!" {
                menuTitle = menuItem.substringFromIndex(menuItem.startIndex.successor())
                style = UIAlertActionStyle.Destructive
            }
            act = UIAlertAction(title: menuTitle, style: style, handler: menuFunc)
            ac.addAction(act)
        }
    }
}

func messageBoxWithTitle( title: String, andBody body: String, forController vc: UIViewController ) {
    messageBoxWithTitleEx(title, andBody: body, forController: vc) { ac in
        let act = UIAlertAction(title: "OK", style: .Default) { x in
            // dismiss but do nothing
        }
        ac.addAction(act)
    }
}

private var acInUse: UIAlertController! // retain ref to AC while it executes
func messageBoxWithTitleEx( title: String, andBody body: String, forController vc: UIViewController, configuration: (( UIAlertController) -> Void)? = nil ) {
    acInUse = UIAlertController(title: title, message: body, preferredStyle: .Alert) // putting in a new one forgets the old one, if any, which will get cleaned up by ARC
    if let configHandler = configuration {
        configHandler(acInUse)
    }
    vc.presentViewController(acInUse, animated: true, completion: nil)
}

// MARK: table view cell formatting services
func formatBTDetail(item: BTDealerItem) -> String {
    var text = "\(item.code)"
    if item.catalog1 != "" {
        text += " [" + item.catalog1
        if item.catalog2 != "" {
            text += ", " + item.catalog2
        }
        text += "]"
    }
    let price1 = item.price1.isEmpty ? "-0-" : item.price1
    let price2 = item.price2.isEmpty ? "-0-" : item.price2
    let price3 = item.price3.isEmpty ? "-0-" : item.price3
    let price4 = item.price4.isEmpty ? "-0-" : item.price4
    let output = "\(text) - \(item.status): \(price1) FDC-\(price2) Used-\(price3) M/nt-\(price4)"
    return output
}

func formatDealerDetail(item: DealerItem) -> String {
    var text = "\(item.id)(#\(item.exOrder))"
    if item.cat1 != "" {
        text += " [" + item.cat1
        if item.cat2 != "" {
            text += ", " + item.cat2
        }
        text += "]"
    }
    let price1 = item.price1.isEmpty ? "-0-" : item.price1
    let price2 = item.price2.isEmpty ? "-0-" : item.price2
    let price3 = item.price3.isEmpty ? "-0-" : item.price3
    let price4 = item.price4.isEmpty ? "-0-" : item.price4
    var output = "\(text) - \(item.status): \(price1) Used-\(price2) FDC-\(price3) M/nt-\(price4)"
//    let pufs = item.category.prices
//    switch pufs {
//    case "P":
//        output = "\(text) - \(item.status): \(price1)"
//    case "PU":
//        output = "\(text) - \(item.status): \(price1) Used-\(price2)"
//    case "PF":
//        output = "\(text) - \(item.status): \(price1) FDC-\(price2)"
//    default: break
//    }
    if let invItems = Array(item.inventoryItems) as? [InventoryItem] where invItems.count > 0 {
        let types = invItems.map{ $0.itemCondition }
        let summary = histogram(types)
        let sumstr = showHistogram(summary)
        output += "; INV:\(sumstr)"
    }
    if let invItems = Array(item.referringItems) as? [InventoryItem] where invItems.count > 0 {
        let refs = invItems.map{ $0.baseItem as String }
        let summary = histogram(refs)
        let sumstr = showHistogram(summary)
        output += "; REF:\(sumstr)"
    }
    return output
}

func histogram<T where T: Hashable>(items: [T]) -> [T:Int] {
    var output: [T:Int] = [:]
    for item in items {
        if output[item] == nil {
            output[item] = 1
        } else {
            ++(output[item]!)
        }
    }
    return output
}

func showHistogram<T where T:Hashable>(input: [T:Int]) -> String {
    var output: [String] = []
    for (item, counter) in input {
        let ctr = counter > 1 ? "(\(counter))" : ""
        output.append("\(item)\(ctr)")
    }
    return output.joinWithSeparator(",")
}

// MARK: formatting for update comparison review
func formatComparisonRecord( comprec: CompRecord ) -> String {
    var output = "Changes:"
    for (fieldName, status) in comprec {
        switch status {
        case .Equal: continue
        case .EqualIfTC: continue
        default:
            output += " \(fieldName)"
        }
    }
    return output
}

func formatUpdateAction( action: UpdateCommitAction, isLong: Bool = false, withParens: Bool = true ) -> String {
    var output = ""
    switch action {
    case .None: output = isLong ? "None" : ""
    case .Add: output = isLong ? "Add" : "+"
    case .AddAndRemove: output = isLong ? "AddAndRemove" : "+,-"
    case .ConvertType: output = isLong ? "ConvertType" : "=>"
    case .Remove: output = isLong ? "Remove" : "-"
    case .Update: output = isLong ? "Update" : "->"
    }
    if withParens {
        output = "(\(output))"
    }
    return output
}

func getFormattedActionKeysForSection( section: UpdateComparisonTable.TableID ) -> [String] {
    let actions = UpdateComparisonTable.getAllowedActionsForSection(section)
    var actionStrings = actions.map{ formatUpdateAction( $0 ) + ":" + formatUpdateAction( $0, isLong: true, withParens: false) }
    actionStrings[0] += " (Default)"
    return actionStrings
}

func formatActionKeyForSection( section: UpdateComparisonTable.TableID ) -> String {
    var output = ""
    let actionStrings = getFormattedActionKeysForSection(section)
    output += actionStrings.joinWithSeparator("\n")
    return output
}

func getColorForAction(action: UpdateCommitAction, inSection section: UpdateComparisonTable.TableID) -> UIColor {
    switch action {
    case .None: return UIColor.whiteColor()
    case .Add: return UIColor.greenColor().colorWithAlphaComponent(0.5)
    case .AddAndRemove: return UIColor.magentaColor().colorWithAlphaComponent(0.5)
    case .ConvertType: return UIColor.blueColor().colorWithAlphaComponent(0.5)
    case .Remove: return UIColor.redColor().colorWithAlphaComponent(0.5)
    case .Update: return section == .Ambiguous ? UIColor.cyanColor().colorWithAlphaComponent(0.5) : UIColor.yellowColor().colorWithAlphaComponent(0.5)
    }
}

// MARK: Inventory formatting basics
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
    return item.wantHave == "w" ? "*WANTED*" : ""
}

private func formatInventoryLocation(item: InventoryItem) -> String {
    let section = item.albumSection
    let sectionStr = section.isEmpty ? "" : " (S:\(section))"
    return "IN \(item.albumRef) p.\(item.albumPage)\(sectionStr)"
}

func formatPriceDescription( catPrices: String, fieldName: String ) -> String {
    // determine whether to return
    //  Mint v Used (cat.prices == PU)
    //  Mint(tab) v Used v FDC v Other (PUFS)
    //  Mint v FDC (PF)
    //  "" (P only)
    var output = ""
    switch (catPrices, fieldName) {
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
    return output
}

private func formatInventoryValue(item: InventoryItem) -> String {
    var output = "Val"
    let baseItem = item.dealerItem
    let nameExt = formatPriceDescription(item.category.prices, fieldName: item.itemType)
    output += nameExt
    if let price = baseItem.valueForKey(item.itemType) as? String,
        priceVal = price.toDouble() {
            output += "=" + padDoubleString(priceVal, toLength: 10, withFractionDigits: 2, padWith: "")
    }
    return output
}

private func formatInventoryVarCondition(item: InventoryItem) -> String {
    let variety = item.desc.isEmpty ? "" : /*makeStringFit(*/"V: \(item.desc)"//, 40)
    let condition = item.notes.isEmpty ? "" : /*makeStringFit(*/"C: \(item.notes)"//, 40)
    return "\(variety) \(condition)"
}

func formatInventoryMain(item: InventoryItem) -> String {
    let basedes = item.dealerItem.descriptionX //makeStringFit(item.dealerItem.descriptionX, 60)
    return "\(basedes) \(formatInventoryWantField(item)) \(formatInventoryLocation(item))"
}

func formatInventoryDetail(item: InventoryItem) -> String {
    return "\(item.baseItem) \(formatInventoryValue(item)) \(formatInventoryVarCondition(item))"
}

// MARK: Parsing the ID code field for sorting
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

extension CodeFieldClass: CustomStringConvertible {
    var description: String {
        switch self {
        case .Numeric: return "num"
        case .Alpha: return "alp"
        default: break
        }
        return "unk"
    }
}

func getCharacterClass( ch: Character ) -> CodeFieldClass {
    // assumes old-style ASCII - okay for what I have used so far
    if ch >= "0" && ch <= "9" {
        return .Numeric
    }
    return .Alpha
}

private func splitDealerCode( code: String, special: Bool = false ) -> [String] {
    // accepts code numbers of the following forms:
    //  "6110xNNNyy"
    //  "psXXNNNyy"
    // SPECIAL: "6110kNNNRC[1]mMMM"
    // New ANBAR system - uses 5-digit machine numbers
    // splits them into fields of homogenous type (alpha or numeric)
    var output: [String] = []
    var field = ""
    var state: CodeFieldClass = .Unknown
    for char in code.characters {
        let charClass = getCharacterClass(char)
        if special {
            // detect field == "RC" and wait until "m" is detected, accumulating digits and suffixes into field
            if field.characters.count >= 2 && field[0...1] == "RC" {
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
    let firstCharClass = getCharacterClass(code[0])
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
    let len = code.characters.count
    let part1 = code[0..<splitAt]
    let part2 = code[splitAt..<len]
    return (part1, part2)
}

private func normalizeCatCode( codePart: String, forCat catnum: Int16 ) -> String {
    return "NCAT" + padIntegerString(Int(catnum), toLength: 4)
}

private func paddington( len: Int, input: String, char: Character = " ", trailing: Bool = false ) -> String {
    let inlen = input.characters.count
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

struct IDParser {
    let catnum: Int16
    let allows1000Fix: Bool
    let original: String
    let main: String // catcode + prefix + sequence
    let catcode: String
    let prefix: String // .Alpha or empty
    let sequence: String // .Numeric - NOTE: still needs fixup (+1000 or year-set split)
    var fields: [String] // all suffix fields, starting with first .Alpha one

    init( code: String, forCat catnumIn: Int16, isPostE1K: Bool = false ) {
        catnum = catnumIn
        allows1000Fix = isPostE1K
        original = code
        let (catcode, rest) = splitCatCode(code, forCat: catnum)
        self.catcode = catcode
        fields = splitDealerCode(rest, special: catnum == 26) // special handling invoked for Vending category 6110kNNNRC[..]mMMM case
        let firstField = fields.first!
        let hasPrefix = getCharacterClass(firstField[0]) == .Alpha
        if hasPrefix {
            prefix = firstField
            fields.removeAtIndex(0)
        } else {
            prefix = ""
        }
        sequence = fields.first!
        fields.removeAtIndex(0)
        main = catcode + prefix + sequence
    }
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
    let lenrest = rest.characters.count
    let finrest = lenrest < 2 ? "  " : rest[lenrest-2...lenrest-1]
    let fields = splitDealerCode(rest, special: catnum == 26) // special handling invoked for Vending category 6110kNNNRC[..]mMMM case
    let data = fields.map { x in
        (normcat, catcode, x, getCharacterClass(x[0]))
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
                output += paddington(8, input: "ZZPACKET", char: padder)
            }
            else if catnum == 20 && rest[0...1] == "PC" && finrest[1] == "m" {
                // special handling for Military Post Cards (cat 20) psPC NNN m
                // if the last field is an alpha == "m", then add an alpha prefix to make it sort after the plan ones
                output += paddington(8, input: "PC_MIL", char: padder, trailing: true)
                skip = true // prevent the PC from becoming another prefix
            }
            else if catnum == 21 && finrest[1] == "p" {
                // special handling for Revenue (cat 21) 6110r NNN p
                // if the last field is an alpha == "p", then add an alpha prefix to make it sort after the plan ones
                output += paddington(8, input: "ZZPACKET", char: padder)
            }
            else if catnum == 26 && rest == "9k" {
                // special handling for Vending (cat 26) 6110k 9 k
                output += paddington(8, input: "ZZPACKET", char: padder)
            }
            else if catnum == 26 && rest == "30" {
                // special handling for Vending (cat 26) 6110k 9 k
                output += paddington(8, input: "ZZPACKET", char: padder)
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
                output += paddington(8, input: prefix, char: padder, trailing: true)
            }
            else if catnum == 3 && catcode == "6110e" {
                // special handling for Booklets (cat 26) 6110e [...] to go after 6110b [...]
                output += paddington(8, input: "EBOOKLET", char: padder)
            }
            else if fieldClass != .Alpha {
                // missing prefix field - normalize by adding empty one
                output += paddington(8, input: "", char: padder)
            }
        }
        let flen = field.characters.count
        switch fieldClass {
        case .Alpha: if !skip { output += paddington(8, input: field, char: padder, trailing: true) }
        case .Numeric:
            var num = Int(field)!
            // insert YEAR fixups here
            if catnum == 16 {
                num += fixupCenturyYY(num)
            }
            if catnum == 27 && flen == 2 {
                num += fixupCenturyYY(num)
            }
            if catnum == 27 && flen == 4 {
                var num1 = Int(field[0...1])!
                var num2 = Int(field[2...3])!
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
                    var num1 = Int(field[0...1])! // YY
                    let num2 = Int(field[2...3])! // NN
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

// Album-order inventory comparisons, almost like in the PHP code
func getSectionSortOrder( section: String ) -> Int {
    if !section.isEmpty {
        if section[0...0] == "J" { switch section {
            // special joint issue sorting, figure out order of sections by base ID (j#) instead
            /*
            '6110j595 '=>array('JPOLAND','2001','125','2SF'), // SF possibly doesn't exist (?)
            '6110j682 '=>array('JUSA','3','242','1F'),
            '6110j693 '=>array('JCZECH','2002','268','4SF'), // SF possibly doesn't exist (?)
            '6110j708 '=>array('JRUSSIA','2003','285','2SSF'), // SF possibly doesn't exist (?)
            '6110j752 '=>array('JBELGIUM','2004','333','2SF'), // SF possibly doesn't exist (?)
            '6110j762 '=>array('JSLOVAKIA','2005','349','4SF'), // SF about to be purchased (pics on eBay)
            '6110j786 '=>array('JHUNGARY','2006','383','2SF'), // SF possibly doesn't exist (?)
            '6110j814 '=>array('JGEORGIA','11','415','2SF'),
            '6110j895 '=>array('JITALY','2007','-474','4SF'), // SL not sold by BT, SF possibly doesn't exist (?)
            '6110j898 '=>array('JAUS_HUN','12','480','3S'),
            '6110j935 '=>array('JGERMANY','2008','-516','2SF'), // SL not sold by BT, SF possibly doesn't exist (?)
            '6110j1004'=>array('JUN_NGV','13','549','4SF'),
            '6110j1038'=>array('JFRANCE','15','566','4SF'),
            '6110j1055'=>array('JPOLAND2','16','577','2SSF'),
            '6110j1070'=>array('JROMANIA','2009','587','1S1FS'), //
            '6110j1085'=>array('JCANADA','27','596','SCB'),
            '6110j1089'=>array('JAUSTRIA','2010','599','24SS'), //
            '6110j1107'=>array('JVATICAN','2011','608','24SS'), //
            '6110j1164'=>array('JCHINA','2012','623','4S'), //
            '6110j1179'=>array('JNEPAL','2013','628','2S'), //
            '6110j1185'=>array('JINDIA','2014','632','4S'), //
            '6110j1206'=>array('JAUSTRALIA','2015','ne2','4S'), // renumber 'neX' for updated Carmel #s in 2013 by BT site
            '6110j1214'=>array('JGREENLAND','2016','-neX',''), // info needs to be updated after 5/2013
            */
        case "JPOLAND": return 595
        case "JUSA": return 682
        case "JCZECH": return 693
        case "JRUSSIA": return 708
        case "JEBLGIUM": return 752
        case "JSLOVAKIA": return 762
        case "JHUNGARY": return 786
        case "JGEORGIA": return 814
        case "JITALY": return 895
        case "JAUS_HUN": return 898
        case "JGERMANY": return 935
        case "JUN_NGV": return 1004
        case "JFRANCE": return 1038
        case "JPOLAND2": return 1055
        case "JROMANIA": return 1070
        case "JCANADA": return 1085
        case "JAUSTRIA": return 1089
        case "JVATICAN": return 1107
        case "JCHINA": return 1164
        case "JNEPAL": return 1179
        case "JINDIA": return 1185
        case "JAUSTRALIA": return 1206
        case "JGREENLAND": return 1214
        default: return 99998
            }} else { switch section {
            case "Tab": return 1
            case "TabD": return 2
            case "S/S": return 3
            case "P": return 4
            case "ILS": return 5
            case "AS": return 6
            // needs total expansion here - TBD actually needs to be derived from object instead (user-editable and expandable)
        default: return 99999
            }}
    }
    return 0
}

func compareByAlbum( lhs: AlbumSortable, rhs: AlbumSortable ) -> Bool {
    // first combine Type and Ref, sort by the combo
    let tr1 = lhs.albumType + lhs.albumRef
    let tr2 = rhs.albumType + rhs.albumRef
    if tr1 > tr2 { return false }
    if tr1 < tr2 { return true }
    let nemp1 = !lhs.albumSection.isEmpty
    let nemp2 = !rhs.albumSection.isEmpty
    let secOrder1 = !nemp1 ? 0 : getSectionSortOrder(lhs.albumSection)
    let secOrder2 = !nemp2 ? 0 : getSectionSortOrder(rhs.albumSection)
    if nemp1 && nemp2 && secOrder1 > secOrder2 { return false }
    if nemp1 && !nemp2 { return false }
    if !nemp1 && nemp2 { return true }
    if nemp1 && nemp2 && secOrder1 < secOrder2 { return true }
    if nemp1 && nemp2 {
        // sections are both non-empty, sort by alpha instead of ordinal
        if lhs.albumSection > rhs.albumSection { return false }
        if lhs.albumSection < rhs.albumSection { return true }
    }
    let pgval1 = lhs.albumPage.toFloat() ?? 0.0
    let pgval2 = rhs.albumPage.toFloat() ?? 0.0
    if pgval1 > pgval2 { return false }
    if pgval1 < pgval2 { return true }
    // on the same page, PHP code compares by extracted dates next (from baseItem.descriptionX, then from self.desc)
    return false
}
