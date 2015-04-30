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
    var ac = UIAlertController(title: title, message: body, preferredStyle: .Alert)
    let act = UIAlertAction(title: "OK", style: .Default) { x in
        // dismiss but do nothing
    }
    ac.addAction(act)
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

private func formatInventoryValue(item: InventoryItem, baseItem: DealerItem, cat: Category) -> String {
    // determine whether to return
    //  Mint v Used (cat.prices == PU)
    //  Mint(tab) v Used v FDC v Other (PUFS)
    //  Mint v FDC (PF)
    //  "" (P only)
    var output = "Val"
    let price = baseItem.valueForKey(item.itemType) as! String
    switch (cat.prices, item.itemType) {
    case ("P", "price1"): output += ""
    case ("PU", "price1"): output += ":Mint"
    case ("PU", "price2"): output += ":Used"
    case ("PF", "price1"): output += ":Mint"
    case ("PF", "price2"): output += ":OnFDC"
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
    if let cat = CollectionStore.sharedInstance.fetchCategory(Int(item.catgDisplayNum))
        , info = CollectionStore.sharedInstance.fetchInfoItem(item.baseItem) {
            let basedes = makeStringFit(info.descriptionX, 60)
            return "\(basedes) \(formatInventoryWantField(item)) \(formatInventoryLocation(item))"
    }
    return "\(formatInventoryWantField(item)) \(formatInventoryLocation(item))"
}

func formatInventoryDetail(item: InventoryItem) -> String {
    if let cat = CollectionStore.sharedInstance.fetchCategory(Int(item.catgDisplayNum))
        , info = CollectionStore.sharedInstance.fetchInfoItem(item.baseItem) {
            let basedes = makeStringFit(info.descriptionX, 60)
            return "\(item.baseItem) \(formatInventoryValue(item,info,cat)) \(formatInventoryVarCondition(item))"
    }
    return ""
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

func parseDealerCode( code: String, hintCategory: Int = -1 ) -> Int {
    // accepts code numbers of the following form:
    //  "6110xNNNyy" - will return the number part (NNN)
    //  "psNNNyy"
    var number = 0
    return number
}

func extractDateFromDesc( desc: String) -> String {
    // accepts different description formats:
    // 1) leading year "NNNN non-space-chars", just returns the year
    // 2) leading date (Euro) "DD.MM.YY non-space-chars", returns day month and year
    // 3) trailing date (Euro) "non-space-chars DD.MM.YY", returns day, month, and year
    var output = ""
    return output
}

