//
//  InventoryItemViewController.swift
//  StampCollection
//
//  Created by Michael L Mehr on 11/5/15.
//  Copyright © 2015 Michael L. Mehr. All rights reserved.
//

import UIKit

class InventoryItemViewController: UIViewController {
    
    var model: CollectionStore!
    
    var item: InventoryItem!

    @IBOutlet weak var itemView: InventoryItemView!
    @IBOutlet weak var refersButton: UIBarButtonItem!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        updateUI()
    }
    
    fileprivate func updateUI() {
        title = "Edit \(item.dealerItem.descriptionX) \(item.itemCondition)"
        refersButton.isEnabled = item.referredItem != nil
        itemView.wanted = item.wanted
        itemView.picURL = item.dealerItem.picFileRemoteURL
        let (top, btm) = getTitlesForInventoryItem(item)
        itemView.condition = top
        itemView.title = btm
    }

    /// call after any changes on the item target
    fileprivate func reload() {
        // save the data and update the UI
        model.saveMainContext()
        updateUI()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func wantHaveButtonPressed(_ sender: AnyObject) {
        item.wantHave = item.wanted ? "h" : "w"
        reload()
    }
    
    @IBAction func descButtonPressed(_ sender: AnyObject) {
    }
    
    @IBAction func notesButtonPressed(_ sender: AnyObject) {
    }
    
    @IBAction func priceButtonPressed(_ sender: AnyObject) {
    }
    
    @IBAction func refersButtonPressed(_ sender: AnyObject) {
        // first make sure we have an item of the referred type, in the same condition (mint/FDC/..)
        let itemsThatMatchX = (item.referredItem?.inventoryItems.filter {
            ($0 as AnyObject).itemType == item.itemType
        })
        let itemsThatMatch = itemsThatMatchX ?? [] // SWIFT BUG? 11/6/15 - should combine these expressions
        let count = itemsThatMatch.count
        // if we have any of these, pick the first and segue to the page it is on
        if count > 0,
            let page = (itemsThatMatch.first as? InventoryItem)?.page {
            performSegue(withIdentifier: "Show Ref From Inv Segue", sender: page)
        }
        // if not, segue to the info page for that item
        else {
            performSegue(withIdentifier: "Show Info From Inv Segue", sender: item.referredItem)
        }
    }

    @IBAction func infoButtonPressed(_ sender: AnyObject) {
        performSegue(withIdentifier: "Show Info From Inv Segue", sender: item.dealerItem)
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.Show Ref From Inv Segue
        if segue.identifier == "Show Info From Inv Segue" {
            if let dvc = segue.destination as? InfoItemViewController {
                dvc.item = sender as? DealerItem
            }
        }
        if segue.identifier == "Show Ref From Inv Segue" {
            if let dvc = segue.destination as? AlbumPageViewController {
                dvc.setStartPage((sender as? AlbumPage)!)
            }
        }
    }

}
