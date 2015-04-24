//
//  BTItemsTableViewController.swift
//  StampCollection
//
//  Created by Michael L Mehr on 4/19/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import UIKit
import WebKit

class BTItemsTableViewController: UITableViewController, UITableViewDelegate, UITableViewDataSource {

    var categoryNumber = 0
    var storeModel = BTDealerStore.model
    var category : BTCategory!
    
    //private var items : [BTDealerItem] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        // set the category using the given category number
        category = storeModel.getCategoryByNumber(categoryNumber)
        // Set the page title to the category name
        title = "\(category.name) (\(category.items) items)"

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
    }

    func updateUI() {
        tableView.reloadData()
    }
    
    @IBAction func refreshButtonPressed(sender: UIBarButtonItem) {
        // load the BT category items page for scraping
        storeModel.loadStoreCategory(category.number, whenDone: updateUI)
    }
    
    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        // Return the number of sections.
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Return the number of rows in the section.
        return category.dataItems.count
    }

    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("BT Item Cell", forIndexPath: indexPath) as! UITableViewCell

        // Configure the cell...
        let item = category.dataItems[indexPath.row]
        cell.textLabel?.text = "\(item.descr)"
        var text = "\(item.code)"
        if item.catalog1 != "" {
            text += " [" + item.catalog1
            if item.catalog2 != "" {
                text += ", " + item.catalog2
            }
            text += "]"
        }
        cell.detailTextLabel?.text = "\(text) - \(item.status): \(item.price1) \(item.price2) \(item.price3) \(item.price4)"
        let useDisclosure = false
        cell.accessoryType = useDisclosure ? .DisclosureIndicator : .None

        return cell
    }

    /*
    // Override to support conditional editing of the table view.
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // Return NO if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            // Delete the row from the data source
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
        } else if editingStyle == .Insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(tableView: UITableView, moveRowAtIndexPath fromIndexPath: NSIndexPath, toIndexPath: NSIndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(tableView: UITableView, canMoveRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // Return NO if you do not want the item to be re-orderable.
        return true
    }
    */
    
    // MARK: - Navigation
    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using [segue destinationViewController].
        if segue.identifier == "@@@" {
            //            if let dvc = segue.destinationViewController as? RequestPredictionViewController {
            //            }
        }
    }

}
