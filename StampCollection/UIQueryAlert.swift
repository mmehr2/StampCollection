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
    case text, numeric
}

enum UIQueryFieldDesignator {
    case keywordList, yearRangeStart, yearRangeEnd, idPattern
}

struct UIQueryFieldConfiguration {
    var designator: UIQueryFieldDesignator = .keywordList
    var type: UIQueryFieldType = .text
    var placeholder: String = ""
    
    // this object's job is to set up configuration instructions for the various text fields
    init( type des: UIQueryFieldDesignator) {
        designator = des
        switch des {
        case .keywordList:
            // set up the single text field config
            placeholder = "Space-separated key words"
            type = .text
            break
        case .yearRangeStart:
            // set up the two numeric field configs
            placeholder = "Start year as YYYY"
            type = .numeric
            break
        case .yearRangeEnd:
            // set up the two numeric field configs
            placeholder = "End year as YYYY"
            type = .numeric
            break
        case .idPattern:
            // set up the single text field config
            placeholder = "ID search pattern"
            type = .text
            break
        }
    }
}

enum UIQueryAlertType {
    case keyword, yearRange, subCategory
}

struct UIQueryAlertConfiguration {
    var type: UIQueryAlertType = .keyword
    fileprivate var title: String = ""
    fileprivate var body: String = ""
    fileprivate var fieldConfigs: [UIQueryFieldConfiguration] = []

    // this object's job is to set up configuration instructions for the various text fields
    init( type: UIQueryAlertType) {
        self.type = type
        switch type {
        case .keyword:
            // set up the single text field config
            title = "Edit Keyword List"
            body =
            "Enter key words for searching, separated by spaces.\n" +
                "The search will check all description fields.\n" +
            "By default, any keyword will match. To force all keywords to match," +
            " use the word ALL as the first keyword.\n" +
            "To remove all keyword filtering, enter an empty field."
            fieldConfigs.append(UIQueryFieldConfiguration(type: .keywordList))
            break
        case .yearRange:
            // set up the two numeric field configs
            title = "Edit Year Range Filter"
            body = "Specify the years to include. End must be greater than or equal to Start.\n" +
                "Valid years for Israeli stamps are 1948 to present." +
            "\nTo specify a single year, enter valid Start and blank End." +
            "\nTo remove all year filtering, enter blank in both Start and End."
            fieldConfigs.append(UIQueryFieldConfiguration(type: .yearRangeStart))
            fieldConfigs.append(UIQueryFieldConfiguration(type: .yearRangeEnd))
            break
        case .subCategory:
            // set up the single text field config
            title = "SubCategory Filter"
            body = "Enter Search pattern for record IDs.\n" +
            "The search will check just the ID field.\n" +
            "To remove all subcategory filtering, enter an empty field."
            fieldConfigs.append(UIQueryFieldConfiguration(type: .idPattern))
            break
        }
    }
    
    func getConfigurationCount() -> Int {
        return fieldConfigs.count
    }
    
    func getConfiguration(_ index: Int) -> UIQueryFieldConfiguration {
        return fieldConfigs[index]
    }
}

class UIQueryAlert: NSObject, UITextFieldDelegate {
    
    var config: UIQueryAlertConfiguration
    var fields: [UITextField] = []
    var userCompletionHandler: ((SearchType) -> Void)?

    init(type: UIQueryAlertType, completion: @escaping (SearchType) -> Void) {
        config = UIQueryAlertConfiguration(type: type)
        userCompletionHandler = completion
        // lots here eventually
        super.init()
    }

    func RunWithViewController(_ vc: UIViewController) {
        fields = []
        let ac = UIAlertController(title: config.title, message: config.body, preferredStyle: .alert)
        let act = UIAlertAction(title: "OK", style: .default) { x in
            // run the user's completion handler in response to OK being pressed
            if let handler = self.userCompletionHandler {
                let result : SearchType
                if self.config.type == .keyword {
                    let text : String = self.fields[0].text ?? ""
                    var words = text.isEmpty ? [] : text.components(separatedBy: " ") // split this at spaces
                    if words.count > 0 && words[0] == "ALL" {
                        words.remove(at: 0)
                        result = SearchType.keyWordListAll(words)
                    } else {
                        result = SearchType.keyWordListAny(words)
                    }
                    handler(result)
                }
                else if self.config.type == .subCategory {
                    let text : String = self.fields[0].text ?? ""
                    result = SearchType.subCategory(text)
                    handler(result)
                }
                else if self.config.type == .yearRange {
                    let text1 : String = self.fields[0].text ?? ""
                    let text2 : String = self.fields[1].text ?? ""
                    var startYear = Int(text1) ?? 0
                    var endYear = Int(text2) ?? 0
                    // convention: if you only type in the start, the end is set equal to it
                    if startYear != 0 && endYear == 0 {
                        endYear = startYear
                    }
                    let (currentYear, _, _) = componentsFromDate(Date())
                    if startYear < 1948 || startYear > currentYear || endYear < startYear {
                        // validity check: any invalid causes removal of searching type in question by sending back special data
                        startYear = 0
                        endYear = 0
                    }
                    result = SearchType.yearInRange(startYear...endYear)
                    handler(result)
                }
            }
        }
        ac.addAction(act)
        // add the text fields required by the configuration
        for index in 0..<config.getConfigurationCount() {
            let fldconfig = config.getConfiguration(index)
            ac.addTextField() { (textField) in
                textField.delegate = self
                textField.placeholder = fldconfig.placeholder
                if fldconfig.type == .numeric {
                    textField.keyboardType = .numbersAndPunctuation //.NumberPad
                } else if fldconfig.type == .text {
                    textField.keyboardType = .default //.ASCIICapable
                }
                textField.returnKeyType = .done
                self.fields.append(textField)
            }
        }
        vc.present(ac, animated: true) {
        }
    }
    
//    // this method allows keyboard removal by touching any background in the view
//    override func touchesBegan(touches: Set<NSObject>, withEvent event: UIEvent) {
//        view.endEditing(true)
//        setEditing(false, animated: true)
//        super.touchesBegan(touches, withEvent: event)
//    }
    
    // MARK: - UITextFieldDelegate
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        return true
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        textField.becomeFirstResponder()
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        //updateModel() // name field updated and keyboard dismissed
    }

}
