//
//  ItemPicURL.swift
//  StampCollection
//
//  Created by Michael L Mehr on 7/7/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import Foundation

// MARK: URL construction for pic pages and references (TBD: belongs in Network Model)
enum PicRefURLType {
    case BTRef // format: "pic.php?ID=6110s4"
    case JSRef // format: "austrian_pic_detail.asp?index=17020" (for id="AUI001")
    case DLRef // format: "6110s4"
    case DLJSRef // format: "N/A" for none, or "1a" for "ajt1a.jpg" local filename - no way back to picref 17XXX without table
    case Unknown
}

// this table will be indexed by DealerItem pictid ("5c" or "2") and get you a page ref ID ("17020" or "17054")
private var jsDictionary: [String: String] = [:]
// this table will be indexed by page ref ID ("17020" or "17054") and get you a DealerItem pictid ("5c" or "2")
private var jsRevDictionary: [String: String] = [:]

private func setJSDictionaryEntry( pictid: String, picref: String ) {
    if !picref.isEmpty && pictid != "N/A" {
        let comps = picref.componentsSeparatedByCharactersInSet(NSCharacterSet(charactersInString: "="))
        let picref = comps.last!
        jsDictionary[pictid] = picref
        jsRevDictionary[picref] = pictid
    }
}

// this function should be called first before using getPicRefURL() with refs of type .DLJSRef (the CoreData JS info items)
func populateJSDictionary( jsDealerCat: Category, jsWebCat: BTCategory ) {
    if let items = Array(jsDealerCat.dealerItems) as? [DealerItem] {
        // set up cache of IDs to locate BTDealerItems by ID
        var jsToBTIDCache: [String: String] = [:]
        for btitem in jsWebCat.dataItems {
            jsToBTIDCache[btitem.code] = btitem.picref
        }
        // set up pictid-to-picref mapping array for later use
        for item in items {
            let idcode = item.id // matching ID to look up in BT cache
            if let btpicref = jsToBTIDCache[idcode] {
                setJSDictionaryEntry(item.pictid, btpicref)
            }
        }
    }
}

// this utility function should be called by item classes and not directly
// it will turn a pic reference string in one of the four types into a full NSURL for the page that shows that pic (along with other formatted info from the dealer website)
func getPicRefURL( picref: String, refType type: PicRefURLType ) -> NSURL? {
    // BT style: "http://www.bait-tov.com/store/" plus the formatted link from BTRef
    // JS style: "http://www.judaicasales.com/judaica/" plus the formatted link from JSRef
    var output: NSURLComponents! = nil
    if !picref.isEmpty {
        let comps = picref.componentsSeparatedByCharactersInSet(NSCharacterSet(charactersInString: "?"))
        var storeName = ""
        var pathName = ""
        var queryName = ""
        switch type {
        case .BTRef, .DLRef:
            output = NSURLComponents(string: "http://www.bait-tov.com/store")
            storeName = output.path!
            pathName = "pic.php"
            queryName = "ID"
        case .JSRef, .DLJSRef: // TBD: add .DLJSRef support with table lookup from ajtX.jpg file ref to 17XXX index
            output = NSURLComponents(string: "http://www.judaicasales.com/judaica")
            storeName = output.path!
            pathName = "austrian_pic_detail.asp"
            queryName = "index"
        default:
            break
        }
        if comps.count > 1 {
            // fully specified BT/JS ref
            output.path = storeName.stringByAppendingPathComponent(comps.first!) //storeName + "/" + comps.first!
            output.query = comps.last!
        } else {
            var refValue = type == .DLRef ? picref : ""
            if type == .DLJSRef {
                if let picValue = jsDictionary[picref] {
                    refValue = picValue
                } else {
                    // item refs not found in jsDictionary must return nil URLs
                    output = nil
                }
            }
            // only ID given (DL works, JS requires table lookup first), which could fail (table not initialized)
            if !refValue.isEmpty {
                output.path = storeName.stringByAppendingPathComponent(pathName) //storeName + "/" + pathName
                let qitem = NSURLQueryItem(name: queryName, value: refValue)
                output.queryItems = [qitem]
            }
        }
    }
    if let output = output {
        let urlpath = output.string!
        return NSURL(string: urlpath)
    }
    return nil
}

private func getFileNameFromPictid( pictid: String ) -> String {
    // takes an ID of the form "6110s5", returns the file name with ".jpg" added
    return pictid + ".jpg"
}

private func getFileNameFromJSPictid( pictid: String ) -> String {
    // takes an ID of the form "6110s5", returns the file name with ".jpg" added
    return "ajt" + pictid + ".jpg"
}

private func getPicURLFromBaseURL( type: PicRefURLType, picref: String, btBase: NSURL, btPath: String, jsBase: NSURL, jsPath: String ) -> NSURL? {
    var output: NSURL! = nil
    if !picref.isEmpty && picref != "N/A" {
        let comps = picref.componentsSeparatedByCharactersInSet(NSCharacterSet(charactersInString: "="))
        let picref2 = comps.last! // this is just the ID part as a string
        switch type {
        case .BTRef:
            output = btBase.URLByAppendingPathComponent(btPath + getFileNameFromPictid(picref2))
        case .JSRef:
            // translate "17020" back to "1" etc.
            if let picref3 = jsRevDictionary[picref2] {
                output = jsBase.URLByAppendingPathComponent(jsPath + getFileNameFromJSPictid(picref3))
            }
        case .DLRef:
            output = btBase.URLByAppendingPathComponent(btPath + getFileNameFromPictid(picref))
        case .DLJSRef:
            output = jsBase.URLByAppendingPathComponent(jsPath + getFileNameFromJSPictid(picref))
        default:
            break
        }
    }
    return output
}

// this function will turn the URL type reference into a remote URL for just the pic file (only works for the BT site)
func getPicFileRemoteURL( picref: String, refType type: PicRefURLType ) -> NSURL? {
    // BT style: "http://www.bait-tov.com/store/products/" plus the file name (pictid/picref such as "6110s4" + ".jpg" file extension)
    // JS style: "http://www.judaicasales.com/pics/judaica_austriantabs/" plus the file name ("ajt" + picref + ".jpg", where "5" is the picref)
    let btURLBase = NSURL(string: "http://www.bait-tov.com")
    let jsURLBase = NSURL(string: "http://www.judaicasales.com")
    let btURLPath = "/store/products/"
    let jsURLPath = "/pics/judaica_austriantabs/"
    return getPicURLFromBaseURL(type, picref, btURLBase!, btURLPath, jsURLBase!, jsURLPath)
}

// this function will turn the URL type reference into a local file URL for the cached pic file (preferred for JS site, but can work with BT as files are downloaded)
func getPicFileLocalURL( picref: String, refType type: PicRefURLType, category catnum: Int16 ) -> NSURL? {
    // BT style: not currently supported (will return nil); should return a cached location for the downloaded file whose name is as above (pictid + ".jpg")
    // JS style: "ajt%s.jpg" where the %s is the picref as if from the JS DealerItem pictid ("5c" or "1") - returns nil if no pic available
    // actually requires a caching scheme from the base documents directory, or perhaps some data scraping from the pic page to cache the file (ouch)
    let urlBase = CollectionStore.sharedInstance.applicationDocumentsDirectory
    let urlPath = "pics/cat\(catnum)/"
    return getPicURLFromBaseURL(type, picref, urlBase, urlPath, urlBase, urlPath)
}

// this function will turn a local URL into a cache key to use with the persistent key/value store
func getPicFileCacheKeyFromLocalURL( URL: NSURL? ) -> String? {
    if let url = URL, var comps = url.pathComponents as? [String] {
        // we want the last path component, the normalized picref/pictid, if the URL was non-nil
        return comps.last!
    }
    return nil
}

// this function will create a cache key (normalized pictid) from basic pictid/picref and type
func getPicFileCacheKey( picref: String, type: PicRefURLType ) -> String? {
    var output: String? = nil
    if !picref.isEmpty && picref != "N/A" {
        let comps = picref.componentsSeparatedByCharactersInSet(NSCharacterSet(charactersInString: "="))
        let picref2 = comps.last! // this is just the ID part as a string
        switch type {
        case .BTRef:
            output = getFileNameFromPictid(picref2)
        case .JSRef:
            // translate "17020" back to "1" etc.
            if let picref3 = jsRevDictionary[picref2] {
                output = getFileNameFromJSPictid(picref3)
            }
        case .DLRef:
            output = getFileNameFromPictid(picref)
        case .DLJSRef:
            output = getFileNameFromJSPictid(picref)
        default:
            break
        }
    }
    return output
}
