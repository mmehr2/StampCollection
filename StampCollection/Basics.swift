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

I had to use this to help figure out how to push my local git onto the new repo I created on Github's servers:
https://help.github.com/articles/syncing-a-fork/
Basic steps:
Local:
1 cd <project dir>
2 cp ../prototype.gitignore .gitignore
// create local repo
3 git init
4 git add *.*
5 git commit -m "Initial commit."
6 <restart XCode and you should see the source code features; Commit changes if needed>
7 Remote: create the new repo on https://github.com/mmehr2 (include a README.md file)
Local:
8 git remote add upstream https://github.com/mmehr2/<RepoName>.git (create upstream ref, or use a different word, here and later)
9 git remove -v (verify you have two pointers for fetch and push)
// sync the fork, as they say:
10 git fetch upstream (fetch the README.md file and other changes)
11 git checkout master (prob.not needed if you didn't switch branches since checkin)
12 git merge -m "<comment>" upstream/master
NOTE: When I leave out the -m "" part, an editor pops up, but when I save and close it, nothing happens. Until I figure that out, use short comments with -m.
*/

// 75 great developer tools (and more in the comments) here: http://benscheirman.com/2013/08/the-ios-developers-toolbelt/

func trimSpaces( _ input: String ) -> String {
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
func splitNumericEndOfString( _ input: String ) -> (String, String) {
    var indexSplit = input.endIndex
    while indexSplit != input.startIndex {
        // adjust index backwards from end as long as numerics are found; stop at 1st Alpha or start of string
        let tempIndex = input.index(before: indexSplit)
        if getCharacterClass(input[tempIndex]) == .numeric {
            indexSplit = tempIndex
        } else {
            break
        }
    }
    let textString = input.substring(to: indexSplit)
    let numberString = input.substring(from: indexSplit)
    return (textString, numberString)
}

func makeStringFit(_ input: String, length: Int) -> String {
    if input.characters.count > length-2 {
        return String(input.characters.prefix(length - 2)) + ".."
    }
    return input
}

func padIntegerString( _ input: Int, toLength outlen: Int, padWith pad: String = "0") -> String {
    let fmt = NumberFormatter()
    fmt.paddingCharacter = pad
    fmt.minimumIntegerDigits = outlen
    fmt.maximumIntegerDigits = outlen
    fmt.allowsFloats = false
    fmt.minimumFractionDigits = 0
    fmt.maximumFractionDigits = 0
    return fmt.string(from: NSNumber(value: input)) ?? ""
}

func padDoubleString( _ input: Double, toLength outlen: Int, withFractionDigits places: Int = 2, padWith pad: String = "0") -> String {
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
    mutating func merge<K, V>(_ dict: [K: V]){
        for (k, v) in dict {
            self.updateValue(v as! Value, forKey: k as! Key)
        }
    }
}


// following was stolen from: http://stackoverflow.com/questions/24092884/get-nth-character-of-a-string-in-swift-programming-language
// THIS IS CONSIDERED DANGEROUS IN SWIFT 3.x (AND PROBABLY ALL ALONG) - see here: https://stackoverflow.com/questions/39677330/how-does-string-substring-work-in-swift-3
//   which refers to this article to prevent the following usage - https://oleb.net/blog/2016/08/swift-3-strings/
//extension String {

//subscript (i: Int) -> Character {
//    return self[self.characters.index(self.startIndex, offsetBy: i)]
//}

//subscript (i: Int) -> String {
//    return String(self[i] as Character)
//}

//subscript (r: Range<Int>) -> String {
//    return substring(with: (characters.index(startIndex, offsetBy: r.lowerBound) ..< characters.index(startIndex, offsetBy: r.upperBound)))
//}
//}

// MARK: treat a string as a floating point number if possible
extension String {
    func toDouble() -> Double? {
        return NumberFormatter().number(from: self)?.doubleValue
    }
    func toFloat() -> Float? {
        return NumberFormatter().number(from: self)?.floatValue
    }
}

// MARK: string extensions for quick find a la predicate programming: BEGINSWITH, CONTAINS, ENDSWITH
// NOTE: requires NSRange extension for equality testing (Equatable protocol)
extension String {
    static var NotFound : NSRange {
        return NSRange( location: NSNotFound, length: 0 )
    }
    // NOTE: Plain methods use native or bridged functions
    // check if receiver contains the given string anywhere
    func contains( _ str: String ) -> Bool {
        let res = self.range(of: str) // non-nil version is a Range<String.Index>
        return (res != nil)
    }
    // check if receiver starts with the given string
    func beginsWith( _ str: String ) -> Bool {
        return self.hasPrefix(str)
    }
    // check if receiver ends with the given string
    func endsWith( _ str: String ) -> Bool {
        return self.hasSuffix(str)
    }
    // CI methods (and maybe DI too?) need to use NSString APIs - didn't try finding bridged versions yet
    // check if receiver contains the given string anywhere (case insensitive)
    func containsCI( _ str: String ) -> Bool {
        let rcvr = self as NSString
        let res = rcvr.range(of: str, options: NSString.CompareOptions.caseInsensitive)
        return (res != String.NotFound)
    }
    // check if receiver starts with the given string
    func beginsWithCI( _ str: String ) -> Bool {
        let rcvr = self as NSString
        let res = rcvr.range(of: str, options: NSString.CompareOptions.caseInsensitive)
        return (res.location == 0)
    }
    func endsWithCI( _ str: String ) -> Bool {
        let rcvr = self as NSString
        let res = rcvr.range(of: str, options: [NSString.CompareOptions.backwards, NSString.CompareOptions.caseInsensitive])
        return (res.location == NSNotFound ? false : (res.location + res.length == self.characters.count))
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
public func <(d1: Date, d2: Date) -> Bool {
    let res = d1.compare(d2)
    return res == .orderedAscending
}

//public func ==(d1: NSDate, d2: NSDate) -> Bool {
//    let res = d1.compare(d2)
//    return res == .OrderedSame
//}
//
//extension NSDate: Equatable { }
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
func linearScale( _ input: Double, fromRange: ClosedRange<Double>, toRange: ClosedRange<Double> ) -> Double {
    let x0 = fromRange.lowerBound
    let x1 = fromRange.upperBound
    let y0 = toRange.lowerBound
    let y1 = toRange.upperBound
    let xNum = input - x0
    let xDenom = x1 - x0
    let yNum = y1 - y0
    let result = y0 + (xNum / xDenom) * yNum
    return result
}

// MARK: generic range comparisons
// Isn't this in Swift already? I can't tell yet!
func isValue<T: Comparable>( _ input: T, inClosedRange range: ClosedRange<T>) -> Bool {
    if input < range.lowerBound {
        return false
    } else if input > range.upperBound {
        return false
    }
    return true
}

func isValue<T: Comparable>( _ input: T, inOpenRange range: ClosedRange<T>) -> Bool {
    if input < range.lowerBound {
        return false
    } else if input >= range.upperBound {
        return false
    }
    return true
}

func isValue<T: Comparable>( _ input: T, inClosedRange range: Range<T>) -> Bool {
    if input < range.lowerBound {
        return false
    } else if input > range.upperBound {
        return false
    }
    return true
}

func isValue<T: Comparable>( _ input: T, inOpenRange range: Range<T>) -> Bool {
    if input < range.lowerBound {
        return false
    } else if input >= range.upperBound {
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
    
    func getNumberOfValuesOnPage(_ page: Int) -> Int? {
        if let index = getFirstIndexForPageNumber(page) {
            switch index {
            case _ where index >= indexOfPartialPage: return valuesOnPartialPage
            default: return valuesPerPage
            }
        } else { return nil }
    }
    
    func getPageNumberForIndex(_ index: Int) -> Int? {
        if index >= count || index < 0 {
            return nil
        }
        return index / valuesPerPage
    }
    
    func getFirstIndexForPageNumber(_ page: Int) -> Int? {
        let index = page * valuesPerPage
        return index >= count ? nil : index
    }
}
