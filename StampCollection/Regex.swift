//
//  Regex.swift
//  StampCollection
//
//  Created by Michael L Mehr on 6/6/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import Foundation

// code lifted from: http://www.swift-studies.com/blog/2014/6/12/regex-matching-and-template-replacement-operators-in-swift
// Changed to support Swift 1.2 by Michael L. Mehr 6/6/2015:
//  1) infix must precede operator in op declarations
//  2) countElements() is replaced by count()
//  3) used if let syntax for regex optional testing/chaining
//  4) better use of private keyword
// Then I modified it to use static private implementation funcs for the guts (to make the Ruby operators optional), and wrote String extension versions a la Javascript
// WARNING 11/2015: USES MIXED VALUE AND REFERENCE SEMANTICS! TBD: Need to deal with copy-on-write-if-referenced semantics as in: http://www.raywenderlich.com/112029/reference-value-types-in-swift-part-2
// Also there have been other articles I've read recently 11/14/15 about using init(copy:C) that seem better, but is this a convention/best-practice or a 2.1 compiler change? find the ref ...

struct Regex {
    var pattern: String{
        didSet{
            updateRegex()
        }
    }
    var expressionOptions: NSRegularExpressionOptions{
        didSet{
            updateRegex()
        }
    }
    var matchingOptions: NSMatchingOptions
    
    var regex : NSRegularExpression?
    
    init(pattern: String, expressionOptions: NSRegularExpressionOptions, matchingOptions: NSMatchingOptions) {
        self.pattern = pattern
        self.expressionOptions = expressionOptions
        self.matchingOptions = matchingOptions
        updateRegex()
    }
    
    init(pattern:String) {
        self.pattern = pattern
        expressionOptions = NSRegularExpressionOptions(rawValue: 0)
        matchingOptions = NSMatchingOptions(rawValue: 0)
        updateRegex()
    }
    
    private mutating func updateRegex(){
        regex = try? NSRegularExpression(pattern: pattern, options: expressionOptions)
    }
    
    private static func testMatch(left: String, right: Regex) -> Bool {
        let range = NSMakeRange(0, left.characters.count)
        if let regex = right.regex {
            let matches = regex.matchesInString(left, options: right.matchingOptions, range: range) // as! [NSTextCheckingResult]
            return matches.count > 0
        }
        
        return false
    }
    
    private static func replacePattern(left:String, right: (regex:Regex, template:String) ) -> String{
        if Regex.testMatch(left, right: right.regex) {
            let range = NSMakeRange(0, left.characters.count)
            if let regex = right.regex.regex {
                return regex.stringByReplacingMatchesInString(left, options: right.regex.matchingOptions, range: range, withTemplate: right.template)
            }
        }
        return left
    }

}

//// MARK: match test operator (OPT - can be removed)
//infix operator =~ { associativity left precedence 140 }
//
//// match using an existing Regex: String =~ Regex
//func =~(left: String, right: Regex) -> Bool {
//    return Regex.testMatch(left, right: right)
//}
//
//// match using a Regex created from a String: String =~ String-regex-pattern
//func =~(left: String, right: String) -> Bool {
//    return left =~ Regex(pattern: right)
//}
//
//// MARK: replacement operator (OPT - can be removed)
//infix operator >< { associativity left precedence 140 }
//
//// replace using an existing Regex: String >< (Regex, String-template)
//func >< (left:String, right: (regex:Regex, template:String) ) -> String{
//    return Regex.replacePattern(left, right: right)
//}
//
//// replace using a Regex created from a String: String >< (String-pattern, String-template)
//func >< (left:String, right: (pattern:String, template:String) ) -> String{
//    return left >< (Regex(pattern: right.pattern), right.template)
//}

// MY OWN EXTENSIONS: I prefer the JavaScript syntax of
// string.test(pattern: String) -> Bool
// string.match(pattern: String) -> String?
// string.matchAll(pattern: String) -> [String] -- my version for /g global match
// string.replace(pattern: String, template: String) -- should only do one replacement max
// string.replaceAll(pattern: String, template: String) -- my version for /g global replace (as many replacements as found)
// THUS, I will adapt them via extensions to the String class
// Turns out, global search/replace is easy, single is difficult, and matching is not supported by the above
// so I will just use the simple test and replace definitions below
extension String {
    
    func test(pattern: String) -> Bool {
        return test(Regex(pattern: pattern))
    }
    
    func test(regex: Regex) -> Bool {
        return Regex.testMatch(self, right: regex) //self =~ regex
    }
    
    func replace( pattern: String, withTemplate template: String) -> String {
        return replace( Regex(pattern: pattern), withTemplate: template )
    }
    
    func replace( regex: Regex, withTemplate template: String) -> String {
        return Regex.replacePattern(self, right: (regex, template)) //self >< (regex, template)
    }
    
}

/*
USAGE:

let r1 = Regex(pattern: "[a-z]")
let r2 = Regex(pattern: "[0-9]", expressionOptions: NSRegularExpressionOptions(0), matchingOptions: NSMatchingOptions(0))

"a" =~ r1
"2" =~ r1
"a" =~ r2
"2" =~ r2
"2" =~ "[a-z]"
"2" =~ "[0-9]"

var iLoveLetters = "a" >< (r1,"$0!!!!")
var iHateNumbers = "d" >< (r2,"$0!!!!")

"Hello, Objective-C!!" >< ("Objective.C","Swift")
"Hello, Objective C!!" >< ("Objective.C","Swift")
"Hello, ObjectiveC!!!" >< ("Objective.*C","Swift")
*/

