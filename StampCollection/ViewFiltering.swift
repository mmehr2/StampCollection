//
//  ViewFiltering.swift
//  StampCollection
//
//  Created by Michael L Mehr on 5/1/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import Foundation

// functions to support search filtering of memory objects (INFO, INVENTORY) using programmable criteria

// the various enums encode common use case types that are needed to implement the various filtered views

// most of these are dependent on particular categories of records, as well

enum WantHaveType: Printable {
    case All, Haves, Wants
    
    var nextState: WantHaveType {
        switch self {
        case .All: return .Haves
        case .Haves: return .Wants
        case .Wants: return .All
        }
    }
    
    var description: String {
        switch self {
        case .All: return "All"
        case .Haves: return "Haves"
        case .Wants: return "Wants"
        }
    }
}

enum SearchType: Printable {
    case None // includes all items of a particular type (INFO or INVENTORY)
    case Category(Int16) // checks the catgDisplayNum field (-1 is shorthand for all)
    case MultiCategory([Int16]) // same, but includes multiple categories (related in some way)
    case SubCategory(String) // checks relevant id/code fields to define useful subcategory groupings
    case Catalog(String) // checks the catalog fields for various kinds of matches
    case YearInRange(ClosedInterval<Int>) // compares extracted date to range of years N...M, where N==M allowed
    case KeyWordListAll([String]) // filters for keyword existence in description fields (all words)
    case KeyWordListAny([String]) // filters for keyword existence in description fields (any word)
    // INVENTORY-SPECIFIC QUERIES
    case WantHave(WantHaveType) // INV wantHave field filtering
    case Location(String) // looks at any/all the location fields (type,ref,sec,page)
    case Price(String) // filtering based on price/value comparisons
    
    var requiresBaseLookup : Bool {
        switch self {
        case Catalog: return true
        case YearInRange: return true
        case KeyWordListAll: return true
        case KeyWordListAny: return true
        case Price: return true
        default: return false
        }
    }
    
    static func anyRequireBaseLookup( types: [SearchType] ) -> Bool {
        return types.reduce(false) { (total, type) in
            total || type.requiresBaseLookup
        }
    }
    
    var description: String {
        switch self {
        case .None: return "All Items"
        case .Category(let catnum):
            return "In Category \(catnum)"
        case .KeyWordListAll(let words):
            let list = " ".join(words)
            return "By Words [ALL]:\(list)"
        case .KeyWordListAny(let words):
            let list = " ".join(words)
            return "By Words [ANY]:\(list)"
        case .YearInRange(let range):
            return "By Years \(range.start):\(range.end)"
        case .WantHave(let whtype):
            return "Only \(whtype)"
        case .MultiCategory:
            return "By MultiCategory Unimplemented"
        case .SubCategory:
            return "By SubCategory Unimplemented"
        case .Catalog:
            return "By Catalog Unimplemented"
        case .Location:
            return "By Location Unimplemented"
        case .Price:
            return "By Price Unimplemented"
        default:
            return "Unknown search type"
        }
    }
}

// MARK: Individual search type functions - INFO
// MARK: search Category
protocol CatCompable {
    var catgDisplayNum: Int16 {get}
}

extension DealerItem : CatCompable { }
extension InventoryItem : CatCompable { }

private func CompareCategory<T: CatCompable>( type: SearchType, item: T ) -> Bool {
    var result = false
    switch type {
    case .Category(let catnum):
        if catnum == CollectionStore.CategoryAll { result = true }
        else { result = (item.catgDisplayNum == catnum) }
    default:
        break
    }
    return result
}

private func CompareMultiCategory<T: CatCompable>( type: SearchType, item: T ) -> Bool {
    var result = false
    switch type {
    case .MultiCategory(let catnums):
        // idea is to get OR of all categories in the list, so we run until we get a T (ret T) or F if all F
        for catnum in catnums {
            if CompareCategory( SearchType.Category(catnum), item ) {
                // 1st true results in total truth
                result = true
                break
            }
        }
    default:
        break
    }
    return result
}

// MARK: search any string for keywords
private func searchAny(input: String, For word: String) -> Bool
{
    if word == "" { return true }
    if word[0] != "@" { return input.contains(word) }
    // OPT: split word into two parts, optional leading TYPE field and rest is string to search for (word)
    // this prefix would specify use of beginsWith, endsWith, or the CI versions of all three
    // default is just plain "contains" searching
    var wlen = count(word)
    let codeSize = count("@@.@@") // general form of prefix code, . is a digit
    if wlen > codeSize {
        let code = word[0..<codeSize]
        let wordPart = word[codeSize..<wlen]
        switch code {
        case "@@0@@": return input.containsCI(wordPart)
        case "@@1@@": return input.beginsWith(wordPart)
        case "@@2@@": return input.beginsWithCI(wordPart)
        case "@@3@@": return input.endsWith(wordPart)
        case "@@4@@": return input.endsWithCI(wordPart)
        default: return input.contains(wordPart)
        }
    }
    return input.contains(word)
}

private enum CompareStringType { case UseAny, UseAll }
private func CompareStringForKeywords( input: String, words: [String], type: CompareStringType) -> Bool {
    var result = false
    switch type {
    case .UseAny:
        // idea is to get OR of all keywords, so we run until we get a T (ret T) or F if all F
        for word in words {
            if searchAny(input, For: word) {
                // 1st true results in total truth
                result = true
                break
            }
        }
    case .UseAll:
        // idea is to get AND of all keywords, so we run until we get a F (ret F) or T if all T
        result = true
        for word in words {
            if !searchAny(input, For: word) {
                // 1st false results in total falsehood
                result = false
                break
            }
        }
    default:
        break
    }
    return result
   
}

private func CompareDateInRange( input: String, range: ClosedInterval<Int> ) -> Bool {
    let (fmt, extractedRange) = extractYearRangeFromDescription(input)
    if fmt != 0 {
        let startInside = range.contains(extractedRange.start)
        let endInside = range.contains(extractedRange.end)
        if startInside && endInside {
            // fully contained
            return true
        }
    }
    return false
}

// MARK: search for INFO
private func CompareInfoSingle( types: [SearchType], item: DealerItem) -> Bool {
    var result = true
    for type in types {
        var eachResult = true
        switch type {
        case .Category(_): eachResult = CompareCategory( type, item )
        case .MultiCategory(_): eachResult = CompareMultiCategory( type, item )
        case .KeyWordListAll(let wordList):
            eachResult = CompareStringForKeywords(item.descriptionX, wordList, .UseAll)
        case .KeyWordListAny(let wordList):
            eachResult = CompareStringForKeywords(item.descriptionX, wordList, .UseAny)
        case .YearInRange(let range):
            eachResult = CompareDateInRange(item.descriptionX, range)
        default: eachResult = true
        }
        if !eachResult {
            // quit on 1st negative (ALL responses must be true to include item)
            result = false
            break
        }
    }
    return result
}

func filterInfo( coll: [DealerItem], types: [SearchType] ) -> [DealerItem] {
    return types.count == 0 ? coll : coll.filter { item in
        return CompareInfoSingle( types, item )
    }
}

// MARK: Individual search type functions - INVENTORY
private func CompareInvWantHave( type: SearchType, item: InventoryItem ) -> Bool {
    var result = false
    switch type {
    case .WantHave(let wht):
        if wht == .Haves && item.wantHave == "h" { result = true }
        if wht == .Wants && item.wantHave == "w" { result = true }
        break
    default:
        break
    }
    return result
}

// MARK: search for INVENTORY
private func CompareInvSingle( types: [SearchType], item: InventoryItem) -> Bool {
    var result = true
    var baseItem: DealerItem?
    if SearchType.anyRequireBaseLookup(types) {
        baseItem = CollectionStore.sharedInstance.fetchInfoItem(item.baseItem)
    }
    for type in types {
        var eachResult = true
        switch type {
        case .Category(_): eachResult = CompareCategory( type, item )
        case .MultiCategory(_): eachResult = CompareMultiCategory( type, item )
        case .KeyWordListAll(let wordList):
            eachResult = CompareStringForKeywords(baseItem!.descriptionX + item.desc + item.notes, wordList, .UseAll)
        case .KeyWordListAny(let wordList):
            eachResult = CompareStringForKeywords(baseItem!.descriptionX + item.desc + item.notes, wordList, .UseAny)
        case .YearInRange(let range):
            eachResult = CompareDateInRange(baseItem!.descriptionX, range) // date extraction only works on baseItem description field
        case .WantHave(_): eachResult = CompareInvWantHave( type, item )
        default: eachResult = true
        }
        if !eachResult {
            // quit on 1st negative (ALL responses must be true to include item)
            result = false
            break
        }
    }
    return result
}

func filterInventory( coll: [InventoryItem], types: [SearchType] ) -> [InventoryItem] {
    return types.count == 0 ? coll : coll.filter { item in
        return CompareInvSingle( types, item )
    }
}
