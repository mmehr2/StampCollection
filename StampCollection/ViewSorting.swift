//
//  ViewSorting.swift
//  StampCollection
//
//  Created by Michael L Mehr on 5/4/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import Foundation

enum SortType {
    case none // leaves Phase 1 (predicate) sorting intact
    case byImport(Bool) // needs to know Ascending or Descending
    case byCode(Bool) // needs to know Ascending or Descending
    case byCatThenCode(Bool) // needs to know Ascending or Descending
    case byPrice(Int, Bool) // needs to know which price to sort INFO by (INV should use Value sorting)
    case byDate(Bool) // needs to know Ascending or Descending
    // INV ONLY
    case byAlbum(Bool) // needs to know Ascending or Descending
    case byValue(Bool) // needs to know Ascending or Descending
}

extension SortType: CustomStringConvertible {
    var description: String {
        switch self {
        case .none: return "Default"
        case .byImport(let asc): return decide(asc, name: "Import")
        case .byCode(let asc): return decide(asc, name: "Code")
        case .byCatThenCode(let asc): return decide(asc, name: "Cat:Code")
        case .byPrice(let num, let asc): return decide(asc, name: "Price"+num.description)
        case .byDate(let asc): return decide(asc, name: "Date")
        case .byAlbum(let asc): return decide(asc, name: "INV:Album")
        case .byValue(let asc): return decide(asc, name: "INV:Value")
        }
    }
    
    fileprivate func decide( _ asc: Bool, name: String ) -> String {
        return asc ? name + "+" : name + "-"
    }
}

protocol ImportSortable {
    // compare added property called exOrder
    var exOrder: Int16 { get }
}

protocol CodeSortable {
    // compare computed property called normalizedCode
    // this should create a string that is always the same length, contains all hidden assumptions explicitly (missing '1'), and pads all numeric fields with leading zeroes
    var normalizedCode: String { get }
}

protocol DateSortable {
    // compare computed property called normalizedCode
    // this should create a string that is always the same length and causes the desired sort order
    // for example, it should decide what to do with items that have no encoded date to be extracted
    var normalizedDate: String { get }
}

protocol AlbumSortable {
    // compare existing properties for album location
    var albumType: String! { get }
    var albumRef: String! { get }
    var albumSection: String! { get }
    var albumPage: String! { get }
}

protocol SortTypeSortable : CodeSortable, DateSortable, ImportSortable { }
protocol SortTypeSortableEx : SortTypeSortable, AlbumSortable { }

func sortCollection<T: SortTypeSortable>( _ coll: [T], byType type: SortType) -> [T] {
    switch type {
    case .byImport(let asc):
        if asc {
            return coll.sorted{ $0.exOrder < $1.exOrder }
        } else {
            return coll.sorted{ $1.exOrder < $0.exOrder }
        }
    case .byCode(let asc):
        if asc {
            return coll.sorted{ $0.normalizedCode < $1.normalizedCode }
        } else {
            return coll.sorted{ $1.normalizedCode < $0.normalizedCode }
        }
    case .byDate(let asc):
        if asc {
            return coll.sorted{ $0.normalizedDate < $1.normalizedDate }
        } else {
            return coll.sorted{ $1.normalizedDate < $0.normalizedDate }
        }
    default: break
    }
    return coll
}

func sortCollectionEx<T: SortTypeSortableEx>( _ coll: [T], byType type: SortType) -> [T] {
    switch type {
    case .byImport(let asc):
        if asc {
            return coll.sorted{ $0.exOrder < $1.exOrder }
        } else {
            return coll.sorted{ $1.exOrder < $0.exOrder }
        }
    case .byCode(let asc):
        if asc {
            return coll.sorted{ $0.normalizedCode < $1.normalizedCode }
        } else {
            return coll.sorted{ $1.normalizedCode < $0.normalizedCode }
        }
    case .byDate(let asc):
        if asc {
            return coll.sorted{ $0.normalizedDate < $1.normalizedDate }
        } else {
            return coll.sorted{ $1.normalizedDate < $0.normalizedDate }
        }
    case .byAlbum(let asc):
        if asc {
            return coll.sorted{ return compareByAlbum($0, rhs: $1) }
        } else {
            return coll.sorted{ return compareByAlbum($1, rhs: $0) }
        }
    default: break
    }
    return coll
}

