//
//  Filtering.swift
//  StampCollection
//
//  Created by Michael L Mehr on 4/30/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import Foundation

// NSArrays have better support for CocoaTouch APIs such as KVO filtering/sorting
// This function is required to avoid a HUGE bug in XCODE 6.3/Swift 1.2 having to do with casting NSArray to [T]
// If I tried any form of "NSArray as? [myobject]", the resulting array would have a corrupted count etc.
// Only looping through and casting the individual elements seems to work, so that's what we do here.
func fromNSArray<T: NSObject>( _ input: NSArray ) -> [T] {
    var output : [T] = []
    for i in 0 ..< input.count += 1 {
        let t: AnyObject = input.object(at: i) as AnyObject
        if let temp4 = t as? T {
            output.append(temp4)
        }
    }
    return output
}

// The simple array sorting protocol I use embeds the ascend/descend flag in the key name string.
// Basically, the key name is preceded by a "-" if descending order is desired for that prop's sort descriptor

func sortKVONSArray( _ input: NSArray, keyNames: [String] ) -> NSArray {
    let temp : NSArray = input
    var sortDes : [NSSortDescriptor] = []
    for keyName in keyNames {
        var asc = true
        var kname = keyName
        let klen = kname.characters.count
        if (kname[0] == "-") {
            asc = false
            kname = kname[1..<klen]
        }
        sortDes.append(NSSortDescriptor(key: kname, ascending: asc))
    }
    let output : NSArray = temp.sortedArray(using: sortDes)
    return output
}

func sortKVOArray<T: NSObject>( _ input: [T], keyNames: [String] ) -> [T] {
    let temp : NSArray = input as NSArray
    let temp2 : NSArray = sortKVONSArray(temp, keyNames: keyNames)
    let output : [T] = fromNSArray(temp2)
    return output
}

/*
Filtering can be much more complicated. We want a rich programmatic way to filter items by many criteria.
I will start by using an array of tuples or dictionaries (TBD: Are the names important? Mostly for defaults..)

Most of the Managed Objects' fields are String type, but have very different contents.
The price fields of DealerItem, when number-convertible, should be treated as floats or doubles.
The code id/baseItem/refItem fields need to be treated as composites, with four fields.
The description in certain categories (Joint, Full Sheets) has extra information too.
*/

func filterKVONSArray( _ input: NSArray, keyName: String, keyValue: String, convertValueToInt: Bool ) -> NSArray {
    let temp : NSArray = input
    var kval : NSObject = keyValue as NSString
    if let ival = Int(keyValue) , convertValueToInt {
        kval = NSNumber(value: ival as Int)
    }
    let predicate = NSPredicate(format: "%K = %@", keyName, kval)
    let output : NSArray = temp.filtered(using: predicate) as NSArray
    return output
}

func filterKVOArray<T: NSObject>( _ input: [T], keyName: String, keyValue: String, convertValueToInt: Bool ) -> [T] {
    let temp : NSArray = input as NSArray
    let temp2 : NSArray = filterKVONSArray(temp, keyName: keyName, keyValue: keyValue, convertValueToInt: convertValueToInt)
    let output : [T] = fromNSArray(temp2)
    return output
}
