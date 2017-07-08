//
//  InfoItemViewController.swift
//  StampCollection
//
//  Created by Michael L Mehr on 6/4/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import UIKit

class InfoItemViewController: UIViewController, BTInfoProtocol {

    // set by client for info (CoreData object) usage
    var item: DealerItem!
    
    // OPT - set by client instead of the above for DealerItem object usage
    var btitem: BTDealerItem!
    var btcat: BTCategory!
    
    var infoNode = BTMessageDelegate()
    private var oldLabel: String?
    private var extraInfo: String? {
        willSet {
            if let newValue = newValue {
                // set label extension
                if let text = descriptionLabel.text {
                    oldLabel = text
                    descriptionLabel.text = "\(text)\n\(newValue)"
                }
            } else {
                // remove label extension
                if let old = oldLabel {
                    descriptionLabel.text = "\(old)"
                }
            }
        }
    }
    
    fileprivate var usingBT: Bool {
        if btitem != nil && btcat != nil {
            return true
        }
        return false
    }
    fileprivate var itemID: String {
        return usingBT ? btitem.code  : item.id
    }
    fileprivate var itemDescription: String {
        return usingBT ? btitem.descr  : item.descriptionX
    }
    fileprivate var itemCategoryName: String {
        return usingBT ? btcat.name  : item.category.name
    }
    fileprivate var itemCategoryNumber: Int16 {
        return usingBT ? btcat.infoNumber  : item.category.number
    }
    fileprivate var itemPictid: String {
        return usingBT ? btitem.picref : item.pictid
    }
    fileprivate var picPageURL: URL? {
        return usingBT ? btitem.picPageURL  : item.picPageURL as URL?
    }
    fileprivate var picFileURLSource: URL? {
        return usingBT ? btitem.picFileRemoteURL  : item.picFileRemoteURL as URL?
    }
    fileprivate var picFileURLDestination: URL? {
        return usingBT ? btitem.getThePicFileLocalURL(btcat.number)  : item.picFileLocalURL
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        // make sure the toolbar is visible
//        self.navigationController?.navigationBarHidden = false
//        self.navigationController?.toolbarHidden = false
        infoNode.delegate = self
        updateUI()
    }

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var categoryLabel: UILabel!
    @IBOutlet weak var idLabel: UILabel!
    @IBOutlet weak var yearRangeLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var webInfoButton: UIBarButtonItem!
    @IBAction func refreshButtonPressed(_ sender: AnyObject) {
        // download image file if needed (on background thread) to display later
        downloadAndDisplayImage()
    }
    
    func updateUI() {
        categoryLabel.text = itemCategoryName
        idLabel.text = itemID
        yearRangeLabel.text = usingBT ? "" : item.normalizedDate
        descriptionLabel.text = itemDescription
        // set imageView to a webkit view if possible showing the BT or JS panel, using pictid
//        if let pfrurl = picFileURLSource {
//            print("TBD- Downloading file:\(pfrurl.absoluteString) for pictid:\(itemPictid)")
//        }
//        if let pflurl = picFileURLDestination {
//            print("TBD- Caching file:\(pflurl.absoluteString) for pictid:\(itemPictid)")
//        }
        webInfoButton.isEnabled = picPageURL != nil
        if let nodeUrl = picPageURL?.absoluteString {
            infoNode.loadItemDetailsFromWeb(nodeUrl, forCategory: itemCategoryNumber)
        }
        if !displayImageFileIfPossible() {
            // download image file if needed (on background thread) to display later
            downloadAndDisplayImage()
        }
    }
    
    // MARK: BTInfoProtocol
    func messageHandler(_ handler: BTMessageDelegate, receivedData data: AnyObject, forCategory category: Int) {
        if let data = data as? [String:String], let info = data["info"] {
            print("Data received from infoNode:\(data)")
            extraInfo = info
        }
    }

    // MARK: image file manipulations
    fileprivate func isImageFilePresent() -> Bool {
        var result = false
        let fm = FileManager.default
        if let destURL = picFileURLDestination {
            result = fm.fileExists( atPath: destURL.absoluteString )
        }
        return result
    }
    
    fileprivate func displayImageFileIfPossible() -> Bool {
        var result = false
        if let destURL = picFileURLDestination , isImageFilePresent()
        {
            let filename = destURL.absoluteString
            imageView.image = UIImage(contentsOfFile: filename)
            result = true
        }
        return result
    }

    fileprivate func downloadAndDisplayImage() {
        // run this on a background thread
        if let imageSource = picFileURLSource {
            imageView.imageFromUrl(imageSource) { image, urlReceived in
                if let image = image , urlReceived == imageSource {
                    self.imageView.image = image
                }
            }
        }
    }
    
    /*
    // MARK: - Navigation
    */

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "Show Web Page Segue" {
            // Get the new view controller using segue.destinationViewController.
            if let dvc = segue.destination as? WebItemViewController,
                let url = picPageURL{
                // Pass the selected object to the new view controller.
                print("Displaying page:\(url.absoluteString) for pictid:\(itemPictid)")
                dvc.url = url
            }
        }
    }

}
