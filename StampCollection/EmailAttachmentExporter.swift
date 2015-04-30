//
//  EmailAttachmentExporter.swift
//  StampCollection
//
//  Created by Michael L Mehr on 4/28/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import UIKit
import MessageUI

// this object will invoke the Apple UI to send a preset email message with attachments the user can edit before sending
// NOTE: Apple does NOT allow full programmatic email sends
// NOTE: Causes Simulator to crash, due to no Email application installed. Need a device!

class EmailAttachmentExporter: NSObject, MFMailComposeViewControllerDelegate {
    var controller: UIViewController!
    
    var errFunc : ((NSError) -> Void)?
    
    init( forController vc: UIViewController, errorHandler: ((NSError) -> Void)? = nil ) {
        controller = vc
        errFunc = errorHandler
    }
    
    func sendFiles(fileSuffix: String = "") -> Bool {
        // The files to send are: CATEGORY.CSV, INFO.CSV, INVENTORY.CSV from the Documents directory
        // The file suffix is an optional string to add to each base name (INFOxxx.CSV)
        
        let now = NSDate()
        let datestr = getFormattedStringFromDate(now, withTime: true)
        let emailSubject = "Stamp Collection Backup for \(datestr)"

        let fileExtension = ".CSV"
        let file1 = "CATEGORY" + fileSuffix + fileExtension
        let file2 = "INFO" + fileSuffix + fileExtension
        let file3 = "INVENTORY" + fileSuffix + fileExtension
        let emailBody = "Sending the following attachments:\n\t\(file1)\n\t\(file2)\n\t\(file3)\n"
        
        let recipient1 = "mmehr2@yahoo.com" // make this a setting
        let toRecipients = [recipient1]
        
        let ad = UIApplication.sharedApplication().delegate! as! AppDelegate
        let file1url = ad.applicationDocumentsDirectory.URLByAppendingPathComponent(file1)
        let file2url = ad.applicationDocumentsDirectory.URLByAppendingPathComponent(file2)
        let file3url = ad.applicationDocumentsDirectory.URLByAppendingPathComponent(file3)
        
        // check file existence first, to make sure we can send
        // fail if we can't send them all
        let fileManager = NSFileManager.defaultManager()
        let file1exists = fileManager.fileExistsAtPath(file1url.path!)
        let file2exists = fileManager.fileExistsAtPath(file2url.path!)
        let file3exists = fileManager.fileExistsAtPath(file3url.path!)
        if !(file1exists && file2exists && file3exists) {
            if let errFunc = errFunc {
                errFunc( NSError(domain: "StampCollection", code: 1, userInfo: nil) )
            }
            if !file1exists { println("Error preparing for email export: \(file1) doesn't exist.") }
            if !file2exists { println("Error preparing for email export: \(file2) doesn't exist.") }
            if !file3exists { println("Error preparing for email export: \(file3) doesn't exist.") }
            return false
        }

        let file1Data = NSData(contentsOfURL: file1url)
        let file2Data = NSData(contentsOfURL: file2url)
        let file3Data = NSData(contentsOfURL: file3url)
        
        let mimeType = "text/csv"
        
        var mc = MFMailComposeViewController()
        mc.mailComposeDelegate = self
        mc.setSubject(emailSubject)
        mc.setMessageBody(emailBody, isHTML: false)
        mc.setToRecipients(toRecipients)
        
        mc.addAttachmentData(file1Data, mimeType: mimeType, fileName: file1)
        mc.addAttachmentData(file2Data, mimeType: mimeType, fileName: file2)
        mc.addAttachmentData(file3Data, mimeType: mimeType, fileName: file3)
        
        // present the VC on behalf of the provided VC
        controller.presentViewController(mc, animated: true, completion: nil)
        return true
    }
    
    func mailComposeController(controller: MFMailComposeViewController!, didFinishWithResult result: MFMailComposeResult, error: NSError!)
    {
        var errHappened = false
        switch result {
        case MFMailComposeResultCancelled:
            println("Email canceled by user")
            break
        case MFMailComposeResultSaved:
            println("Email saved by user")
            break
        case MFMailComposeResultSent:
            println("Email sent by user")
            break
        case MFMailComposeResultFailed:
            println("Email sent by user but failed due to error \(error.localizedDescription)")
            errHappened = true
            break
        default:
            break
        }
        
        // dismiss the VC
        controller.dismissViewControllerAnimated(true) {
            if let errFunc = self.errFunc where errHappened {
                errFunc(error)
            }
        }
    }
}

// why doesn't Apple define this?? and why the constants and not an ENUM???
func ~=( lhs: MFMailComposeResult, rhs: MFMailComposeResult) -> Bool {
    return lhs.value ~= rhs.value
}

