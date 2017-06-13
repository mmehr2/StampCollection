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
/*
IDEA: To send images, use Dropbox to send a big ZIP file. Here's a framework to use Dropbox2 API from Swift:
https://github.com/dropbox/swiftydropbox

CRASH NOTES:
I tried this on my iPhone 6: various misbehaviors happened.
1) The VC comes up. If I Send the email, it goes out but the VC doesn't dismiss and the delegate callback doesn't get called.
2) If I Cancel, when I Delete Draft, the app crashes without calling the callback. (GPFLT at AppDelegate line 1) EXC_BAD_ACCESS code=1 adr=<random 0xdca5beb8 (note that "beb8" again!)
3) If I Cancel, and Save Draft, same crash and no callback. EXC_BAD_ACCESS code=1 adr=0x188beb8
4) On Simulator, if I Send, the app crashes same way (GPFLT on AppDelegate line 1). code=1 adr=0x18
5) On Simulator, Cancel/Delete Draft, app runs callback properly but crashes trying to do errFunc()
  But then it crahsed again, but code=EXC_I386_GPFLT no adr given
6) On Simulator, Cancel/Save Draft, same crash (GPFLT on AppDelegate line 1). code=1 adr=0x18

From about 10 test runs on device and sim, with various paths, I conclude:
On device, crash is intermittent and only on Cancel (either way) - Send always sends but will not dismiss the VC or get to my breakpoint.
On simulator, crash has also happened intermittently, but when it passes breakpoint, it fails in the errFunc() call.
*/

private var mailController: MFMailComposeViewController!

class EmailAttachmentExporter: NSObject, MFMailComposeViewControllerDelegate {
    var controller: UIViewController!
    
    var errFunc : ((NSError) -> Void)?
    
    init( forController vc: UIViewController, errorHandler: ((NSError) -> Void)? = nil ) {
        super.init()
        controller = vc
        errFunc = errorHandler
    }
    
    func sendFiles(_ fileSuffix: String = "") -> Bool {
        // The files to send are: CATEGORY.CSV, INFO.CSV, INVENTORY.CSV from the Documents directory
        // The file suffix is an optional string to add to each base name (INFOxxx.CSV) in case we use multiple sets of files for user backup
        var ecode = 0
        
        let now = Date()
        let datestr = getFormattedStringFromDate(now, withTime: true)
        let versionstr = "v1.0"
        let emailSubject = "Stamp Collection Backup \(versionstr) at \(datestr)"

        let fileExtension = ".csv"
        let file1 = "category" + fileSuffix + fileExtension
        let file2 = "info" + fileSuffix + fileExtension
        let file3 = "inventory" + fileSuffix + fileExtension
        let emailBody = "Sending the following attachments:\n\t\(file1)\n\t\(file2)\n\t\(file3)\n"
        
        let recipient1 = "mmehr2@yahoo.com" // TBD: make this a setting
        let toRecipients = [recipient1]
        
        let ad = UIApplication.shared.delegate! as! AppDelegate
        let file1url = ad.applicationDocumentsDirectory.appendingPathComponent(file1)
        let file2url = ad.applicationDocumentsDirectory.appendingPathComponent(file2)
        let file3url = ad.applicationDocumentsDirectory.appendingPathComponent(file3)
        
        // check file existence first, to make sure we can send
        // fail if we can't send them all
        let fileManager = FileManager.default
        let file1exists = fileManager.fileExists(atPath: file1url.path)
        let file2exists = fileManager.fileExists(atPath: file2url.path)
        let file3exists = fileManager.fileExists(atPath: file3url.path)
        if !(file1exists && file2exists && file3exists) {
            if !file1exists { ecode += 1; print("Error preparing for email export: \(file1url.path) doesn't exist.") }
            if !file2exists { ecode += 2; print("Error preparing for email export: \(file2url.path) doesn't exist.") }
            if !file3exists { ecode += 4; print("Error preparing for email export: \(file3url.path) doesn't exist.") }
            if let errFunc = errFunc {
                errFunc( NSError(domain: "StampCollection", code: ecode, userInfo: nil) )
            }
            return false
        }

        // replace with SSZipArchive
        let zipFileExtension = ".sczp" // can be used for custom registration for import feature
        let zipFilename = "StampCollection" + zipFileExtension
        let zipFileurl = ad.applicationDocumentsDirectory.appendingPathComponent(zipFilename)
        var error : NSError?
        do {
            try fileManager.removeItem(at: zipFileurl)
        } catch let error1 as NSError {
            error = error1
        }
        if error != nil {
            ecode += 8
            print("Unable to remove existing ZIPFILE: \(error!.localizedDescription).")
        }
        let fileUrls = [file1url.path, file2url.path, file3url.path]
        let zipArchiveOK = SSZipArchive.createZipFile(atPath: zipFileurl.path, withFilesAtPaths:fileUrls)
        if !zipArchiveOK {
            ecode += 16
            print("Unable to create ZIPFILE archive \(zipFilename): \(error!.localizedDescription).")
            if let errFunc = errFunc {
                errFunc( NSError(domain: "StampCollection", code: ecode, userInfo: nil) )
            }
            return false
        }
        
        guard let fileData = try? Data(contentsOf: zipFileurl) else {
            ecode += 32
            print("Unable to read ZIPFILE archive \(zipFilename).")
            if let errFunc = errFunc {
                errFunc( NSError(domain: "StampCollection", code: ecode, userInfo: nil) )
            }
            return false
        }

        
        let mimeType = "application/zip"
        
        // make sure email feature is available (running on device)
        if !MFMailComposeViewController.canSendMail() {
            ecode += 64
            if let errFunc = errFunc {
                errFunc( NSError(domain: "StampCollection", code: ecode, userInfo: nil) )
            }
            return false
        }

        // rather than using a local var here, we hold the reference in a private var instead
        // this assures the controller's lifetime while it is doing its work
        mailController = MFMailComposeViewController()
        mailController.mailComposeDelegate = self
        mailController.setSubject(emailSubject)
        mailController.setMessageBody(emailBody, isHTML: false)
        mailController.setToRecipients(toRecipients)
        
        mailController.addAttachmentData(fileData, mimeType: mimeType, fileName: zipFilename)
        
        // present the VC on behalf of the provided VC
        controller.present(mailController, animated: true, completion: nil)
        return true
    }
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?)
    {
        //var errHappened = false
//        let fakeError = NSError(domain: "StampCollection", code: 0, userInfo: nil)
//        let fakeError2 = NSError(domain: "StampCollection", code: -1, userInfo: nil)
//        let errorEx = error ?? fakeError2
        switch result {
        case MFMailComposeResult.cancelled:
            print("Email canceled by user")
            break
        case MFMailComposeResult.saved:
            print("Email saved by user")
            break
        case MFMailComposeResult.sent:
            print("Email sent by user")
            break
        case MFMailComposeResult.failed:
            print("Email sent by user but failed due to error \(error!.localizedDescription)")
            //errHappened = true
            break
        //default:
        //    break
        }
        
        // dismiss the VC
        controller.dismiss(animated: true) {
            // try doing nothing here
        }
//        if let errFunc = self.errFunc {
//            if errHappened {
//                errFunc(errorEx)
//            } else {
//                errFunc(fakeError)
//            }
//        }
    }
}

// NOTE: function required to allow result to be used in a switch statement (check if still needed: Swift 1.2)
// why doesn't Apple define this?
func ~=( lhs: MFMailComposeResult, rhs: MFMailComposeResult) -> Bool {
    return lhs.rawValue ~= rhs.rawValue
}

