//
//  ViewSorting.swift
//  StampCollection
//
//  Created by Michael L Mehr on 5/4/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import Foundation

enum SortType {
    case None // leaves Phase 1 (predicate) sorting intact
    case ByImport(Bool) // needs to know Ascending or Descending
    case ByCode(Bool) // needs to know Ascending or Descending
    case ByCatThenCode(Bool) // needs to know Ascending or Descending
    case ByPrice(Int, Bool) // needs to know which price to sort INFO by (INV should use Value sorting)
    case ByDate(Bool) // needs to know Ascending or Descending
    // INV ONLY
    case ByAlbum(Bool) // needs to know Ascending or Descending
    case ByValue(Bool) // needs to know Ascending or Descending
}

extension SortType: CustomStringConvertible {
    var description: String {
        switch self {
        case .None: return "Default"
        case .ByImport(let asc): return decide(asc, name: "Import")
        case .ByCode(let asc): return decide(asc, name: "Code")
        case .ByCatThenCode(let asc): return decide(asc, name: "Cat:Code")
        case .ByPrice(let num, let asc): return decide(asc, name: "Price"+num.description)
        case .ByDate(let asc): return decide(asc, name: "Date")
        case .ByAlbum(let asc): return decide(asc, name: "INV:Album")
        case .ByValue(let asc): return decide(asc, name: "INV:Value")
        }
    }
    
    private func decide( asc: Bool, name: String ) -> String {
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

func sortCollection<T: SortTypeSortable>( coll: [T], byType type: SortType) -> [T] {
    switch type {
    case .ByImport(let asc):
        if asc {
            return coll.sort{ $0.exOrder < $1.exOrder }
        } else {
            return coll.sort{ $1.exOrder < $0.exOrder }
        }
    case .ByCode(let asc):
        if asc {
            return coll.sort{ $0.normalizedCode < $1.normalizedCode }
        } else {
            return coll.sort{ $1.normalizedCode < $0.normalizedCode }
        }
    case .ByDate(let asc):
        if asc {
            return coll.sort{ $0.normalizedDate < $1.normalizedDate }
        } else {
            return coll.sort{ $1.normalizedDate < $0.normalizedDate }
        }
    default: break
    }
    return coll
}

func sortCollectionEx<T: SortTypeSortableEx>( coll: [T], byType type: SortType) -> [T] {
    switch type {
    case .ByImport(let asc):
        if asc {
            return coll.sort{ $0.exOrder < $1.exOrder }
        } else {
            return coll.sort{ $1.exOrder < $0.exOrder }
        }
    case .ByCode(let asc):
        if asc {
            return coll.sort{ $0.normalizedCode < $1.normalizedCode }
        } else {
            return coll.sort{ $1.normalizedCode < $0.normalizedCode }
        }
    case .ByDate(let asc):
        if asc {
            return coll.sort{ $0.normalizedDate < $1.normalizedDate }
        } else {
            return coll.sort{ $1.normalizedDate < $0.normalizedDate }
        }
    case .ByAlbum(let asc):
        if asc {
            return coll.sort{ return compareByAlbum($0, rhs: $1) }
        } else {
            return coll.sort{ return compareByAlbum($1, rhs: $0) }
        }
    default: break
    }
    return coll
}

