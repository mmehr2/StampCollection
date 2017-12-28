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

    let CATEG_SHEETS: Int16 = 31
    
    func updateUI() {
        categoryLabel.text = itemCategoryName
        idLabel.text = itemID
        yearRangeLabel.text = usingBT ? "" : item.normalizedDate
        descriptionLabel.text = itemDescription
        webInfoButton.isEnabled = picPageURL != nil
        if let nodeUrl = picPageURL?.absoluteString, (itemCategoryNumber == CATEG_SETS || itemCategoryNumber == CATEG_SHEETS) {
            var catnumToUse = itemCategoryNumber
            if itemCategoryNumber == CATEG_SHEETS {
                catnumToUse = CATEG_SETS
                // picPageURL is already set to display the base set here, no need to change that
            }
            infoNode.loadItemDetailsFromWeb(nodeUrl, forCategory: catnumToUse)
        }
        if !displayImageFileIfPossible() {
            // download image file if needed (on background thread) to display later
            downloadAndDisplayImage()
        }
        if usingBT {
            let lflst = btitem.leafletList
            print("BT leaflets = <\(lflst)>")
            if let dt = btitem.details {
                print("BT Bulletin list:\n\(dt.bulletinList.joined(separator: "-"))")
                let cat1List = btitem.catalog1List
                let cat2List = btitem.catalog2List
                if dt.isSouvenirSheet {
                    let cat1ListSS = cat1List.map{ "Souv.Sheet" + ($0.isEmpty ? "" : " - Catalog1: " + $0) }
                    let cat2ListSS = cat2List.map{ ($0.isEmpty ? "" : ", Catalog2: " + $0) }
                    let fs = zip(cat1ListSS, cat2ListSS).flatMap{ x, y in return x+y }
                    let ssheetList = fs.joined(separator: "\n")
                    print("BT Souvenir sheet list:\n\(ssheetList)")
                } else {
                    let fsdList = dt.fullSheetDetails
                    let cat1ListSh = cat1List.map{ ($0.isEmpty ? "" : ", Catalog1: " + $0 + "full") }
                    let cat2ListSh = cat2List.map{ ($0.isEmpty ? "" : ", Catalog2: " + $0 + "full") }
                    let fs1 = zip(fsdList, cat1ListSh).flatMap{ x, y in return x+y }
                    let fs2 = zip(fs1, cat2ListSh).flatMap{ (arg) -> <#Result#> in let (x, y) = arg; return x+y }
                    let sheetList = fs2.joined(separator: "\n")
                    print("BT Full sheet list:\n\(sheetList)")
                }
            }
        }
    }
    
    // MARK: BTInfoProtocol
    func messageHandler(_ handler: BTMessageDelegate, receivedDetails data: BTItemDetails, forCategory category: Int) {
        DispatchQueue.main.async {
            print("Data received from infoNode:\(data)")
            self.extraInfo = data.description
            let dr = data.dateRange
            if !dr.isEmpty {
                self.yearRangeLabel.text = dr
            }
            if !self.usingBT {
                print("Full sheet list:\n\(data.fullSheetDetails.joined(separator: "\n"))")
            }
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
