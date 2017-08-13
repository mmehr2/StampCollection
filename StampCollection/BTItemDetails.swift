//
//  BTItemDetails.swift
//  StampCollection
//
//  Created by Michael L Mehr on 7/10/17.
//  Copyright © 2017 Michael L. Mehr. All rights reserved.
//

import Foundation

class BTItemDetails {
    
    typealias InfoObject = [String:String]
    fileprivate var data: InfoObject
    fileprivate let codeNumber: Int16
    fileprivate var infoLines: [String] = []
    
    init(titleLine: String, infoLine: String, codeNum cnum: Int16) {
        // NOTE: All the processing work is done here.
        // Unfortunately, we can't make the object constant with 'let' because the compiler doesn't know these names are the only ones.
        // TBD - Is there a Swift 3?4? way to say this yet? I guess, make a class out of it and set up the fields in the init() call; nope we have done that, and it still needs to be mutable. Oh well...
        // add a hint for exceptions during download creation (this is the code number from "6110s" in the URL)
        codeNumber = cnum
        data =  [
            "xtitle" : "", //raw, original init
            "xinfo": "", //raw, original init
            "info": "", //all items display description (as corrected)
            "titleRaw": "", //raw
            "ssCount": "",
            "jointWith": "",
            "subTitle": "",
            "xinfoRaw": "", //raw (all following)
            "issueDatesRaw": "", //raw - basic format (Hebrew) is DD.MM.YYYY, and comma-separated list
            "issueDateStartList": "", // space-separated list, format YYYY.MM.DD where MM and DD use leading zeroes
            "issueDateEndList": "", // space-separated list, format YYYY.MM.DD where MM and DD use leading zeroes
            "designersRaw": "", //raw
            "designers": "",
            "plateNumbersRaw": "", //raw
            "plateNumbers": "", // space-separated list of plate numbers (no suffixes I believe)
            "bulletinsRaw": "", //raw
            "bulletins": "", // space-separated list of designators, each of which might contain a suffix letter, such as "123 123a 123b"
            "leafletsRaw": "", //raw
            "leaflets": "", // space-separated list of leaflet numbers (no suffixes I believe)
            "sheetFormatRaw": "", //raw
            "numStampsList": "", // list of Ints, separated by spaces
            "numTabsList": "", // same
            "numRowsList": "", // list of Ints, separated by spaces
            "numColumnsList": "", // same
            "sheetFormatList": "", // space separated list of formats such as "(3x5)" taken from "15s 5t"
            "sheetFormatCount": "", // so that all the answers can coordinate properly
            "souvenirSheetFormatRaw": "", //raw
            "ssWidthList": "", // space-separated list of: Float number with 1 DP, minus the "cm", such as "13.0"
            "ssHeightList": "", // same
            "ssUnits": "",
        ]
        // typically, bulletin and/or leaflet line will be missing - will all dates be there? who knows?
        // if we're a Souvenir Sheet (see lines[1]), the plate number line is replaced by a size line in cm (HxW, floating point with 1 decimal optional) (so far, no S/S has a plate number...)
        // create a dictionary using the following headers (all data are strings):
        //  "ssCount" = 0/1/2/3/+? (souvenir sheet count) -- sometimes it says "N Souvenir Sheets" for N==3 or ...
        //  "jointWith" = XXX (joint issue partner, or blank if none)
        //  "plateNumbers" = NNN (CSV plate number list*) - always pure numbers with a 'p' at the front, no spaces (EXCEPT Stand-by issues have no p# but are listed as 'p--'; this is flagged in the title as "Stand-By"
        //  "bulletins" = BBB (CSV bulletin number list*) - bulletins as marked so some can have a suffix like 259a for s255 (25th Independence); these went away after the early '80s so the field is optional, empty if not present
        //  "leaflets" = LLL (CSV leaflet number list*) - these weren't available in the early years, so field is optional and empty if not present, but see s88 (leaflet (0)) or s91 "leaflet none" (and "bulletin ??")
        //  "ssWidth" = WW.W (souv.sheet width dimension in cm)
        //  "ssHeight" = HH.H (souv.sheet height dimension in cm)
        //  "designers" = DDDDD (designer name(s))
        //  "issueDates" = DD.MM.YYYY (date of issue, I think) - this is sometimes a date range separated by '-' (see for example Landscapes I and II (s234) or Coins Mered (s23)
        // NOTE: sheet format variation on s738-9 Flag 1st SA - uses 40s (4t)
        //  "numStamps" = NN (sheet format, number of stamps per sheet, except in case of "3 Souvenir Sheets" like Jerusalem '73 where it's still 3 in the set, but for 3 sheets, it's like 10s 5t, the single sheet format (!)
        //  "numTabs" = TT (sheet format, number of tabs)
        //  "setCardinality" = N for purposes of splitting, how many things are in this set? diff.#s needed for set, FDC, and sheet, but we can't really tell here, so just one guess (or can we?)
        //     for now, I would define it as the number of plate numbers present, and if no P# line, then the # of S/S
        // * These CSV lists should be normalized to include all values, separated by commas, instead of the shorthand method used by the website; parse something like "255-7,263,279-81" into "255 256 257 263 279 280 281"
        //    NOTE: remember bulletins can have non-numeric suffixes too, and maybe the early leaflets too; see Morgenstein for the excruciating details!
        
        let infoData = infoLine.components(separatedBy: "/")
        data["xtitle"] = titleLine
        parseTitleField(titleLine)
        let numInfo = infoData.count
        if numInfo > 0 {
            parseDateList(infoData[0])
        }
        if numInfo > 1 {
            parseDesignerList(infoData[1])
        }
        if numInfo > 2 {
            for i in 2..<numInfo {
                // the following components are OPTIONAL
                let component = infoData[i]
                if component.hasPrefix("p") {
                    parsePlateNumberList(component)
                } else if component.hasPrefix("bulletin") {
                    parseBulletinList(component)
                } else if component.hasPrefix("leaflet") {
                    parseLeafletList(component)
                } else if component.hasSuffix("s") {
                    parseSheetFormat(component)
                } else if component.hasSuffix("t") {
                    parseSheetFormat(component)
                } else if component.hasSuffix("cm") {
                    parseSouvenirSheetFormat(component)
                } else if !component.isEmpty {
                    parseException(component)
                }
            }
        }
        // once everyone has parsed, concatenate the raw inputs found
        data["info"] = assembleInfoField(withSeparator: "||") // display version
        data["xinfo"] = assembleInfoField(withSeparator: "/") // reconstruction (import/export) version
    }

    // special exception handling for certain data errors from the BT site
    enum ExceptionAction : CustomStringConvertible {
        case InvertedSheetStampFormat,
         ParenSheetFormat,
         BadPlateNumberPrefix,
         LabeledSheetFormat
        
        var description: String {
            switch self {
            case .InvertedSheetStampFormat: return "InvertedSheetStampFormat"
            case .ParenSheetFormat: return "ParenSheetFormat"
            case .BadPlateNumberPrefix: return "BadPlateNumberPrefix"
            case .LabeledSheetFormat: return "LabeledSheetFormat"
            }
        }
    }
    
    fileprivate static let exceptions: [Int16:ExceptionAction] = [
        475:.InvertedSheetStampFormat, // sheet format "sX" should be "Xs" for X numeric
        738:.ParenSheetFormat, // parens on sheet format tabs "40s (4t)"
        739:.ParenSheetFormat, // parens on sheet format tabs "40s (4t)"
        1032:.BadPlateNumberPrefix, // plate number list is missing initial 'p'
        1101:.LabeledSheetFormat, // sheet format is "6s+3l", needs to use "6s 6t" like others (but ignore labels for now)
    ]

    // to allow other classes to test if an exceptional condition exists for this detail item (code number is part of URL)
    static func isExceptional(codeNumber cnum: Int16) -> Bool {
        return exceptions.keys.contains(cnum)
    }
    
    fileprivate func parseException(_ input: String) {
        // deal with certain discovered exceptions in the BT data (as of Aug 2017)
        if let action = BTItemDetails.exceptions[codeNumber] {
            // perform custom action as required
            switch action {
            case .InvertedSheetStampFormat:
                let (p, x) = splitNumericEndOfString(input)
                let newInput = x + p
                print("Exception \(action) - passing \(newInput) to parseSheetFormat()")
                parseSheetFormat(newInput)
                break
            case .ParenSheetFormat:
                // remove '(' and ')'
                let newInput = input.replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "")
                print("Exception \(action) - passing \(newInput) to parseSheetFormat()")
                parseSheetFormat(newInput)
                break
            case .BadPlateNumberPrefix:
                let newInput = "p" + input
                print("Exception \(action) - passing \(newInput) to parsePlateNumberList()")
                parsePlateNumberList(newInput)
                break
            case .LabeledSheetFormat:
                // NOTE: This is hard to generalize without knowing what BT might do in the future. Simpler is better.
                // remove label string (between '+' and 'l' inclusive)
                let input1 = input.replacingOccurrences(of: "\\+[^l]l", with: "", options: .regularExpression, range: nil)
                // add the same number of tabs as a suffix
                // to do this, we double the string with a space in the middle, then drop the final 's' and add a 't'
                let input2 = "\(input1) \(input1)"
                let input3 = String(input2.characters.dropLast())
                let newInput = input3 + "t"
                print("Exception \(action) - passing \(newInput) to parseSheetFormat()")
                parseSheetFormat(newInput)
                break
            }
        } else {
            print("Couldn't parse the DealerItem detailed info line: [\(input)]")
        }
    }
    
    fileprivate func parseTitleField(_ input: String) {
        //
        //print("Parse the Title field: \(input)")
        data["titleRaw"] = input
        // look for "- Souvenir Sheet" OR "- N Souvenir Sheets" to set ssCount to "N" or "1" or "0"
        // look for "- XXXX YYY ZZ Joint Issue" to set jointWith to "XXXX YYY ZZ"
        // NOTE: DO IT ALL WITH Regexes!! -- actually tho it gets more complicated
        // The Joint Issue might be blank, because the title itself says "Thailand Friendship" or "Germany Relations", so ...
        // We need to be always accumulating in the buffer and scanning it for these new keywords (Friendship and Relations for now)
        var seenHyphen = false // T if we have seen a hyphen
        var seenSouvenir = false // "state machine" for Souvenir Sheet pattern
        var seenJoint = false // "state machine" for Joint Issue pattern
        var buffer = [String]()
        var subtitleBuffer = [String]()
        var ssCount = 0
        var jointWith = ""
        var completedJoint = false
        var unlinkSubtitle = false
        var unlinkKeywords = 0
        for word in input.components(separatedBy: " ") {
            subtitleBuffer += [word] // never cleared completely, just when keywords are recognized
            
            switch word {
            case "-":
                seenHyphen = true
                buffer = []
                unlinkKeywords = 1
            case _ where word.contains("Friendship") || word.contains("Relations"):
                if buffer.count > 0 {
                    jointWith = buffer.last!
                }
            case _ where seenHyphen && word.contains("Souvenir"):
                seenSouvenir = true
                unlinkKeywords += 1
            case _ where seenSouvenir && word.contains("Sheets"):
                // BINGO! more than one S/S
                // set ssCount from buffer[0] if buffer.count == 1
                if buffer.count == 1, let count = Int(buffer[0]) {
                    ssCount = count
                } else {
                    print("Bad parse of Title SSCount buffer \(buffer)")
                }
                seenSouvenir = false
                seenHyphen = false
                unlinkKeywords += 1
                unlinkSubtitle = true
            case _ where seenSouvenir && word.contains("Sheet"):
                // BINGO! one S/S
                ssCount = 1
                seenSouvenir = false
                seenHyphen = false
                unlinkKeywords += 1
                unlinkSubtitle = true
            case _ where seenHyphen == true && word.contains("Joint"):
                seenJoint = true
                unlinkKeywords += 1
            case _ where seenJoint == true && word.contains("Issue"):
                // BINGO! joint issue completed - might already have something tho
                // We can safely overwrite it if the buffer has something instead (word(s) seen since hyphen)
                // Test this with set 6110s935 2005 Germany Diplomatic Relations
                if buffer.count > 0 {
                    jointWith = buffer.joined(separator: " ")
                }
                seenJoint = false
                seenHyphen = false
                completedJoint = true
                unlinkKeywords += 1
                unlinkSubtitle = true
            default:
                buffer += [word]
            }
            
            if unlinkSubtitle {
                // remove the last N items in the buffer from the subtitle too, plus one each for the hyphen and two keywords
                subtitleBuffer = Array(subtitleBuffer.dropLast(buffer.count + unlinkKeywords))
                unlinkSubtitle = false
                unlinkKeywords = 0
            }
        } // loop on words
        if !completedJoint {
            // random use of Friendship or Relations if we never saw the "- Joint Issue" tag
            jointWith = ""
        }
        data["ssCount"] = String(ssCount)
        data["jointWith"] = jointWith
        data["subTitle"] = subtitleBuffer.joined(separator: " ")
    }

    // to allow reprocessing, we add each component by name so the order of the final info is preserved,
    // but we don't allow duplicates
    fileprivate func addRawInfo(_ input: String, named name: String) {
        data[name] = input
        if !infoLines.contains(name) {
            infoLines.append(name)
        }
    }

    // once everyone is finally parsed, assemble the raw input fields named into the info field
    // this is what will be persisted in Export and reconstructed in Import
    fileprivate func assembleInfoField(withSeparator sep: String) -> String {
        var result : [String] = []
        for name in infoLines {
            if let value = data[name] {
                result.append(value)
            }
        }
        return result.joined(separator: sep)
    }
    
    fileprivate func parseDateList(_ input: String) {
        //
        //print("Parse the Issue Date list: \(input)")
        
        addRawInfo(input, named: "issueDatesRaw")
        // convert each comma-separated component from DD.MM.YYYY to YYYY.MM.DD format, space-separated
        let comps = input.components(separatedBy: ",")
        var starts = [String]()
        var ends = [String]()
        for comp in comps {
            let (_, rng) = extractDateRangesFromDescription(comp)
            starts.append("\(normalizedStringFromDate(rng.lowerBound))")
            ends.append("\(normalizedStringFromDate(rng.upperBound))")
        }
        /*
        "issueDateStartList": "", // space-separated list, format YYYY.MM.DD where MM and DD use leading zeroes
        "issueDateEndList": "", // space-separated list, format YYYY.MM.DD where MM and DD use leading zeroes
         */
        data["issueDateStartList"] = starts.joined(separator: " ")
        data["issueDateEndList"] = ends.joined(separator: " ")
    }
    
    fileprivate func parseDesignerList(_ input: String) {
        //
        //print("Parse the Designer list: \(input)")
        
        addRawInfo(input, named: "designersRaw")
        data["designers"] = input // no processing for now
        
    }
    
    private let specialPlateNumbers: [Int16:String] = [
        1: "1 1 1 1 1 1", // '48 Coins: all sheets had plate number 1
        2: "1 1 1", // '48 Coins (hi values): all sheets had plate number 1
        4: "1 1 1 1 1", // '48 Postage dues (coins): all sheets had plate number 1
        5: "1:6 1:6 1:6 1:6 1:6", // '48 Festivals: five sheets of 300, ea.consisting of 6 panes of 50 (50s 10t) numbered 1-6
        13: "1:2 1:2 1:2 1:2 1:2 1:2", // '49 Coins (MERED): ea.sheet had plate numbers 1 and 2 on left and right
        20: "1:6 1:6 1:6 1:6 1:6 1:6", // '50 Airmail Birds: ea.sheet had all plate numbers 1-6
        91: "1-10,29", // '60 Provisionals: additional sheet not mentioned by BT info
    ]
    
    fileprivate func parsePlateNumberList(_ input: String) {
        //
        //print("Parse the Plate Number list: \(input)")
        
        addRawInfo(input, named: "plateNumbersRaw")
        
        if input.hasPrefix("p") {
            let plist : String
            if let plistX = specialPlateNumbers[codeNumber] {
                plist = plistX
            } else {
                plist = String(input.characters.dropFirst())
            }
            let output = expandNumberList(plist)
            data["plateNumbers"] = output
        } else {
            data["plateNumbers"] = ""
        }
        
    }
    
    fileprivate func parseBulletinList(_ input: String) {
        //
        //print("Parse the Bulletin list: \(input)")
        
        addRawInfo(input, named: "bulletinsRaw")
        
        let name = "bulletin "
        if input.hasPrefix(name) {
            let plist = String(input.characters.dropFirst(name.characters.count))
            let output = expandNumberList(plist)
            data["bulletins"] = output
        } else {
            data["bulletins"] = ""
        }
        
    }
    
    fileprivate func parseLeafletList(_ input: String) {
        //
        //print("Parse the Leaflet list: \(input)")
        
        addRawInfo(input, named: "leafletsRaw")
        
        let name = "leaflet "
        if input.hasPrefix(name) {
            let plist = String(input.characters.dropFirst(name.characters.count))
            let output = expandNumberList(plist)
            data["leaflets"] = output
        } else {
            data["leaflets"] = ""
        }
        
    }
    
    fileprivate class func parseSheetFormatSingle(_ input: String) -> (String, String, String, String)? {
        // try to return (nStamps nTabs nRows nCols) from a single "Ns Mt" or "Ns" designator
        if input.hasSuffix("s") {
            // simple count w/o tabs, no idea of format
            let nStamps = String(input.characters.dropLast())
            return (nStamps, "?", "?", "?")
        } else if input.hasSuffix("t") {
            let comps = input.components(separatedBy: " ")
            if comps.count == 2 {
                let stamps = comps[0]
                let tabs = comps[1]
                if stamps.hasSuffix("s") && tabs.hasSuffix("t") {
                    let nStamps = String(stamps.characters.dropLast())
                    let nTabs = String(tabs.characters.dropLast())
                    if let nS = Int(nStamps), let nT = Int(nTabs) {
                        // assuming tabs in rows across the bottom, the # of cols is the same as the number of tabs, and the number of rows is stamps/tabs
                        // NOTE: for modern cases where this is not the case, let's see how BT handles it - hand editing the output may be required
                        var nRows = "0" // theoretically possible to have a sheet without tabs in the data, just unlikely
                        if nT > 0 {
                            let nR = nS / nT
                            nRows = "\(nR)"
                        }
                        return (nStamps, nTabs, nRows, nTabs)
                    }
                }
            }
        }
        return nil
    }
    
    fileprivate func parseSheetFormat(_ input: String) {
        //
        //print("Parse the Sheet Format list: \(input)")
        
        addRawInfo(input, named: "sheetFormatRaw")
        
        /*       "sheetFormatRaw": "", //raw
         "numStampsList": "", // list of Ints, separated by spaces
         "numTabsList": "", // same
         "numRowsList": "", // list of Ints, separated by spaces
         "numColumnsList": "", // same
         "sheetFormatList": "", // space separated list of formats such as "(3x5)" taken from "15s 5t"
         "sheetFormatCount": "", // so that all the answers can coordinate properly
         */
        let comps = input.components(separatedBy: ",")
        var stamps = [String]()
        var tabs = [String]()
        var rows = [String]()
        var cols = [String]()
        var formats = [String]()
        var count = 0
        for comp in comps {
            if let (s, t, r, c) = BTItemDetails.parseSheetFormatSingle(comp) {
                stamps.append(s)
                tabs.append(t)
                rows.append(r)
                cols.append(c)
                formats.append("(\(r)x\(c))")
                count += 1
            }
        }
        data["numStampsList"] = stamps.joined(separator: " ")
        data["numTabsList"] = tabs.joined(separator: " ")
        data["numRowsList"] = rows.joined(separator: " ")
        data["numColumnsList"] = cols.joined(separator: " ")
        data["sheetFormatList"] = formats.joined(separator: " ")
        data["sheetFormatCount"] = "\(count)"
    }

    fileprivate class func parseSouvenirSheetFormatSingle(_ input: String) -> (String, String)? {
        let comps = input.components(separatedBy: "x")
        if comps.count == 2 {
            let width = comps[0]
            let height = comps[1]
            return (width, height)
        }
        return nil
    }
    
    fileprivate func parseSouvenirSheetFormat(_ input: String) {
        //
        //print("Parse the Souvenir Sheet Format list: \(input)")
        
        addRawInfo(input, named: "souvenirSheetFormatRaw")
        
        /*          "souvenirSheetFormatRaw": "", //raw 19.3x10.0cm (possible comma-separated list?)
         "ssWidthList": "", // space-separated list of: Float number with 1 DP, minus the "cm", such as "13.0"
         "ssHeightList": "", // same
         "ssUnits": "cm",
         */
        var widths = [String]()
        var heights = [String]()
        var units = ""
        if input.hasSuffix("cm") {
            units = "cm"
            let plist = String(input.characters.dropLast(2))
            let comps = plist.components(separatedBy: ",")
            for comp in comps {
                if let (w, h) = BTItemDetails.parseSouvenirSheetFormatSingle(comp) {
                    widths.append(w)
                    heights.append(h)
                }
            }
        }
        data["ssUnits"] = units
        data["ssWidthList"] = widths.joined(separator: " ")
        data["ssHeightList"] = heights.joined(separator: " ")
    }
    
}

// MARK: protocol overrides
extension BTItemDetails: CustomDebugStringConvertible {
    var debugDescription: String {
        var result = "Item details:\n"
        let obj = self.data
        let keys = obj.keys.sorted()
        
        for k in keys {
            // in order, add the lines
            result += " \"\(k)\": \"\(obj[k]!)\"\n"
        }
        return result
    }
}

extension BTItemDetails: CustomStringConvertible {
    
    var description: String {
        return data["info"] ?? ""
    }
    
}

// MARK: Publically accessible properties
extension BTItemDetails {
 
    // these two can be used to initialize a new object equal to this one
    // NOTE: original title is just the description field with all annotations of the original set BTDealerItem
    var originalTitle: String {
        return data["xtitle"] ?? ""
    }
    var originalInfo: String {
        return data["xinfo"] ?? ""
    }
    
    // converts the lists of issued date ranges for this set to an array of ClosedDateRange
    var dateRanges: [ClosedRange<Date>] {
        var result = [ClosedRange<Date>]()
        if let slist = data["issueDateStartList"]?.components(separatedBy: " "),
            let elist = data["issueDateEndList"]?.components(separatedBy: " "),
            slist.count == elist.count
        {
            for i in 0..<slist.count {
                if slist[i] == elist[i] {
                    if let d = Date(gregorianString: slist[i]) {
                        result.append(d...d)
                    }
                } else {
                    if let s = Date(gregorianString: slist[i]),
                        let e = Date(gregorianString: elist[i]) {
                        result.append(s...e)
                    }
                }
            }
        }
        return result
    }
    
    // converts that list to a string of ranges separated by ", "
    var dateRange: String {
        var result = [String]()
        if let slist = data["issueDateStartList"]?.components(separatedBy: " "),
            let elist = data["issueDateEndList"]?.components(separatedBy: " "),
            slist.count == elist.count
        {
            for i in 0..<slist.count {
                if slist[i] == elist[i] {
                    result.append(slist[i])
                } else {
                    result.append("\(slist[i])-\(elist[i])")
                }
            }
        }
        return result.joined(separator: ", ")
    }
    
    // returns whether any specific (Optional) date is in any of the ranges covered by this set
    func isDateInRange(_ date: Date?) -> Bool {
        var result = false
        if let date = date {
            // scan the list of date ranges and search for any match
            for rng in dateRanges {
                if rng.contains(date) {
                    result = true
                    break
                }
            }
        }
        return result
    }
    
    // converts the list of plate numbers into an array of Int plate numbers
    var plateNumberList: [String] {
        var result = [String]()
        if let xlist = data["plateNumbers"], !xlist.isEmpty {
            result = xlist.components(separatedBy: " ") //.map{ Int($0) }.flatMap{ $0 }
        }
        return result
    }
    
    // converts the list of leaflets into an array of String leaflet numbers
    var leafletList: [String] {
        var result = [String]()
        if let xlist = data["leaflets"], !xlist.isEmpty {
            result = xlist.components(separatedBy: " ")
        }
        return result
    }
    
    // converts the list of bulletins into an array of String bulletin numbers
    var bulletinList: [String] {
        var result = [String]()
        if let xlist = data["bulletins"], !xlist.isEmpty {
            result = xlist.components(separatedBy: " ")
        }
        return result
    }
    
    // separates the sheet format list into an array of format strings of the form "(RxC)" where R is # of rows, C is # of columns
    var sheetFormatList: [String] {
        var result = [String]()
        if let xlist = data["sheetFormatList"], !xlist.isEmpty {
            result = xlist.components(separatedBy: " ")
        }
        return result
    }
    
    // the sheet series string decides from the dateRanges of the set which of the four sheet series this set belongs to (1948+, 1960+, 1981+, 1986+) and returns it as a string in "YYYY+" format; best dates were used by studying the stamp data.
    var sheetSeries: String {
        //let years = [ 1948, 1960, 1980, 1986 ] // start year when plate numbers were reset to 1
        let eventDates = [
            // first issue of State of Israel
            Date(gregorianString: "1948.5.16")!,
            // 1960 Provisional stamps p.1-6 were issued on 1960.1.6 (one value came out in July that year)
            Date(gregorianString: "1960.1.6")!,
            // Golda Meir issue s363 plate #1 dated 1981.2.10
            Date(gregorianString: "1981.2.10")!,
            // Archeology def.issue s444 p6-7 but date was 1986.1.1, p1 was Artur Rubenstein on 1986.3.4, so use 1.1
            Date(gregorianString: "1986.1.1")!,
            //...Date(timeIntervalSinceNow: 0),
       ]
        // actually want OpenDateRange's between pairs of these
        //let seriesRanges: [OpenRange<Date>] = []
        let seriesRanges = [
            eventDates[0]..<eventDates[1],
            eventDates[1]..<eventDates[2],
            eventDates[2]..<eventDates[3],
            eventDates[3]..<Date(timeIntervalSinceNow: 0),
        ]
        let resultX = seriesRanges.filter {
            // this object most likely has a single date in its dateRanges, but sets somtimes have multiple issue dates and/or ranges, thus the list aspect
            // to evaluate which of our four choices is the valid series, we want to apply each range from dateRanges to 
            //   the above OpenDateRange objects (using Closed for now) and get the "majority" vote
            // I'm not aware of any set split over series boundaries, so this shouldn't be a problem
            for rng in dateRanges {
                let v1 = $0.contains(rng.lowerBound)
                let v2 = $0.contains(rng.upperBound)
                if v1 || v2 {
                    // T: one of the bounds of one of this object's dateRanges is in this series range
                    return true
                }
            }
            // F: this series range does NOT overlap any of the date ranges in this object
            return false
        }
        let result = resultX.map { x -> String in
            // we are passed the seriesRange object, we want to extract the year of the lowerBound and show it as "YYYY+"
            let gc = Calendar(identifier: .gregorian)
            let date = x.lowerBound
            let yy = gc.component(.year, from: date)
            let result_ = "\(yy)+"
            return result_
        }
        return result.first ?? "Unknown"
    }
    
    // a multiline string containing a sheet description for each sheet in the set (as best we know it from the BT detail data)
    var fullSheetDetails: String {
        var tempList = [String]()
        let series = sheetSeries
        let pnlist = plateNumberList
        let sflist = sheetFormatList
        let sheetFormat = sflist.first ?? "(Unknown)" // first is probably most used in the bigger sets (less hand fixup)
        let N = pnlist.count
        for M in 0..<N {
            let P = pnlist[M]
            let numstr = N == 1 ? "" : " (#\(M+1)/\(N))"
            let result = "Full sheet\(numstr) [Pl.No.\(P) (\(series)), Format=\(sheetFormat)] Design:\(data["designers"]!)"
            tempList.append(result)
        }
        return tempList.joined(separator: "\n")
    }
    
}
