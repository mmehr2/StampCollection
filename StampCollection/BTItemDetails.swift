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
    private var data: InfoObject
    
    var dataObject: InfoObject {
        return data // publicly read-only
    }
    
    init(titleLine: String, infoLine: String) {
        // NOTE: All the processing work is done here.
        // Unfortunately, we can't make the object constant with 'let' because the compiler doesn't know these names are the only ones.
        // TBD - Is there a Swift 3?4? way to say this yet? I guess, make a class out of it and set up the fields in the init() call; nope we have done that, and it still needs to be mutable. Oh well...
        data =  [
                "xtitle" : "", //raw, temporary
                "info": "", //raw, temporary
                "titleRaw": "", //raw
                "ssCount": "",
                "jointWith": "",
                "subTitle": "",
                "xinfoRaw": "", //raw (all following)
                "issueDatesRaw": "", //raw
                "issueDates": "",
                "designersRaw": "", //raw
                "designers": "",
                "plateNumbersRaw": "", //raw
                "plateNumbers": "",
                "bulletinsRaw": "", //raw
                "bulletins": "",
                "leafletsRaw": "", //raw
                "leaflets": "",
                "sheetFormatRaw": "", //raw
                "numStamps": "",
                "numTabs": "",
                "souvenirSheetFormatRaw": "", //raw
                "ssWidth": "",
                "ssHeight": ""
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
        // * These CSV lists should be normalized to include all values, separated by commas, instead of the shorthand method used by the website; parse something like "255-7,263,279-81" into "255,256,257,263,279,280,281"
        //    NOTE: remember bulletins can have non-numeric suffixes too, and maybe the early leaflets too; see Morgenstein for the excruciating details!
        
        // create regex test patterns to apply
        let regexSheetFormat = Regex(pattern: "/^(\\d\\d*)s(\\s(\\d\\d*)t)+/") // typ:100s[ 10t], \1 and \3 are individual measurements (stamps and optional tabs)
        // the above if repeated, are separated by commas; this one should match only one pattern
        let regexSouvenirSheetFormat = Regex(pattern: "/^(\\d\\d*(\\.\\d)+)x(\\d\\d*(\\.\\d)+)cm$/") // typ: NN.nxMM.mcm -- extract \1 and \3 to get individual measurements
        let infoData = infoLine.components(separatedBy: "/")
        data["xtitle"] = titleLine
        data["info"] = infoData.joined(separator: "||") // temporary placeholder version
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
                } else if component.test(regexSheetFormat) {
                    parseSheetFormat(component)
                } else if component.test(regexSouvenirSheetFormat) {
                    parseSouvenirSheetFormat(component)
                } else {
                    print("Couldn't parse the DealerItem detailed info line: \(component)")
                }
            }
        }
    }
    
    func parseTitleField(_ input: String) {
        //
        print("Parse the Title field: \(input)")
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
    
    func parseDateList(_ input: String) {
        //
        print("Parse the Issue Date list: \(input)")
        
        data["issueDatesRaw"] = input
        
    }
    
    func parseDesignerList(_ input: String) {
        //
        print("Parse the Designer list: \(input)")
        
        data["designersRaw"] = input
        
    }
    
    func parsePlateNumberList(_ input: String) {
        //
        print("Parse the Plate Number list: \(input)")
        
        data["plateNumbersRaw"] = input
        
    }
    
    func parseBulletinList(_ input: String) {
        //
        print("Parse the Bulletin list: \(input)")
        
        data["bulletinsRaw"] = input
        
    }
    
    func parseLeafletList(_ input: String) {
        //
        print("Parse the Leaflet list: \(input)")
        
        data["leafletsRaw"] = input
        
    }
    
    func parseSheetFormat(_ input: String) {
        //
        print("Parse the Sheet Format list: \(input)")
        
        data["sheetFormatRaw"] = input
        
    }
    
    func parseSouvenirSheetFormat(_ input: String) {
        //
        print("Parse the Souvenir Sheet Format list: \(input)")
        
        data["souvenirSheetFormatRaw"] = input
        
    }
    
}

extension BTItemDetails: CustomStringConvertible {
    var description: String {
        var result = "Item details:\n"
        let obj = self.dataObject
        let keys = obj.keys.sorted()
        
        for k in keys {
            // in order, add the lines
            result += " \"\(k)\": \"\(obj[k]!)\"\n"
        }
        return result
    }
}
