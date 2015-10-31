//
//  InfoItemViewController.swift
//  StampCollection
//
//  Created by Michael L Mehr on 6/4/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import UIKit

class InfoItemViewController: UIViewController {

    // set by client for info (CoreData object) usage
    var item: DealerItem!
    
    // OPT - set by client instead of the above for DealerItem object usage
    var btitem: BTDealerItem!
    var btcat: BTCategory!
    
    private var usingBT: Bool {
        if btitem != nil && btcat != nil {
            return true
        }
        return false
    }
    private var itemID: String {
        return usingBT ? btitem.code  : item.id
    }
    private var itemDescription: String {
        return usingBT ? btitem.descr  : item.descriptionX
    }
    private var itemCategoryName: String {
        return usingBT ? btcat.name  : item.category.name
    }
    private var itemPictid: String {
        return usingBT ? btitem.picref : item.pictid
    }
    private var picPageURL: NSURL? {
        return usingBT ? btitem.picPageURL  : item.picPageURL
    }
    private var picFileURLSource: NSURL? {
        return usingBT ? btitem.picFileRemoteURL  : item.picFileRemoteURL
    }
    private var picFileURLDestination: NSURL? {
        return usingBT ? btitem.getThePicFileLocalURL(btcat.number)  : item.picFileLocalURL
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        // make sure the toolbar is visible
//        self.navigationController?.navigationBarHidden = false
//        self.navigationController?.toolbarHidden = false
        updateUI()
    }

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var categoryLabel: UILabel!
    @IBOutlet weak var idLabel: UILabel!
    @IBOutlet weak var yearRangeLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var webInfoButton: UIBarButtonItem!
    @IBAction func refreshButtonPressed(sender: AnyObject) {
        // download image file if needed (on background thread) to display later
        downloadAndDisplayImage()
    }
    
    func updateUI() {
        categoryLabel.text = itemCategoryName
        idLabel.text = itemID
        yearRangeLabel.text = usingBT ? "" : item.normalizedDate
        descriptionLabel.text = itemDescription
        // set imageView to a webkit view if possible showing the BT or JS panel, using pictid
        if let pfrurl = picFileURLSource {
            print("TBD- Downloading file:\(pfrurl.absoluteString) for pictid:\(itemPictid)")
        }
        if let pflurl = picFileURLDestination {
            print("TBD- Caching file:\(pflurl.absoluteString) for pictid:\(itemPictid)")
        }
        webInfoButton.enabled = picPageURL != nil
        if !displayImageFileIfPossible() {
            // download image file if needed (on background thread) to display later
            downloadAndDisplayImage()
        }
    }

    // MARK: image file manipulations
    private func isImageFilePresent() -> Bool {
        var result = false
        let fm = NSFileManager.defaultManager()
        if let destURL = picFileURLDestination {
            result = fm.fileExistsAtPath( destURL.absoluteString )
        }
        return result
    }
    
    private func displayImageFileIfPossible() -> Bool {
        var result = false
        if let destURL = picFileURLDestination where isImageFilePresent()
        {
            let filename = destURL.absoluteString
            imageView.image = UIImage(contentsOfFile: filename)
            result = true
        }
        return result
    }

    private func downloadAndDisplayImage() {
        // run this on a background thread
        if let imageSource = picFileURLSource {
            imageView.imageFromUrl(imageSource) { image in
                if let image = image {
                    self.imageView.image = image
                }
            }
        }
    }
    
    /*
    // MARK: - Navigation
    */

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "Show Web Page Segue" {
            // Get the new view controller using segue.destinationViewController.
            if let dvc = segue.destinationViewController as? WebItemViewController,
                url = picPageURL{
                // Pass the selected object to the new view controller.
                print("Displaying page:\(url.absoluteString) for pictid:\(itemPictid)")
                dvc.url = url
            }
        }
    }

}
