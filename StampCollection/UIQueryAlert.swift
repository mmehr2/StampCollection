//
//  UIQueryAlert.swift
//  StampCollection
//
//  Created by Michael L Mehr on 5/3/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import UIKit

/*
This class will display a UIAlertController modally.
The controller will have a few text input fields for editing various things, such as keywords or year ranges.
For now we will customize it to edit SearchType objects' auxiliary data.
// TBD: needs to remember previous entry for each field - how?
*/

enum UIQueryFieldType {
    case Text, Numeric
}

enum UIQueryFieldDesignator {
    case KeywordList, YearRangeStart, YearRangeEnd, IDPattern
}

struct UIQueryFieldConfiguration {
    var designator: UIQueryFieldDesignator = .KeywordList
    var type: UIQueryFieldType = .Text
    var placeholder: String = ""
    
    // this object's job is to set up configuration instructions for the various text fields
    init( type des: UIQueryFieldDesignator) {
        designator = des
        switch des {
        case .KeywordList:
            // set up the single text field config
            placeholder = "Space-separated key words"
            type = .Text
            break
        case .YearRangeStart:
            // set up the two numeric field configs
            placeholder = "Start year as YYYY"
            type = .Numeric
            break
        case .YearRangeEnd:
            // set up the two numeric field configs
            placeholder = "End year as YYYY"
            type = .Numeric
            break
        case .IDPattern:
            // set up the single text field config
            placeholder = "ID search pattern"
            type = .Text
            break
        }
    }
}

enum UIQueryAlertType {
    case Keyword, YearRange, SubCategory
}

struct UIQueryAlertConfiguration {
    var type: UIQueryAlertType = .Keyword
    private var title: String = ""
    private var body: String = ""
    private var fieldConfigs: [UIQueryFieldConfiguration] = []

    // this object's job is to set up configuration instructions for the various text fields
    init( type: UIQueryAlertType) {
        self.type = type
        switch type {
        case .Keyword:
            // set up the single text field config
            title = "Edit Keyword List"
            body = "Enter key words for searching, separated by spaces.\n"
                "The search will check all description fields.\n"
            "By default, any keyword will match. To force all keywords to match,"
            " use the word ALL as the first keyword.\n"
            "To remove all keyword filtering, enter an empty field."
            fieldConfigs.append(UIQueryFieldConfiguration(type: .KeywordList))
            break
        case .YearRange:
            // set up the two numeric field configs
            title = "Edit Year Range Filter"
            body = "Specify the years to include. End must be greater than or equal to Start.\n"
                "Valid years for Israeli stamps are 1948 to present."
            "\nTo specify a single year, enter valid Start and blank End."
            "\nTo remove all year filtering, enter blank in both Start and End."
            fieldConfigs.append(UIQueryFieldConfiguration(type: .YearRangeStart))
            fieldConfigs.append(UIQueryFieldConfiguration(type: .YearRangeEnd))
            break
        case .SubCategory:
            // set up the single text field config
            title = "SubCategory Filter"
            body = "Enter Search pattern for record IDs.\n"
            "The search will check just the ID field.\n"
            "To remove all subcategory filtering, enter an empty field."
            fieldConfigs.append(UIQueryFieldConfiguration(type: .IDPattern))
            break
        }
    }
    
    func getConfigurationCount() -> Int {
        return fieldConfigs.count
    }
    
    func getConfiguration(index: Int) -> UIQueryFieldConfiguration {
        return fieldConfigs[index]
    }
}

class UIQueryAlert: NSObject, UITextFieldDelegate {
    
    var config: UIQueryAlertConfiguration
    var fields: [UITextField] = []
    var userCompletionHandler: ((SearchType) -> Void)?

    init(type: UIQueryAlertType, completion: (SearchType) -> Void) {
        config = UIQueryAlertConfiguration(type: type)
        userCompletionHandler = completion
        // lots here eventually
        super.init()
    }

    func RunWithViewController(vc: UIViewController) {
        fields = []
        let ac = UIAlertController(title: config.title, message: config.body, preferredStyle: .Alert)
        let act = UIAlertAction(title: "OK", style: .Default) { x in
            // run the user's completion handler in response to OK being pressed
            if let handler = self.userCompletionHandler {
                let result : SearchType
                if self.config.type == .Keyword {
                    let text : String = self.fields[0].text ?? ""
                    var words = text.isEmpty ? [] : text.componentsSeparatedByString(" ") // split this at spaces
                    if words.count > 0 && words[0] == "ALL" {
                        words.removeAtIndex(0)
                        result = SearchType.KeyWordListAll(words)
                    } else {
                        result = SearchType.KeyWordListAny(words)
                    }
                    handler(result)
                }
                else if self.config.type == .SubCategory {
                    let text : String = self.fields[0].text ?? ""
                    result = SearchType.SubCategory(text)
                    handler(result)
                }
                else if self.config.type == .YearRange {
                    let text1 : String = self.fields[0].text ?? ""
                    let text2 : String = self.fields[1].text ?? ""
                    var startYear = Int(text1) ?? 0
                    var endYear = Int(text2) ?? 0
                    // convention: if you only type in the start, the end is set equal to it
                    if startYear != 0 && endYear == 0 {
                        endYear = startYear
                    }
                    let (currentYear, _, _) = componentsFromDate(NSDate())
                    if startYear < 1948 || startYear > currentYear || endYear < startYear {
                        // validity check: any invalid causes removal of searching type in question by sending back special data
                        startYear = 0
                        endYear = 0
                    }
                    result = SearchType.YearInRange(startYear...endYear)
                    handler(result)
                }
            }
        }
        ac.addAction(act)
        // add the text fields required by the configuration
        for index in 0..<config.getConfigurationCount() {
            let fldconfig = config.getConfiguration(index)
            ac.addTextFieldWithConfigurationHandler() { (textField) in
                textField.delegate = self
                textField.placeholder = fldconfig.placeholder
                if fldconfig.type == .Numeric {
                    textField.keyboardType = .NumbersAndPunctuation //.NumberPad
                } else if fldconfig.type == .Text {
                    textField.keyboardType = .Default //.ASCIICapable
                }
                textField.returnKeyType = .Done
                self.fields.append(textField)
            }
        }
        vc.presentViewController(ac, animated: true) {
        }
    }
    
//    // this method allows keyboard removal by touching any background in the view
//    override func touchesBegan(touches: Set<NSObject>, withEvent event: UIEvent) {
//        view.endEditing(true)
//        setEditing(false, animated: true)
//        super.touchesBegan(touches, withEvent: event)
//    }
    
    // MARK: - UITextFieldDelegate
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldShouldBeginEditing(textField: UITextField) -> Bool {
        return true
    }
    
    func textFieldDidBeginEditing(textField: UITextField) {
        textField.becomeFirstResponder()
    }
    
    func textFieldDidEndEditing(textField: UITextField) {
        //updateModel() // name field updated and keyboard dismissed
    }

}
