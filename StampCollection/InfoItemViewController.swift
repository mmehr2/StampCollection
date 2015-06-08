//
//  InfoItemViewController.swift
//  StampCollection
//
//  Created by Michael L Mehr on 6/4/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import UIKit

class InfoItemViewController: UIViewController {
    
    var item: DealerItem!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        // make sure the toolbar is visible
//        self.navigationController?.navigationBarHidden = false
//        self.navigationController?.toolbarHidden = false
        updateUI()
    }

    @IBOutlet weak var categoryLabel: UILabel!
    @IBOutlet weak var idLabel: UILabel!
    @IBOutlet weak var yearRangeLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    
    func updateUI() {
        categoryLabel.text = item.category.name
        idLabel.text = item.id
        yearRangeLabel.text = item.normalizedDate
        descriptionLabel.text = item.descriptionX
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
