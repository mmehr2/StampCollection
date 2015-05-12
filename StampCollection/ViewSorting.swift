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

extension SortType: Printable {
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
        return asc ? name + "Asc" : name + "Dsc"
    }
}

protocol ImportSortable {
    // compare added property called exOrder
    var exOrder: Int16 { get }
}

private func isOrderedByImport( ob1: ImportSortable, ob2: ImportSortable ) -> Bool {
    return ob1.exOrder < ob2.exOrder
}

protocol CodeSortable {
    // compare computed property called normalizedCode
    // this should create a string that is always the same length, contains all hidden assumptions explicitly (missing '1'), and pads all numeric fields with leading zeroes
    var normalizedCode: String { get }
}

private func isOrderedByCode( ob1: CodeSortable, ob2: CodeSortable ) -> Bool {
    return ob1.normalizedCode < ob2.normalizedCode
}

protocol DateSortable {
    // compare computed property called normalizedCode
    // this should create a string that is always the same length and causes the desired sort order
    // for example, it should decide what to do with items that have no encoded date to be extracted
    var normalizedDate: String { get }
}

private func isOrderedByDate( ob1: DateSortable, ob2: DateSortable ) -> Bool {
    return ob1.normalizedDate < ob2.normalizedDate
}

protocol SortTypeSortable : CodeSortable, DateSortable, ImportSortable { }

private func isOrderedBySortType( type: SortType, ob1: SortTypeSortable, ob2: SortTypeSortable ) -> Bool {
    switch type {
    case .ByImport(let asc): asc ? isOrderedByImport(ob1, ob2) : isOrderedByImport(ob2, ob1)
    case .ByCode(let asc): asc ? isOrderedByCode(ob1, ob2) : isOrderedByCode(ob2, ob1)
    case .ByDate(let asc): asc ? isOrderedByDate(ob1, ob2) : isOrderedByDate(ob2, ob1)
    default: break
    }
    return false
}

func sortCollection<T: SortTypeSortable>( coll: [T], byType type: SortType) -> [T] {
    switch type {
    case .None: return coll
    default: break
    }
    return coll.sorted{
        return isOrderedBySortType(type, $0, $1)
    }
}