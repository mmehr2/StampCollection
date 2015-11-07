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
    
    private func updateUI() {
        title = "Edit \(item.dealerItem.descriptionX) \(item.itemCondition)"
        refersButton.enabled = item.referredItem != nil
        itemView.wanted = item.wanted
        itemView.picURL = item.dealerItem.picFileRemoteURL
        let (top, btm) = getTitlesForInventoryItem(item)
        itemView.condition = top
        itemView.title = btm
    }

    /// call after any changes on the item target
    private func reload() {
        // save the data and update the UI
        model.saveMainContext()
        updateUI()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func wantHaveButtonPressed(sender: AnyObject) {
        item.wantHave = item.wanted ? "h" : "w"
        reload()
    }
    
    @IBAction func descButtonPressed(sender: AnyObject) {
    }
    
    @IBAction func notesButtonPressed(sender: AnyObject) {
    }
    
    @IBAction func priceButtonPressed(sender: AnyObject) {
    }
    
    @IBAction func refersButtonPressed(sender: AnyObject) {
        // first make sure we have an item of the referred type, in the same condition (mint/FDC/..)
        let itemsThatMatchX = (item.referredItem?.inventoryItems.filter {
            $0.itemType == item.itemType
        })
        let itemsThatMatch = itemsThatMatchX ?? [] // SWIFT BUG? 11/6/15 - should combine these expressions
        let count = itemsThatMatch.count
        // if we have any of these, pick the first and segue to the page it is on
        if count > 0,
            let page = (itemsThatMatch.first as? InventoryItem)?.page {
            performSegueWithIdentifier("Show Ref From Inv Segue", sender: page)
        }
        // if not, segue to the info page for that item
        else {
            performSegueWithIdentifier("Show Info From Inv Segue", sender: item.referredItem)
        }
    }

    @IBAction func infoButtonPressed(sender: AnyObject) {
        performSegueWithIdentifier("Show Info From Inv Segue", sender: item.dealerItem)
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.Show Ref From Inv Segue
        if segue.identifier == "Show Info From Inv Segue" {
            if let dvc = segue.destinationViewController as? InfoItemViewController {
                dvc.item = sender as? DealerItem
            }
        }
        if segue.identifier == "Show Ref From Inv Segue" {
            if let dvc = segue.destinationViewController as? AlbumPageViewController {
                dvc.setStartPage((sender as? AlbumPage)!)
            }
        }
    }

}
