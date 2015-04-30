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
*/

// MARK: random numbers
// get random integer in between two numbers (+ve or -ve fine, from < to)
func getRandomFrom(from: Int, #to: Int) -> Int {
    let arg : UInt32 = UInt32(to - from)
    return Int(arc4random_uniform(arg)) + from
}

func getRandomBool() -> Bool {
    let numZeroOrOne = getRandomFrom(0, to: 2)
    return numZeroOrOne == 1
}

// MARK: date extensions and helpers
// full set of comparison operators for NSDate pairs
func <(d1: NSDate, d2: NSDate) -> Bool {
    let res = d1.compare(d2)
    return res == .OrderedAscending
}

func ==(d1: NSDate, d2: NSDate) -> Bool {
    let res = d1.compare(d2)
    return res == .OrderedSame
}

func >(d1: NSDate, d2: NSDate) -> Bool {
    let res = d1.compare(d2)
    return res == .OrderedDescending
}

func !=(d1: NSDate, d2: NSDate) -> Bool {
    return !(d1 == d2)
}

func >=(d1: NSDate, d2: NSDate) -> Bool {
    return !(d1 < d2)
}

func <=(d1: NSDate, d2: NSDate) -> Bool {
    return !(d1 > d2)
}

// func for getting a random date
func getRandomDateFrom(from: Int, #to: Int) -> NSDate {
    var date = NSDate()
    let numToAdd = getRandomFrom(from, to: to)
    date = date.addDays(numToAdd)
    return date
}

// predefined parameter random date function for simulated data
func getRandomDate() -> NSDate {
    // generate a randome date over the last year, but not too close to now
    let from = -365
    let to = -5
    return getRandomDateFrom(from, to: to)
}

// date extension to easily deal with adding days to dates

private let secsPerDay = 24 * 60 * 60

extension NSDate {
    func addDays(days : Int) -> NSDate {
        let time = NSTimeInterval(days * secsPerDay)
        return self.dateByAddingTimeInterval(time)
    }
}

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

// MARK: latitude and longitude functions
private let sexagesimalScaleFactor = 60.0
func sexagesimalSplit(input: Double) -> (Int, Int, Double) {
    var result : (D: Int, M: Int, S: Double) = (0,0,0.0)
    result.D = Int(input)
    let rem = input - Double(result.D)
    let r2 = rem * sexagesimalScaleFactor
    result.M = Int(r2)
    let rem2 = r2 - Double(result.M)
    result.S = rem2 * sexagesimalScaleFactor
    return result
}

func sexagesimalCombine(input: (Int, Int, Double)) -> Double {
    let (D, M, S) = input
    return Double(D) + (Double(M) / sexagesimalScaleFactor) + (S / (sexagesimalScaleFactor * sexagesimalScaleFactor))
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
