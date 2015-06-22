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
    
    var code: String {
        switch self {
        case .All: return "?"
        case .Haves: return "h"
        case .Wants: return "w"
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

enum SearchType {
    case None // includes all items of a particular type (INFO or INVENTORY)
    case Category(Int16) // checks the catgDisplayNum field (-1 is shorthand for all)
    case MultiCategory([Int16]) // same, but includes multiple categories (related in some way)
    case YearInRange(ClosedInterval<Int>) // compares extracted date to range of years N...M, where N==M allowed
    case KeyWordListAll([String]) // filters for keyword existence in description fields (all words)
    case KeyWordListAny([String]) // filters for keyword existence in description fields (any word)
    case SubCategory(String) // checks relevant id/code fields to define useful subcategory groupings
    case Catalog(String) // checks the catalog fields for various kinds of matches
    // INVENTORY-SPECIFIC QUERIES
    case WantHave(WantHaveType) // INV wantHave field filtering
    case Location(String) // looks at any/all the location fields (type,ref,sec,page)
    case Price(String) // filtering based on price/value comparisons
}

extension SearchType: Printable {
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
        case .MultiCategory(let catlist):
            let catlistX = ", ".join(catlist.map{ cat in
                "\(cat)" })
            return "In Categories: \(catlistX)"
        case .SubCategory(let pattern):
            return "In SubCategory Defined By \(pattern)"
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

extension SearchType {
    // convert to preicates

    func getPredicateForDataType( dataType: CollectionStore.DataType ) -> NSPredicate? {
        var output: NSPredicate?
        let dealerItemPrefix = dataType == .Inventory ? "dealerItem." : ""
        switch self {
        case .None:
            //output = NSPredicate(format: "TRUEPREDICATE")
            break
        case .Category(let catnum):
            // same for both INFO and INV
            output = NSPredicate(format: "%K = %@", "catgDisplayNum", NSNumber(short: catnum))
            break
        case .KeyWordListAll(let words):
            // naive implementation: AND a bunch of predicates, one for each key-to-word-value pair
            // actually this will NOT work, since it requires ALL the words to appear entirely in one of 3 fields
            // it will NOT allow mix-and-matching - ONLY WAY TO DO THIS IS CONCATENATE THE FIELDS FOR SEARCHING!
            // Until I can figure out how to do this, it will only check descriptionX in the dealerItem
            let target1 : String = dealerItemPrefix + "descriptionX"
            var subpredicates1 = getPredicatesForField(target1, inKeyWordList: words)
            var temp = NSCompoundPredicate.andPredicateWithSubpredicates(subpredicates1)
//            var subpredicates2 = dataType != .Inventory ? [] : (getPredicatesForField("desc", inKeyWordList: words))
//            if subpredicates2.count > 0 {
//                let out2 = NSCompoundPredicate.andPredicateWithSubpredicates(subpredicates2)
//                temp = NSCompoundPredicate.orPredicateWithSubpredicates([out2, temp])
//            }
//            var subpredicates3 = dataType != .Inventory ? [] : (getPredicatesForField("notes", inKeyWordList: words))
//            if subpredicates3.count > 0 {
//                let out3 = NSCompoundPredicate.andPredicateWithSubpredicates(subpredicates3)
//                temp = NSCompoundPredicate.orPredicateWithSubpredicates([out3, temp])
//            }
            output = temp
            break
        case .KeyWordListAny(let words):
            // naive implementation: OR a bunch of predicates, one for each key-to-word-value pair
            // for INV, also check the "desc" and "notes" fields
            // if ANY word appears in ANY field, the entire predicate is true
            let target1 : String = dealerItemPrefix + "descriptionX"
            let cival = true // not really sure how to use this, so just try it for now on ANY searches
            var subpredicates1 = getPredicatesForField(target1, inKeyWordList: words, caseInsensitive: cival)
            var subpredicates2 = dataType != .Inventory ? [] : (getPredicatesForField("desc", inKeyWordList: words, caseInsensitive: cival))
            var subpredicates3 = dataType != .Inventory ? [] : (getPredicatesForField("notes", inKeyWordList: words, caseInsensitive: cival))
            var subpredicates = subpredicates1 + subpredicates2 + subpredicates3
            var temp = NSCompoundPredicate.orPredicateWithSubpredicates(subpredicates)
            output = temp
            break
        /** NOTE: The reason this and other fetches like this aren't here is the need to use derived data and not just what is in the fields using the predicate programming language
            I cannot figure out a way to do this in a way that preprocesses the field, such as creating transient properties (cannot be used in predicates or sort descriptors)
            Thus, I am forced to implement features like this in Swift as a second step filtering; luckily the 1st step is quick and reduces the size of the data (WantHave, Category and KeyWordList)
            For more complicated searching and sorting, we will rely on Swift on the smaller data arrays. This assumption breaks down for the All Categories choice, but the user will wait when managing the entire dataset.
            
        case .YearInRange(let range):
            // prefix allows this to work with both INFO and INV
            let key1 = dealerItemPrefix + "exYearStart"
            let key2 = dealerItemPrefix + "exYearEnd"
            let val1 = NSNumber(integer: range.start)
            let val2 = NSNumber(integer: range.end)
            output = NSPredicate(format: "%K != 0 AND %K != 0 AND %K >= %@ AND %K <= %@", key1, key2, key1, val1, key2, val2)
            break
            **/
        case .WantHave(let whtype):
            // works for INV only
            let key = "wantHave"
            let value = whtype.code
            if value != "?" {
                output = NSPredicate(format: "%K = %@", key, value)
            }
            break
        case .MultiCategory(let catnums):
            // works with either INFO or INV
            var preds : [NSPredicate] = []
            for catnum in catnums {
                if let pred = SearchType.Category(catnum).getPredicateForDataType(dataType) {
                    preds.append(pred)
                }
            }
            if preds.count > 0  {
                output = NSCompoundPredicate.orPredicateWithSubpredicates(preds)
            }
            break
        case .SubCategory(let patternIn):
            // works with either INFO or INV
            let target = dealerItemPrefix + "id"
            // pattern can contain "shorthand" characters for ID searching
            let pattern = fillOutSubcatPattern(patternIn)
            output = NSPredicate(format: "%K MATCHES %@", target, pattern)
            break
//        case .Catalog:
//            output = NSPredicate(format: "TRUEPREDICATE")
//            break
//        case .Location:
//            output = NSPredicate(format: "TRUEPREDICATE")
//            break
//        case .Price:
//            output = NSPredicate(format: "TRUEPREDICATE")
//            break
        default:
            //output = NSPredicate(format: "TRUEPREDICATE")
            break
        }
        return output
    }
}

private func fillOutSubcatPattern( pattern: String ) -> String {
    var output = pattern
    output = output.replace("@", withTemplate: ".*")
    return output
}

private func getPredicatesForField( field: String, inKeyWordList words: [String], caseInsensitive cival: Bool = false ) -> [NSPredicate] {
    var output : [NSPredicate] = []
    for word in words {
        output.append( cival ?
            NSPredicate(format: "%K CONTAINS[c] %@", field, word) :
            NSPredicate(format: "%K CONTAINS %@", field, word) )
    }
    return output
}

func getPredicateOfType( dataType: CollectionStore.DataType, forSearchTypes types: [SearchType] ) -> NSPredicate? {
    var output : NSPredicate?
    // get the combined AND of all non-nil predicates (simplest use case)
    for type in types {
        if let pred = type.getPredicateForDataType(dataType) {
            if output == nil {
                output = pred
            } else {
                output = output! && pred
            }
        }
    }
    return output
}

// MARK: predicate operators
// simple predicate extensions to deal with making compound predicates
infix operator && {}
func &&( lhs: NSPredicate, rhs: NSPredicate) -> NSPredicate {
    return NSCompoundPredicate.andPredicateWithSubpredicates([lhs, rhs])
}

infix operator || {}
func ||( lhs: NSPredicate, rhs: NSPredicate) -> NSPredicate {
    return NSCompoundPredicate.orPredicateWithSubpredicates([lhs, rhs])
}

prefix operator ! {}
prefix func !( lhs: NSPredicate) -> NSPredicate {
    return NSCompoundPredicate.notPredicateWithSubpredicate(lhs)
}

// MARK: in-memory filtering

// pull out the SearchType objects that we are interested in
private func getMemorySearchTypes( types: [SearchType] ) -> [SearchType] {
    return types.filter { x in
        switch x {
        case .YearInRange(_): return true
        default: return false
        }
    }
}

private func CompareYearInRange( input: String, range: ClosedInterval<Int> ) -> Bool {
    let (fmt, extractedRange, _, _) = extractDateRangesFromDescription(input)
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

private func CompareInfoSingle( types: [SearchType], item: DealerItem) -> Bool {
    var result = true
    for type in types {
        var eachResult = true
        switch type {
        case .YearInRange(let range):
            eachResult = CompareYearInRange(item.descriptionX, range)
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
    let mtypes = getMemorySearchTypes(types)
    return mtypes.count == 0 ? coll : coll.filter { item in
        return CompareInfoSingle( mtypes, item )
    }
}

// MARK: Individual search type functions - INVENTORY
//private func CompareInvWantHave( type: SearchType, item: InventoryItem ) -> Bool {
//    var result = false
//    switch type {
//    case .WantHave(let wht):
//        if wht == .Haves && item.wantHave == "h" { result = true }
//        if wht == .Wants && item.wantHave == "w" { result = true }
//        break
//    default:
//        break
//    }
//    return result
//}

// MARK: search for INVENTORY
private func CompareInvSingle( types: [SearchType], item: InventoryItem) -> Bool {
    var result = true
    for type in types {
        var eachResult = true
        switch type {
        case .YearInRange(let range):
            eachResult = CompareYearInRange(item.dealerItem.descriptionX, range) // date extraction only works on baseItem description field
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
    let mtypes = getMemorySearchTypes(types)
    return mtypes.count == 0 ? coll : coll.filter { item in
        return CompareInvSingle( mtypes, item )
    }
}

