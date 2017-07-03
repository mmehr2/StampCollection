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

// print album ref data object (with presplit ref as generated by AlbumFamilyNavigator)
func printAlbumData(_ data: [String:String]) {
    print("Album reference: \(data)")
}

// create modified page data object by adding an offset to the albumPage (default inc by 1)
func offsetAlbumPageInData(_ data_: [String:String], by offset:Int = 1) -> [String:String] {
    var data = data_
    guard let numstr = data["albumPage"] else { return data }
    let number = numstr.components(separatedBy: ".")
    if let numint = Int(number[0]) {
        // NOTE: even if there was an extension on the old page number, we will ignore it when creating the new page number, only using the base number
        data["albumPage"] = "\(numint + offset)"
    }
    return data
}

// create modified page data object by adding an offset to the albumPage extension (after the '.') (default inc by 1)
// NOTE: if current page has no extension, creates it at .1 (ignoring offset)
func offsetAlbumPageExInData(_ data_: [String:String], by offset:Int = 1) -> [String:String] {
    var data = data_
    guard let numstr = data["albumPage"] else { return data }
    let number = numstr.components(separatedBy: ".")
    if number.count == 1 {
        // no ext page, start at .1, ignore offset
        data["albumPage"] = "\(number[0]).1"
    } else if let numint = Int(number[1]) {
        data["albumPage"] = "\(number[0]).\(numint + offset)"
    }
    return data
}

// create modified page data object by adding an offset to the albumRef numeric suffix (default inc by 1)
// NOTE: if no numeric portion exists, one is created at 1; this is used internally when creating a new album family in code (the existing data has been modified to use no blank refs)
func offsetAlbumIndexInData(_ data_: [String:String], by offset:Int = 1, restartPages: Bool = false) -> [String:String] {
    // this will increment the numeric portion of the index portion of the albumRef field in the data
    guard let albumRef = data_["albumRef"] else {
        // give up, no changes (silently) if no albumRef provided
        return data_
    }
    let numstr = AlbumRef.getIndex(fromRef: albumRef)
    let family = AlbumRef.getFamily(fromRef: albumRef)
    var data = data_
    if let numint = Int(numstr) {
        data["albumRef"] = AlbumRef.makeCode(fromFamily: family, andNumber: numint + offset)
        data["albumFamily"] = family
    } else {
        // current number didn't exist (internal use only), assume unnumbered first item is always 1
        data["albumRef"] = AlbumRef.makeCode(fromFamily: family, andNumber: 1)
        data["albumFamily"] = family
    }
    // NOTE: since we have created a new album here (continuing the same section as before), we must also increment the page number to prevent duplicate page codes
    // since it is possible that other patterns will emerge for using this function, this can be commented out, but some way of preventing duplicates must be assured
    if restartPages {
        // sometimes, the page should be set to the beginning
        data["albumPage"] = "1"
    } else {
        data = offsetAlbumPageInData(data)
    }
    return data
}

func addPageOneOfNewSection(_ secname: String, toAlbumData data: [String:String]) -> [String:String] {
    var albumData = data
    albumData["albumSection"] = secname
    return albumData
}

func addPageOneOfNewSection(_ secname: String, toNextAlbumData data: [String:String]) -> [String:String] {
    var albumData = data
    albumData["albumSection"] = secname
    return offsetAlbumIndexInData(albumData, by: 1, restartPages: true)
}

func addPageOneOfSection(_ secname: String, toNewAlbumFamily familyName: String, ofType familyType: String, withData data: [String:String]) -> [String:String] {
    var albumData = data
    albumData["albumSection"] = secname
    albumData["albumType"] = familyType
    albumData["albumRef"] = familyName // this is ok for internal use, will create a ref to album #1 of family
    return offsetAlbumIndexInData(albumData, by: 0, restartPages: true)
}
