//
//  BTDealerItem.swift
//  StampCollection
//
//  Created by Michael L Mehr on 4/19/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import Foundation

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
    
    func createInfoItem(category: BTCategory) -> [String:String] {
        var output : [String:String] = [:]
        output["id"] = code
        output["descriptionX"] = descr
        output["status"] = status
        output["pictype"] = "0" // always BT type
        output["pictid"] = picref // actually this needs to be processed to get only the ID code
        output["cat1"] = catalog1
        output["cat2"] = catalog2
        output["group"] = category.name
        let catnumX = BTCategory.translateNumberToInfoCategory(category.number)
        output["catgDisplayNum"] = "\(catnumX)" // set to -1 if no corresponding category exists
        // price columns for a category can be P, PU, PF, or PUFS; pick the appropriate one from the headers array
        var foundPF = find(category.headers, "PriceFDC") != nil
        var foundPS = find(category.headers, "PriceOther") != nil
        if foundPF && !foundPS {
            // this is two-price situation with 2nd as FDC (needs some translation)
            output["price1"] = price1
            output["price2"] = price3
            output["price3"] = ""
            output["price4"] = price4
            output["buy1"] = buy1 == "" ? "0" : "1"
            output["buy2"] = buy3 == "" ? "0" : "1"
            output["buy3"] = "0"
            output["buy4"] = buy4 == "" ? "0" : "1"
            output["oldprice1"] = oldprice1
            output["oldprice2"] = oldprice3
            output["oldprice3"] = ""
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
    
    class func translatePropertyName( pname: String ) -> String {
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
}