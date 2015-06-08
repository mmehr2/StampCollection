//
//  Basics.swift
//  GoldenPythag
//
//  Created by Michael L Mehr on 3/2/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import Foundation

/*
Solution for SourceKitService Terminated errors in XCode 6.1.1:
http://stackoverflow.com/questions/24006206/sourcekitservice-terminated
which says to run this command line to eliminate some cache data:
    rm -rf ~/Library/Developer/Xcode/DerivedData/ModuleCache
NOTE: This specific issue doesn't seem to plague XCode 6.3 (MANY OTHER PROBS THO!)

UPDATE: It turns out that when X6.3 gets really flakey, this also helps fix it.
There is one more powerful version of the above, that removes the entire directory contents:
    rm -rf ~/Library/Developer/Xcode/DerivedData/ * (NOTE: remove the space, it is to allow this to exist in a Swift comment!)
This causes all the caches to be removed, and should only be used when XCode is closed.
*/

/*
Git merge and diff using P4MERGE:
Check this article on how to install it and do a proper 4-pane 3-way merge:
http://naleid.com/blog/2013/10/29/how-to-use-p4merge-as-a-3-way-merge-tool-with-git-and-tower-dot-app
*/

// 75 great developer tools (and more in the comments) here: http://benscheirman.com/2013/08/the-ios-developers-toolbelt/

func trimSpaces( input: String ) -> String {
//    var begin = input.startIndex
//    var end = input.endIndex
//    while begin != input.endIndex {
//        let char = input[begin]
//        if char != " " {
//            break
//        }
//        begin = begin.successor()
//    }
//    while begin != end {
//        let char = input[end.predecessor()]
//        if char != " " && char != "\n" {
//            break
//        }
//        end = end.predecessor()
//    }
//    let range : Range<String.Index> = begin..<end
//    return input[range]
    // new version using Regex
    // step 1 - replace all whitespace runs with a single space
    let temp = input.replace("\\s+", withTemplate: " ")
    // step 2 - eliminate the possible leading space
    let temp2 = temp.replace("^\\s", withTemplate: "")
    // step 3 - eliminate the possible trailing space
    let temp3 = temp2.replace("\\s$", withTemplate: "")
    return temp3
}

// splits a string into a numeric suffix and non-numeric prefix
func splitNumericEndOfString( input: String ) -> (String, String) {
    var indexSplit = input.endIndex
    while indexSplit != input.startIndex {
        // adjust index backwards from end as long as numerics are found; stop at 1st Alpha or start of string
        let tempIndex = indexSplit.predecessor()
        if getCharacterClass(input[tempIndex]) == .Numeric {
            indexSplit = tempIndex
        } else {
            break
        }
    }
    let textString = input.substringToIndex(indexSplit)
    let numberString = input.substringFromIndex(indexSplit)
    return (textString, numberString)
}

func makeStringFit(input: String, length: Int) -> String {
    if count(input) > length-2 {
        return input[0..<length-2] + ".."
    }
    return input
}

func padIntegerString( input: Int, toLength outlen: Int, padWith pad: String = "0") -> String {
    var fmt = NSNumberFormatter()
    fmt.paddingCharacter = pad
    fmt.minimumIntegerDigits = outlen
    fmt.maximumIntegerDigits = outlen
    fmt.allowsFloats = false
    fmt.minimumFractionDigits = 0
    fmt.maximumFractionDigits = 0
    return fmt.stringFromNumber(input) ?? ""
}

func padDoubleString( input: Double, toLength outlen: Int, withFractionDigits places: Int = 2, padWith pad: String = "0") -> String {
    var fmtstr = String(format: "%d.%dlf", (pad.isEmpty ? 1 : outlen), places)
    fmtstr = "%" + pad + fmtstr
    let str = String(format:fmtstr, input)
    return str
//    var fmt = NSNumberFormatter()
//    fmt.paddingCharacter = pad
//    fmt.paddingPosition = .AfterPrefix
//    fmt.minimumIntegerDigits = outlen
//    fmt.maximumIntegerDigits = outlen
//    fmt.allowsFloats = true
//    fmt.minimumFractionDigits = places
//    fmt.maximumFractionDigits = places
//    return fmt.stringFromNumber(input) ?? ""
}

// code stolen from: http://stackoverflow.com/questions/26728477/swift-how-to-combine-two-dictionary-arrays
extension Dictionary {
    mutating func merge<K, V>(dict: [K: V]){
        for (k, v) in dict {
            self.updateValue(v as! Value, forKey: k as! Key)
        }
    }
}


// following was stolen from: http://stackoverflow.com/questions/24092884/get-nth-character-of-a-string-in-swift-programming-language
extension String {
    
    subscript (i: Int) -> Character {
        return self[advance(self.startIndex, i)]
    }
    
    subscript (i: Int) -> String {
        return String(self[i] as Character)
    }
    
    subscript (r: Range<Int>) -> String {
        return substringWithRange(Range(start: advance(startIndex, r.startIndex), end: advance(startIndex, r.endIndex)))
    }
}

// MARK: treat a string as a floating point number if possible
extension String {
    func toDouble() -> Double? {
        return NSNumberFormatter().numberFromString(self)?.doubleValue
    }
    func toFloat() -> Float? {
        return NSNumberFormatter().numberFromString(self)?.floatValue
    }
}

// Deal with Range (index functionality) vs. ClosedInterval (all else) by forcing ambiguity so user must choose
// Discussion here: http://airspeedvelocity.net/2014/11/16/which-function-does-swift-call-part-6-tinkering-with-priorities/
// Since I want to use ClosedInterval<Int> for Year range filtering, I'd like to have 1980...1989 be a ClosedInterval
// Normally, I'd get a Range<Int> instead because of the indexing capabilities of Int for Array subscripts.
// So this function makes the equivalent range ambiguous, so now I have to say Range or ClosedInterval specifically.
func ... <T: Comparable where T: ForwardIndexType>
    (start: T, end: T) -> ClosedInterval<T> {
        return ClosedInterval(start, end)
}

// MARK: string extensions for quick find a la predicate programming: BEGINSWITH, CONTAINS, ENDSWITH
// NOTE: requires NSRange extension for equality testing (Equatable protocol)
extension String {
    static var NotFound : NSRange {
        return NSRange( location: NSNotFound, length: 0 )
    }
    // NOTE: Plain methods use native or bridged functions
    // check if receiver contains the given string anywhere
    func contains( str: String ) -> Bool {
        let res = self.rangeOfString(str) // non-nil version is a Range<String.Index>
        return (res != nil)
    }
    // check if receiver starts with the given string
    func beginsWith( str: String ) -> Bool {
        return self.hasPrefix(str)
    }
    // check if receiver ends with the given string
    func endsWith( str: String ) -> Bool {
        return self.hasSuffix(str)
    }
    // CI methods (and maybe DI too?) need to use NSString APIs - didn't try finding bridged versions yet
    // check if receiver contains the given string anywhere (case insensitive)
    func containsCI( str: String ) -> Bool {
        let rcvr = self as NSString
        let res = rcvr.rangeOfString(str, options: NSStringCompareOptions.CaseInsensitiveSearch)
        return (res != String.NotFound)
    }
    // check if receiver starts with the given string
    func beginsWithCI( str: String ) -> Bool {
        let rcvr = self as NSString
        let res = rcvr.rangeOfString(str, options: NSStringCompareOptions.CaseInsensitiveSearch)
        return (res.location == 0)
    }
    func endsWithCI( str: String ) -> Bool {
        let rcvr = self as NSString
        let res = rcvr.rangeOfString(str, options: NSStringCompareOptions.BackwardsSearch | NSStringCompareOptions.CaseInsensitiveSearch)
        return (res.location == NSNotFound ? false : (res.location + res.length == count(self)))
    }
}

// MARK: NSRange Equatable extension for string comparisons
// WHY DOESN'T APPLE PROVIDE THIS???
extension NSRange: Equatable {
    
}

public func ==( lhs: NSRange, rhs: NSRange ) -> Bool {
    return lhs.length == rhs.length && lhs.location == rhs.location
}

public func !=( lhs: NSRange, rhs: NSRange ) -> Bool {
    return !(lhs == rhs)
}

// MARK: date extensions and helpers
// full set of comparison operators for NSDate pairs
public func <(d1: NSDate, d2: NSDate) -> Bool {
    let res = d1.compare(d2)
    return res == .OrderedAscending
}

public func ==(d1: NSDate, d2: NSDate) -> Bool {
    let res = d1.compare(d2)
    return res == .OrderedSame
}

extension NSDate: Equatable, Comparable { }
// NOTE: the protocols take care of defining the rest...
//func >(d1: NSDate, d2: NSDate) -> Bool {
//    let res = d1.compare(d2)
//    return res == .OrderedDescending
//}
//
//func !=(d1: NSDate, d2: NSDate) -> Bool {
//    return !(d1 == d2)
//}
//
//func >=(d1: NSDate, d2: NSDate) -> Bool {
//    return !(d1 < d2)
//}
//
//func <=(d1: NSDate, d2: NSDate) -> Bool {
//    return !(d1 > d2)
//}

// MARK: linear scaling function
func linearScale( input: Double, fromRange: ClosedInterval<Double>, toRange: ClosedInterval<Double> ) -> Double {
    let x0 = fromRange.start
    let x1 = fromRange.end
    let y0 = toRange.start
    let y1 = toRange.end
    let xNum = input - x0
    let xDenom = x1 - x0
    let yNum = y1 - y0
    var result = y0 + (xNum / xDenom) * yNum
    return result
}

// MARK: generic range comparisons
// Isn't this in Swift already? I can't tell yet!
func isValue<T: Comparable>( input: T, inClosedRange range: ClosedInterval<T>) -> Bool {
    if input < range.start {
        return false
    } else if input > range.end {
        return false
    }
    return true
}

func isValue<T: Comparable>( input: T, inOpenRange range: ClosedInterval<T>) -> Bool {
    if input < range.start {
        return false
    } else if input >= range.end {
        return false
    }
    return true
}

func isValue<T: Comparable>( input: T, inClosedRange range: Range<T>) -> Bool {
    if input < range.startIndex {
        return false
    } else if input > range.endIndex {
        return false
    }
    return true
}

func isValue<T: Comparable>( input: T, inOpenRange range: Range<T>) -> Bool {
    if input < range.startIndex {
        return false
    } else if input >= range.endIndex {
        return false
    }
    return true
}

// MARK: data paging support class
// (where does this belong?)
class PagingDataCounter {
    var count = 0 // MUST BE >= 0
    var valuesPerPage = 1 // MUST BE > 0
    var numberOfWholePages : Int {
        return count / valuesPerPage // integer division rounds down
    }
    var valuesOnPartialPage : Int {
        return count % valuesPerPage
    }
    var hasPartialPage : Bool {
        return valuesOnPartialPage != 0
    }
    var numberOfPages : Int {
        return numberOfWholePages + (hasPartialPage ? 1 : 0)
    }
    var indexOfPartialPage : Int {
        return numberOfWholePages * valuesPerPage
    }
    
    init() {
    }
    
    init(total: Int) {
        count = total
    }
    
    func getNumberOfValuesOnPage(page: Int) -> Int? {
        if let index = getFirstIndexForPageNumber(page) {
            switch index {
            case _ where index >= indexOfPartialPage: return valuesOnPartialPage
            default: return valuesPerPage
            }
        } else { return nil }
    }
    
    func getPageNumberForIndex(index: Int) -> Int? {
        if index >= count || index < 0 {
            return nil
        }
        return index / valuesPerPage
    }
    
    func getFirstIndexForPageNumber(page: Int) -> Int? {
        let index = page * valuesPerPage
        return index >= count ? nil : index
    }
}
