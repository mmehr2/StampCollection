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
 
 UPDATE: added text fields for inventory Section Name and Album Family Name, and query types using either or both
*/

enum UIQueryFieldType {
    case text, numeric
}

enum UIQueryFieldDesignator {
    case keywordList, yearRangeStart, yearRangeEnd, idPattern
    , invSectionName, invAlbumName
    , invPartSetM
    , invPartSetOfN
    , invPartSetVal(String)
    , notes
}

struct UIQueryFieldConfiguration {
    var designator: UIQueryFieldDesignator = .keywordList
    var type: UIQueryFieldType = .text
    var placeholder: String = ""
    
    // this object's job is to set up configuration instructions for the various text fields
    init( type des: UIQueryFieldDesignator) {
        designator = des
        switch des {
        case .notes:
            // set up the single text field config
            //placeholder = ""
            type = .text
            break
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
        case .invSectionName:
            // set up the single text field config
            placeholder = "Section name (nonblank)"
            type = .text
            break
        case .invAlbumName:
            // set up the single text field config
            placeholder = "Album Group name (nonblank)"
            type = .text
            break
        case .invPartSetM:
            // set up the two numeric field configs
            placeholder = "Which part M (M of N)"
            type = .numeric
            break
        case .invPartSetOfN:
            // set up the two numeric field configs
            placeholder = "Number of parts N (M of N)"
            type = .numeric
            break
        case .invPartSetVal(let option):
            // set up the two numeric field configs
            placeholder = "Value \(option)"
            type = .numeric // allows text too, but no emoji
            break
        }
    }
}

enum UIQueryAlertType {
    case keyword, yearRange, subCategory
    , invAskSection(String) // include existing section names to avoid
    , invAskAlbum(String) // include existing album names to avoid
    , invAskSectionAndAlbum(String,String) // include both the above
    , invAskPartialSetValues
    , invAskNotes
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
        case .invAskSection(let secnames):
            // set up the single text field config
            title = "New Section Name"
            body = "Enter the (required) name of the new Section in this Album.\n" +
            "Do not use one of the section names already used: \(secnames).\n"
            fieldConfigs.append(UIQueryFieldConfiguration(type: .invSectionName))
            break
        case .invAskAlbum(let albnames):
            // set up the single text field config
            title = "New Album Name"
            body = "Enter the (required) name of the new Album group.\n" +
                "Do not provide any numeric suffix, such as XXX01; just XXX.\n" +
            "Do not use one of the album names already used: \(albnames).\n"
            fieldConfigs.append(UIQueryFieldConfiguration(type: .invAlbumName))
            break
        case .invAskSectionAndAlbum(let secnames, let albnames):
            // set up the single text field config
            title = "New Section and Album Names"
            body = "Enter the (required) name of the new Section.\n" +
                "Do not use one of the section names already used: \(secnames).\n" +
                "\nAlso, enter the name of the new Album group.\n" +
                "Do not provide any numeric suffix, such as XXX01; just XXX.\n" +
            "Do not use one of the album names already used: \(albnames).\n"
            fieldConfigs.append(UIQueryFieldConfiguration(type: .invSectionName))
            fieldConfigs.append(UIQueryFieldConfiguration(type: .invAlbumName))
            break
        case .invAskPartialSetValues:
            // set up the single text field config
            title = "Partial Set Description"
            body = "Enter the number of Parts to split the Set, and which one (m of n).\n" +
                "Then enter up to four Values in order.\n" +
                "Each Value describes an individual Part, i.e, denomination, color.\n" +
            "The description of the partial set will be added to the Inventory Item pending its location."
            fieldConfigs.append(UIQueryFieldConfiguration(type: .invPartSetOfN))
            fieldConfigs.append(UIQueryFieldConfiguration(type: .invPartSetM))
            fieldConfigs.append(UIQueryFieldConfiguration(type: .invPartSetVal("1")))
            fieldConfigs.append(UIQueryFieldConfiguration(type: .invPartSetVal("2 (OPT)")))
            fieldConfigs.append(UIQueryFieldConfiguration(type: .invPartSetVal("3 (OPT)")))
            fieldConfigs.append(UIQueryFieldConfiguration(type: .invPartSetVal("4 (OPT)")))
            break
        case .invAskNotes:
            // set up the single text field config
            title = "Inventory Notes"
            body = "Enter notes about any distinguishing characteristics of the item.\n" +
            "This description of the item will be added to the Inventory Item pending its location."
            fieldConfigs.append(UIQueryFieldConfiguration(type: .notes))
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
    var status: UITextField!
    var userCompletionHandler: ((SearchType) -> Void)?

    init(type: UIQueryAlertType, completion: @escaping (SearchType) -> Void) {
        config = UIQueryAlertConfiguration(type: type)
        userCompletionHandler = completion
        // lots here eventually
        super.init()
    }

    func RunWithViewController(_ vc: UIViewController, withStatus statstr: String = "", andPresets presets: [String] = []) {
        fields = []
        let ac = UIAlertController(title: config.title, message: config.body, preferredStyle: .alert)
        let can = UIAlertAction(title: "Cancel", style: .cancel) { x in
            // do nothing here
        }
        ac.addAction(can)
        let act = UIAlertAction(title: "OK", style: .default) { x in
            // run the user's completion handler in response to OK being pressed
            if let handler = self.userCompletionHandler {
                let result : SearchType
                switch self.config.type {
                case .keyword:
                    let text : String = self.fields[0].text ?? ""
                    var words = text.isEmpty ? [] : text.components(separatedBy: " ") // split this at spaces
                    if words.count > 0 && words[0] == "ALL" {
                        words.remove(at: 0)
                        result = SearchType.keyWordListAll(words)
                    } else {
                        result = SearchType.keyWordListAny(words)
                    }
                    handler(result)
                case .subCategory:
                    let text : String = self.fields[0].text ?? ""
                    result = SearchType.subCategory(text)
                    handler(result)
                case .yearRange:
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
                case .invAskSection(let namelist), .invAskAlbum(let namelist):
                    // KLUDGE - we need to use a SearchType.location to return the textual result
                    let text : String = self.fields[0].text ?? ""
                    var valTypes:[InvValidationType] = [.empty, .inUse(namelist)]
                    if case .invAskAlbum = self.config.type {
                        valTypes += [.numSuffix]
                    }
                    let statcode:InvValidationType = self.validateInvUsage(types:valTypes, forText: text)
                    if statcode != .OK {
                        let statstr = "Name is: \(statcode)"
                        self.RunWithViewController(vc, withStatus: statstr, andPresets: [text])
                        return
                    }
                    result = SearchType.location(text)
                    handler(result)
                case .invAskSectionAndAlbum(let namelist1, let namelist2):
                    // KLUDGE - we need to use a SearchType.location to return the textual result
                    let text1 : String = self.fields[0].text ?? "" // section
                    let text2 : String = self.fields[1].text ?? "" // album
                    let statcode1 = self.validateInvUsage(types: [.empty, .inUse(namelist1)], forText: text1)
                    let statcode2 = self.validateInvUsage(types: [.empty, .inUse(namelist2), .numSuffix], forText: text2)
                    if statcode1 != .OK || statcode2 != .OK {
                        let statstr = "Section is: \(statcode1); Album is: \(statcode2)"
                        self.RunWithViewController(vc, withStatus: statstr, andPresets: [text1, text2])
                        return
                    }
                    // the double result is returned as a string delimited by a semicolon (disallow semicolons in names)
                    let text = "\(text1);\(text2)"
                    result = SearchType.location(text)
                    handler(result)
                case .invAskPartialSetValues:
                    // the values are packed into a keyword array
                    // by convention, N and M are first; defaults are "" if not entered
                    var results:[String] = []
                    for field in self.fields {
                        results.append(field.text ?? "")
                    }
                    result = SearchType.keyWordListAny(results)
                    handler(result)
                case .invAskNotes:
                    // the values are packed into a keyword array
                    // by convention, N and M are first; defaults are "" if not entered
                    var results:[String] = ["n", ""]
                    for field in self.fields {
                        results.append(field.text ?? "")
                    }
                    result = SearchType.keyWordListAny(results)
                    handler(result)
                }
            }
        }
        ac.addAction(act)
        // add a status label
        ac.addTextField() { (statusField) in
            statusField.delegate = self
            statusField.tag = -1
            statusField.text = statstr
            self.status = statusField
        }
        // add the text fields required by the configuration
        for index in 0..<config.getConfigurationCount() {
            let fldconfig = config.getConfiguration(index)
            ac.addTextField() { (textField) in
                textField.delegate = self
                textField.placeholder = fldconfig.placeholder
                if presets.count > index && !presets[index].isEmpty {
                    textField.text = presets[index]
                }
                textField.tag = index
                textField.clearButtonMode = .whileEditing
                if fldconfig.type == .numeric {
                    textField.keyboardType = .numbersAndPunctuation //.NumberPad
                } else if fldconfig.type == .text {
                    textField.keyboardType = .default //.ASCIICapable
                    switch self.config.type {
                    case .invAskSection, .invAskAlbum, .invAskSectionAndAlbum:
                        textField.autocapitalizationType = .allCharacters
                    default:
                        break
                    }
                }
                textField.returnKeyType = .done
                if index == 0 {
                    // NOTE: this is automatically called the first time, but not for validation retries, so best to do it here
                    textField.becomeFirstResponder()
                }
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
        // runs when keyboard Done is pressed, does nothing except edit next field (if more than one), or pass control on to the OK handler
        return true
    }
    
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        if textField.tag < 0 {
            return false // disallow editing the status label
        }
        return true
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        //textField.becomeFirstResponder() // not needed here
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        //updateModel() // name field updated and keyboard dismissed
        //textField.resignFirstResponder() // not needed here
    }
    
    enum InvValidationType: CustomStringConvertible, Equatable {
        case OK, badUse, empty, inUse(String), numSuffix
        
        static func == (lhs: InvValidationType, rhs: InvValidationType) -> Bool {
            return lhs.description == rhs.description
        }
        
        var description: String {
            switch self {
            case .OK:
                return "OK"
            case .empty:
                return "Empty"
            case .inUse:
                return "In Use"
            case .numSuffix:
                return "Numeric Suffix"
            default:
                return "Bad Use"
            }
        }
    }
    
    func validateInvUsage(types: [InvValidationType], forText text: String?) -> InvValidationType {
        if let text=text {
            for type in types {
                switch type {
                case .empty:
                    if text.isEmpty {
                        print("Name is empty, nonblank required. Please try again.")
                        return .empty
                    }
                case .inUse(let names):
                    let pnames = names.components(separatedBy: ",")
                    if pnames.contains(text) {
                        print("Name \(text) is in list \(pnames); try again.")
                        return .inUse(names)
                    }
                case .numSuffix:
                    let (_, sfx) = splitNumericEndOfString(text)
                    if !sfx.isEmpty {
                        print("Name \(text) has numeric suffix \(sfx); try again.")
                        return .numSuffix
                    }
                default:
                    break
                }
            }
            print("Name \(text) is validated")
            return .OK
        } else {
            print("No text entered. Please try again.")
            return .badUse
        }
   }
    
    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        // validation traditionally should occur here - return true if AOK, false if something needs correction
        // NOTE: I have chosen to implement full validation with the OK button press
        return true
    }

}
