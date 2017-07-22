//
//  BTDealerItem.swift
//  StampCollection
//
//  Created by Michael L Mehr on 4/19/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import Foundation

private let CATNUM_SETS = 2 // belongs in constants list somewhere else
private let CATNUM_JS = 29

class BTDealerItem: NSObject {
    var code = ""
    var descr = ""
    var catalog1 = ""
    var catalog2 = ""
    var price1 = ""
    var price2 = ""
    var price3 = ""
    var price4 = ""
    var buy1 = ""
    var buy2 = ""
    var buy3 = ""
    var buy4 = ""
    var oldprice1 = ""
    var oldprice2 = ""
    var oldprice3 = ""
    var oldprice4 = ""
    var status = ""
    var picref = ""
    var catnum = 0
    
    var details: BTItemDetails?
    
    var leafletList: String {
        return details?.leafletList.joined(separator: ",") ?? ""
    }

    var isJS: Bool {
        if code.characters.count > 2 {
            return code.hasPrefix("AUI")
        }
        return false
    }
    
    var picPageURL: URL? {
        return getPicRefURL(picref, refType: isJS ? .jsRef  : .btRef)
    }
    
    var picFileRemoteURL: URL? {
        return getPicFileRemoteURL(picref, refType: isJS ? .jsRef  : .btRef, category: catnum)
    }
    
    func getThePicFileLocalURL(_ btcatnum: Int) -> URL? {
        let catgDisplayNum = BTCategory.translateNumberToInfoCategory(btcatnum)
        return getPicFileLocalURL(picref, refType: isJS ? .jsRef  : .btRef, category: catgDisplayNum)
    }
    
    func fixupJSItem() {
        catnum = CATNUM_JS
        // synthesize a status field for JS data
        let hasMint = (price1 != "N/A")
        let hasFDC = (price2 != "N/A")
        switch (hasMint, hasFDC) {
        case (false, false): status = "Sold out"
        case (true, false): status = "Mint only"
        case (false, true): status = "FDC only"
        case (true, true): status = "In stock"
        //default: status = "" // never occurs; stupid Swift compiler
        }
        // NOTE: JS code will remove all leading and trailing white space
        // synthesize leading and trailing buy fields
        // (convention copied on 5/21/2015)
        // need to split off the index number from the picref field:
        if let indexStr = picref.components(separatedBy: "=").last, let index = Int(indexStr) {
            if hasMint {
                buy1 = "judaica/austrian.asp?on_load=1&UC_AddId=\(index)"
            }
            if hasFDC {
                buy2 = "judaica/austrian.asp?on_load=1&UC_AddId3=\(index)"
            }
        }
    }
    
    
    func fixCatField(_ catfieldx: String, Named fname: String, WithID id: String) -> String
    {
        // returns fixed-up version of catfield, which is a string of ranges separated by commas
        var retval = catfieldx
        // make sure we are in proper catalog format; if not, just return field as-is
        // length must be longer than prefix length (2)
        let cflen = retval.characters.count
        if cflen < 2 { return retval }
        // TBD: first char must be a known catalog abbreviation code (this info can change slowly over time as BT adds catalog references)
        // second char must be a space
        let rvidx1 = retval.index(after: retval.startIndex)
        if retval[rvidx1...rvidx1] != " " { return retval }
        // split the prefix (cat type and space) from the data
        var splitIndex = catfieldx.index(after: catfieldx.characters.index(after: catfieldx.startIndex))
        let prefix = catfieldx.substring(to: splitIndex)
        let catfield = catfieldx.substring(from: splitIndex)
        let (part1, part2) = splitNumericEndOfString(catfield)
        let lencf = part2.characters.count
        let is8digitField = lencf == 8 && part1.isEmpty
        // the function detects the need for missing commas, and puts them in the proper places
        // the type (field name 'cat1' or 'cat2') and ID fields are used to detect certain known problems that don't fit the rules,
        // ERROR ARRAY:
        //   [0] is offset into catfield (ignoring prefix chars such as 'S ' or 'C ')
        //   [1] is 'sub' for substitution, or 'ins' for insertion
        //   [2] is the string to substitute, currently all a single comma
        //   [3] is a flag that controls if the rule is used if found in the input
        //     NOTE: This, while not strictly needed, prevents the default RULE1 from ever being looked up in input.
        let errorIDs = [
            "6110s377cat2" : (3,"sub",",", true),
            "6110s665cat2" : (4,"ins",",", true),
            "6110s717cat2" : (5,"ins",",", true),
            "6110s796cat2" : (7,"ins",",", true),
            "6110s846cat1" : (7,"ins",",", true),
            "6110s846cat2" : (8,"ins",",", true),
            "RULE1"        : (4,"ins",",", false),
        ]
        // otherwise a rule-based approach is used
        // Rule #1 - detect 8-digit strings, insert comma after digit #4
        // (currently no other rules are implemented, just the above exceptions)
        let exceptionKey = id + fname
        let (pos, type, char, found) = errorIDs[exceptionKey] ?? errorIDs["RULE1"]!
        let len = char.characters.count
        // determine if we should do this at all
        var ok = is8digitField || found // yes if we have 8 digits (use Rule#1) OR if we found another rule via lookup
        // double-check if the problem hasn't already been corrected by BT or us (found case)
        if ok {
            let idx1 = catfield.index(catfield.startIndex, offsetBy: pos)
            let idx2 = catfield.index(idx1, offsetBy: len)
            let catchr = catfield[idx1..<idx2]
            if catchr == char {
                // we're done, right character in position
                ok = false
            }
        }
        // if we're still good to go, do the substitution or insertion
        if ok {
            let startIndex = catfield.startIndex
            splitIndex = catfield.index(startIndex, offsetBy: pos)
            retval = prefix + catfield[startIndex..<splitIndex] + char
            if type == "sub" {
                // only diff between ins and sub is where we pick up the tail from
                // ins means keep the entire tail (splitIndex doesn't move)
                // whereas with sub, we must advance splitIndex past the same number of chars that were in 'char' string (len)
                splitIndex = catfield.index(splitIndex, offsetBy: len)
            }
            retval += catfield[splitIndex..<catfield.endIndex]
        }
        return retval
    }
    
    func fixupBTItem(_ btcatNumber: Int) {
        catnum = btcatNumber
        let isSets = btcatNumber == CATNUM_SETS
        if isSets {
            catalog1 = fixCatField(catalog1, Named: "cat1", WithID: code)
            catalog2 = fixCatField(catalog2, Named: "cat2", WithID: code)
        }
        descr = trimSpaces(descr)
        status = trimSpaces(status)
    }
    
    func createInfoItem(_ category: BTCategory) -> [String:String] {
        // NOTE: be sure to use export names for all properties (i.e. description NOT descriptionX) to be comparable with the output of makeDataFromObject()
        var output : [String:String] = [:]
//        let isJS = (code[0...2] == "AUI")
        output["id"] = code
        output["description"] = trimSpaces(descr)//descr // TBD: needed to fix bug in initial download of data, but can be eliminated once fixupBTItem() is refreshed again 6/8/2015
        output["status"] = status
        output["pictype"] = isJS ? "1" : "0" // 1 is JS type, 0 is BT
        output["pictid"] = picref.components(separatedBy: "=").last ?? ""
        output["cat1"] = catalog1
        output["cat2"] = catalog2
        output["group"] = category.name
        // NOTE TO SELF 5/20/2015: Since my INFO category #s were defined, BT added one in the middle that I don't collect ( one of the cancellations categories )
        // This translation function is designed to go back and forth between the numbering schemes for now
        // TBD eventually I should scrap the need for this and just use the new numbers, but since they are so pervasive, I'm avoiding this for now
        // The result of translation is set to -1 if no corresponding category exists in the old scheme (I should probably ASSERT/crash at that point, and make myself fix the situation in code!)
        let catnumX = BTCategory.translateNumberToInfoCategory(category.number)
        output["CatgDisplayNum"] = "\(catnumX)"
        // price columns for a category can be P, PU, PF, or PUFS; pick the appropriate one from the headers array
        // NOTE: Anomaly - new BT info classes (designed 2015) differ from CSV format (designed 2011) in that:
        //   1. Web site always imports category headers directly from table titles, so Price/PriceUsed or Price/PriceFDC for 2-price cases
        //   2. Then it always translates the title into the same code (price1 for Price, price2 for PriceFDC, price3 for PriceUsed
        //   3. So, in a category like Ex Show Cards (using PU), price2 will be blank and price3 will have the used price
        //   4. In Sets, YearSets, and Varieties (all four present), price2 will be the FDC price and price3 the Used price
        //   5. Thus, the web data always imports as PFUS, so PU uses 1+3, PUFS uses 1+3+2+4 - these violate the CSV assumptions
        // In the import/export CSV design, the PHP code always filled in the lowest numbered codes 1st, so ..
        //   1. CSV would show PU as price1 and price2
        //   2. PF would be price1 and price2 as well
        //   3. Sets YrSets and Vars would use PUFS always as 1+2+3+4
        // So to make the correspondence work, any PU or PUFS cats need to adjust here (swap 2 and 3, or just move 3 to 2 in the PU case)
        let foundPU = category.headers.index(of: "PriceUsed") != nil
        if foundPU && !isJS {
            // in cases where PriceUsed appears, the Info/CSV form will be PU or PUFS
            // the Web form is always PFUS (so for PU, price2 is always blank)
            // by swapping the 2 and 3 fields when Used is in the mix, we give the Info object the order it wants
            output["price1"] = price1
            output["price2"] = price3 // SWAP
            output["price3"] = price2 // SWAP
            output["price4"] = price4
            output["buy1"] = buy1 == "" ? "0" : "1"
            output["buy2"] = buy3 == "" ? "0" : "1" // SWAP
            output["buy3"] = buy2 == "" ? "0" : "1" // SWAP
            output["buy4"] = buy4 == "" ? "0" : "1"
            output["oldprice1"] = oldprice1
            output["oldprice2"] = oldprice3 // SWAP
            output["oldprice3"] = oldprice2 // SWAP
            output["oldprice4"] = oldprice4
        } else {
            output["price1"] = price1
            output["price2"] = price2
            output["price3"] = price3
            output["price4"] = price4
            output["buy1"] = buy1 == "" ? "0" : "1"
            output["buy2"] = buy2 == "" ? "0" : "1"
            output["buy3"] = buy3 == "" ? "0" : "1"
            output["buy4"] = buy4 == "" ? "0" : "1"
            output["oldprice1"] = oldprice1
            output["oldprice2"] = oldprice2
            output["oldprice3"] = oldprice3
            output["oldprice4"] = oldprice4
        }
        return output
    }
    
    class func translatePropertyName( _ pname: String ) -> String {
        switch pname {
        case "ItemCode": return "code"
        case "Description": return "descr"
        case "Catalog1": return "catalog1"
        case "Catalog2": return "catalog2"
        case "Price": return "price1"
        case "Buy": return "buy1"
        case "OldPrice": return "oldprice1"
        case "PriceFDC": return "price2"
        case "BuyFDC": return "buy2"
        case "OldPriceFDC": return "oldprice2"
        case "PriceUsed": return "price3"
        case "BuyUsed": return "buy3"
        case "OldPriceUsed": return "oldprice3"
        case "PriceOther": return "price4"
        case "BuyOther": return "buy4"
        case "OldPriceOther": return "oldprice4"
        case "Status": return "status"
        case "Pic": return "picref"
            
        case "picref": return "Pic"
        case "status": return "Status"
        case "oldprice4": return "OldPriceOther"
        case "buy4": return "BuyOther"
        case "price4": return "PriceOther"
        case "oldprice3": return "OldPriceUsed"
        case "buy3": return "BuyUsed"
        case "price3": return "PriceUsed"
        case "oldprice2": return "OldPriceFDC"
        case "buy2": return "BuyFDC"
        case "price2": return "PriceFDC"
        case "oldprice1": return "OldPrice"
        case "buy1": return "Buy"
        case "price1": return "Price"
        case "catalog2": return "Catalog2"
        case "catalog1": return "Catalog1"
        case "descr": return "Description"
        case "code": return "ItemCode"
            //        case "xxx": return "xxx"
        default: return ""
        }
    }
    
    class func translatePropertyNameJS( _ pname: String ) -> String {
        // HEADERS [Item#, Pic, Description, Mint, FDC]
        switch pname {
        case "Item#": return "code"
        case "Description": return "descr"
        case "Mint": return "price1"
        case "FDC": return "price2"
        case "Pic": return "picref"
            
        case "picref": return "Pic"
        case "price2": return "FDC"
        case "price1": return "Mint"
        case "descr": return "Description"
        case "code": return "Item#"
            //        case "xxx": return "xxx"
        default: return ""
        }
    }
    
    class func getExportNameList() -> [String] {
        var output : [String] = []
        //In Defined Order for CSV file:
        // id, description, status,pictid, pictype,XXXgroup-REMOVED!, cat1,cat2, price1,price2,price3,price4, buy1,buy2,buy3,buy4, oldprice1,oldprice2,oldprice3,oldprice4, CatgDisplayNum
        output.append("code")
        output.append("descr")
        output.append("status")
        output.append("picref")
        output.append("catalog1")
        output.append("catalog2")
        output.append("price1")
        output.append("price2")
        output.append("price3")
        output.append("price4")
        output.append("buy1")
        output.append("buy2")
        output.append("buy3")
        output.append("buy4")
        output.append("oldprice1")
        output.append("oldprice2")
        output.append("oldprice3")
        output.append("oldprice4")
        output.append("catgDisplayNum")
        return output
    }
    
    func getExportData(_ catnum: Int) -> [String:String] {
        var output:[String:String] = [:]
        output["catgDisplayNum"] = "\(catnum)"
        output["code"] = self.code
        output["descr"] = self.descr
        output["status"] = self.status
        output["picref"] = self.picref
        output["catalog1"] = self.catalog1
        output["catalog2"] = self.catalog2
        output["price1"] = self.price1
        output["price2"] = self.price2
        output["price3"] = self.price3
        output["price4"] = self.price4
        output["buy1"] = self.buy1
        output["buy2"] = self.buy2
        output["buy3"] = self.buy3
        output["buy4"] = self.buy4
        output["oldprice1"] = self.oldprice1
        output["oldprice2"] = self.oldprice2
        output["oldprice3"] = self.oldprice3
        output["oldprice4"] = self.oldprice4
        return output
    }
    
    func importFromData(_ data: [String:String]) -> Int {
        let refObj = self
        var catnum = -1
        if let inputStr = data["code"] { refObj.code = inputStr }
        if let inputStr = data["descr"] { refObj.descr = inputStr }
        if let inputStr = data["status"] { refObj.status = inputStr }
        if let inputStr = data["picref"] { refObj.picref = inputStr }
        if let inputStr = data["catalog1"] { refObj.catalog1 = inputStr }
        if let inputStr = data["catalog2"] { refObj.catalog2 = inputStr }
        if let inputStr = data["price1"] { refObj.price1 = inputStr }
        if let inputStr = data["price2"] { refObj.price2 = inputStr }
        if let inputStr = data["price3"] { refObj.price3 = inputStr }
        if let inputStr = data["price4"] { refObj.price4 = inputStr }
        if let inputStr = data["buy1"] { refObj.buy1 = inputStr }
        if let inputStr = data["buy2"] { refObj.buy2 = inputStr }
        if let inputStr = data["buy3"] { refObj.buy3 = inputStr }
        if let inputStr = data["buy4"] { refObj.buy4 = inputStr }
        if let inputStr = data["oldprice1"] { refObj.oldprice1 = inputStr }
        if let inputStr = data["oldprice2"] { refObj.oldprice2 = inputStr }
        if let inputStr = data["oldprice3"] { refObj.oldprice3 = inputStr }
        if let inputStr = data["oldprice4"] { refObj.oldprice4 = inputStr }
        if let inputStr = data["catgDisplayNum"], let inputNum = Int(inputStr) { catnum = inputNum }
        return catnum
    }
}
