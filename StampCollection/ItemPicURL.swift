//
//  ItemPicURL.swift
//  StampCollection
//
//  Created by Michael L Mehr on 7/7/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import Foundation
import UIKit // but only for AppDelegate reference to app docs dir - remove ASAP!

// MARK: URL construction for pic pages and references (TBD: belongs in Network Model)
enum PicRefURLType {
    case btRef // format: "pic.php?ID=6110s4"
    case jsRef // format: "austrian_pic_detail.asp?index=17020" (for id="AUI001")
    case dlRef // format: "6110s4"
    case dljsRef // format: "N/A" for none, or "1a" for "ajt1a.jpg" local filename - no way back to picref 17XXX without table
    case unknown
}

/**
Design Note
===========
This feature was supposed to be looked up on the web (thus, its position in BTCollectionStore).
However, I noticed that it wasn't working in 10/2015 and looked into it further. Seems that the Dealer item  pictid was the same as the extracted picref index (staring with "170"). Thus it was doing nothing, and the table consisted of indexes referring to the same numbers (i.e. "17020":"17020", etc.
After further study, to do this feature dynamically, we would need another web script to parse the jpg file number from the picref page directly. Since it is only one category, and the data doesn't change often, I chose to code these numbers directly into the database (bundle's INFO.CSV file) by direct editing.
We still need to properly interpret the PictID field generated. It is now of the form:
    "17020=1a", where 17020 is used to generate the web pic page href, and the 1a generates the download image file name "ajt1a.jpg". The paths are hard-coded here, same as before.
*/
// this table will be indexed by DealerItem pictid ("5c" or "2") and get you a page ref ID ("17020" or "17054")
private var jsDictionary: [String: String] = [:]
// this table will be indexed by page ref ID ("17020" or "17054") and get you a DealerItem pictid ("5c" or "2")
private var jsRevDictionary: [String: String] = [:]

func splitJSPictID( _ pictid: String ) -> (dbRefID: String, fileRefID: String?) {
    let comps = pictid.components(separatedBy: CharacterSet(charactersIn: "="))
    guard comps.count > 1 else {
        return (comps.first ?? "", nil)
    }
    return (comps.first ?? "", comps.last)
}

private func setJSDictionaryEntry( _ pictid: String, picref: String ) {
    // at this point, picref comes from the web (BTCategory) and pictid from the database (Category)
    // for setting up the table just from the DB side, the picref is optionally empty
    // we have set up pictid in the form "X=Y" where X is the 5-digit ref ID (17020) and Y is the file ref
    //   code (such as 5 or 17a)
    // the extracted picref is of the form "path/something.asp=17020"
    // what we wish to do here is
    // 1) extract the webID from picref, if it is nonempty (17020)
    // 2) split the pictID into its X and Y parts (dbRefID and fileRefID)
    // 3) if there is a webID, verify that dbRefID and webID match (non-match prevents step 4)
    // 4) save the two dictionary entries: forward is dbRefID -> fileRefID, reverse is fileRefID -> dbRefID
    // NOTE: some entries in the DB have no pics, and are specified without the =Y part
    // For these, we do not want a dictionary entry
    // NOTE: We want to populate this solely from the pictid field in some cases, so picref.isEmpty is allowed
    // In this case, just parse the dbRefID and fileRefID without the webID check
    if pictid != "N/A" {
        let comps = picref.components(separatedBy: CharacterSet(charactersIn: "="))
        let webID = comps.last
        let hasWebID = (webID != nil) && comps.count > 1
        let (dbRefID, fileRefID) = splitJSPictID(pictid)
        let hasFileID = (fileRefID != nil)
        var allow = false
        switch (hasWebID, hasFileID) {
        case (true, true):
            // both IDs exist: test for match to allow dictionary entries
            allow = (dbRefID == webID!)
            break
        case (false, true):
            // we have no webID, but do have a pic file ref (and dbID)
            // just make the dictionary entries
            allow = true
            break
        case (_, false):
            // we have a webID but there is no pic file ref - no dictionary
            // no webID and no pic file ref - no dictionary
            break
        }
        if let fileRefID = fileRefID {
            if allow {
                jsDictionary[dbRefID] = fileRefID
                jsRevDictionary[fileRefID] = dbRefID
            }
        } else if hasWebID {
            print("No matching ref found for [webID=\(webID!) vs.dbRefID=\(dbRefID)]")
        } else {
            print("No pic file entry created for [dbRefID=\(dbRefID)]")
        }
    }
}

// this function should be called first before using getPicRefURL() with refs of type .DLJSRef (the CoreData JS info items)
func populateJSDictionary( _ jsDealerCat: Category, jsWebCat: BTCategory? = nil ) {
    if let items = Array(jsDealerCat.dealerItems) as? [DealerItem] {
        // set up cache of IDs to locate BTDealerItems by ID
        var jsToBTIDCache: [String: String] = [:]
        let dataItems = jsWebCat?.getAllDataItems() ?? []
        for btitem in dataItems {
            jsToBTIDCache[btitem.code] = btitem.picref
        }
        // quick unit-test (hard to test this w.Xcode unit tests due to private vars)
//        setJSDictionaryEntry("17020=2c", picref: "tellmeabout=17020") // maps 17020 to 2c and back
//        setJSDictionaryEntry("17020", picref: "tellmeabout=17020") // maps 17020 to 17020 and back
//        setJSDictionaryEntry("17020=2b", picref: "tellmeabout=17021") // creates no mapping, prints err
//        setJSDictionaryEntry("17020=2a", picref: "") // maps 17020 to 2a and back
//        setJSDictionaryEntry("17020=2d", picref: "tellmesome") // maps 17020 to 2d and back
//        setJSDictionaryEntry("N/A", picref: "anything") // creates no mapping or print
//        setJSDictionaryEntry("", picref: "") // creates no mapping or print: ACTUALLY CREATES EMPTY MAP
        // set up pictid-to-fileref mapping array for later use
        for item in items {
            let idcode = item.id // matching ID to look up in BT cache
            let btpicref = jsToBTIDCache[idcode!] ?? ""
            setJSDictionaryEntry(item.pictid, picref: btpicref)
        }
    }
}

// this utility function should be called by item classes and not directly
// it will turn a pic reference string in one of the four types into a full NSURL for the page that shows that pic (along with other formatted info from the dealer website)
func getPicRefURL( _ picref: String, refType type: PicRefURLType ) -> URL? {
    // BT style: "http://www.bait-tov.com/store/" plus the formatted link from BTRef
    // JS style: "http://www.judaicasales.com/judaica/" plus the formatted link from JSRef
    var output: URLComponents! = nil
    if !picref.isEmpty {
        let comps = picref.components(separatedBy: CharacterSet(charactersIn: "?"))
        var storeName = ""
        var pathName = ""
        var queryName = ""
        switch type {
        case .btRef, .dlRef:
            output = URLComponents(string: "http://www.bait-tov.com/store")
            storeName = output.path
            pathName = "pic.php"
            queryName = "ID"
        case .jsRef, .dljsRef: // TBD: add .DLJSRef support with table lookup from ajtX.jpg file ref to 17XXX index
            output = URLComponents(string: "http://www.judaicasales.com/judaica")
            storeName = output.path
            pathName = "austrian_pic_detail.asp"
            queryName = "index"
        default:
            break
        }
        if comps.count > 1 {
            // fully specified BT/JS ref
            output.path = (storeName as NSString).appendingPathComponent(comps.first!) //storeName + "/" + comps.first!
            output.query = comps.last!
        } else {
            var refValue = type == .dlRef ? picref : ""
            if type == .dljsRef {
                // dealer item JS ref is in X=Y form; need to split it and use the 1st part
                let (dbRefID, fileRefID) = splitJSPictID(picref)
                if fileRefID != nil {
                    refValue = dbRefID
                } else {
                    // item refs not found in jsDictionary must return nil URLs
                    output = nil
                }
            }
            // only ID given (DL works, JS requires table lookup first), which could fail (table not initialized)
            if !refValue.isEmpty {
                output.path = (storeName as NSString).appendingPathComponent(pathName) //storeName + "/" + pathName
                let qitem = URLQueryItem(name: queryName, value: refValue)
                output.queryItems = [qitem]
            }
        }
    }
    if let output = output {
        let urlpath = output.string!
        return URL(string: urlpath)
    }
    return nil
}

let CATEG_CANCELLATIONS_FIRST = 4
let CATEG_CANCELLATIONS_LAST = 8

private func getFileNameFromPictid( _ pictid: String, _ cat: Int ) -> String {
    // takes an ID of the form "6110s5", returns the file name with ".jpg" or ".gif" added
    let ext = (cat >= CATEG_CANCELLATIONS_FIRST && cat <= CATEG_CANCELLATIONS_LAST) ? ".gif" : ".jpg"
    return pictid + ext
}

private func getFileNameFromJSPictid( _ pictid: String ) -> String {
    // takes an ID of the form "17020", returns the file name with "ajt" and ".jpg" added
    return "ajt" + pictid + ".jpg"
}

private func getPicURLFromBaseURL( _ type: PicRefURLType, picref: String, btBase: URL, btPath: String, jsBase: URL, jsPath: String, catnum: Int ) -> URL? {
    var output: URL! = nil
    guard !picref.isEmpty else { return output }
    guard picref != "N/A" else { return output }
    
    let comps = picref.components(separatedBy: CharacterSet(charactersIn: "="))
    let picref2 = comps.last! // this is just the ID part as a string
    switch type {
    case .btRef:
        output = btBase.appendingPathComponent(btPath + getFileNameFromPictid(picref2, catnum))
    case .jsRef:
        // translate "17020" forward to "1" etc.
        if let picref3 = jsDictionary[picref2] {
            output = jsBase.appendingPathComponent(jsPath + getFileNameFromJSPictid(picref3))
        }
    case .dlRef:
        output = btBase.appendingPathComponent(btPath + getFileNameFromPictid(picref, catnum))
    case .dljsRef:
        output = jsBase.appendingPathComponent(jsPath + getFileNameFromJSPictid(picref2))
    default:
        break
    }
    return output
}

// this function will turn the URL type reference into a remote URL for just the pic file (only works for the BT site)
func getPicFileRemoteURL( _ picref: String, refType type: PicRefURLType, category cat: Int = 0 ) -> URL? {
    // BT style: "http://www.bait-tov.com/store/products/" plus the file name (pictid/picref such as "6110s4" + ".jpg" file extension)
    // JS style: "http://www.judaicasales.com/pics/judaica_austriantabs/" plus the file name ("ajt" + picref + ".jpg", where "5" is the picref)
    let btURLBase = URL(string: "http://www.bait-tov.com")
    let jsURLBase = URL(string: "http://www.judaicasales.com")
    let btURLPath = "/store/products/"
    let jsURLPath = "/pics/judaica_austriantabs/"
    return getPicURLFromBaseURL(type, picref: picref, btBase: btURLBase!, btPath: btURLPath, jsBase: jsURLBase!, jsPath: jsURLPath, catnum: cat)
}

// this function will turn the URL type reference into a local file URL for the cached pic file (preferred for JS site, but can work with BT as files are downloaded)
func getPicFileLocalURL( _ picref: String, refType type: PicRefURLType, category catnum: Int16 ) -> URL? {
    // BT style: not currently supported (will return nil); should return a cached location for the downloaded file whose name is as above (pictid + ".jpg")
    // JS style: "ajt%s.jpg" where the %s is the picref as if from the JS DealerItem pictid ("5c" or "1") - returns nil if no pic available
    // actually requires a caching scheme from the base documents directory, or perhaps some data scraping from the pic page to cache the file (ouch)
    let ad = UIApplication.shared.delegate! as! AppDelegate
    let urlBase = ad.applicationDocumentsDirectory
    let urlPath = "pics/cat\(catnum)/"
    return getPicURLFromBaseURL(type, picref: picref, btBase: urlBase as URL, btPath: urlPath, jsBase: urlBase as URL, jsPath: urlPath, catnum: Int(catnum))
}

// this function will turn a local URL into a cache key to use with the persistent key/value store
func getPicFileCacheKeyFromLocalURL( _ URL: Foundation.URL? ) -> String? {
    if let comps = URL?.pathComponents {
        // we want the last path component, the normalized picref/pictid, if the URL was non-nil
        return comps.last!
    }
    return nil
}

// this function will create a cache key (normalized pictid) from basic pictid/picref and type
func getPicFileCacheKey( _ picref: String, type: PicRefURLType ) -> String? {
    var output: String? = nil
    if !picref.isEmpty && picref != "N/A" {
        let comps = picref.components(separatedBy: CharacterSet(charactersIn: "="))
        let picref2 = comps.last! // this is just the ID part as a string
        switch type {
        case .btRef:
            output = getFileNameFromPictid(picref2, 0)
        case .jsRef:
            // translate "17020" back to "1" etc.
            if let picref3 = jsRevDictionary[picref2] {
                output = getFileNameFromJSPictid(picref3)
            }
        case .dlRef:
            output = getFileNameFromPictid(picref, 0)
        case .dljsRef:
            output = getFileNameFromJSPictid(picref)
        default:
            break
        }
    }
    return output
}
