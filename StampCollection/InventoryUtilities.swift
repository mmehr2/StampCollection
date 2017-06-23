//
//  InventoryUtilities.swift
//  StampCollection
//
//  Created by Michael L Mehr on 6/20/17.
//  Copyright © 2017 Michael L. Mehr. All rights reserved.
//

import UIKit

enum PriceType {
    case mint
    case used
    case FDC(Bool)
    case mintNoTab
    
    var ptype: String {
        switch self {
        case .mint: return "price1"
        case .used: return "price2"
        case .mintNoTab: return "price4"
        case .FDC(let has4): return has4 ? "price3" : "price2"
        }
    }
    
    var pname: String {
        switch self {
        case .mint: return "Mint"
        case .used: return "Used"
        case .mintNoTab: return "M/NT"
        case .FDC(let has4): return has4 ? "FDC" : "OnFDC"
        }
    }
}

struct PriceUsage {
    let ptype: PriceType
    let numprices: Int
    
    init(_ type: PriceType, num: Int) {
        numprices = num
        switch type {
        case .FDC:
            ptype = .FDC(num > 2)
        default:
            ptype = type
        }
    }
}

