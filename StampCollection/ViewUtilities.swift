//
//  ViewUtilities.swift
//  StampCollection
//
//  Created by Michael L Mehr on 4/25/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import Foundation

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

extension CollectionStore.FetchType : Printable {
    
    var description : String {
        switch self {
        case .Categories: return "Categories"
        case .Info: return "Info"
        case .Inventory: return "Inventory"
        }
    }
    
}