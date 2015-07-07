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
        if let bti = btitem, btc = btcat {
            return true
        }
        return false
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
    
    func updateUI() {
        categoryLabel.text = usingBT ? btcat.name  : item.category.name
        idLabel.text = usingBT ? btitem.code  : item.id
        yearRangeLabel.text = usingBT ? "" : item.normalizedDate
        descriptionLabel.text = usingBT ? btitem.descr  : item.descriptionX
        // set imageView to a webkit view if possible showing the BT or JS panel, using pictid
        let url = usingBT ? btitem.picref  : item.pictid
        println("TBD- Displaying pictid:\(url)")
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
