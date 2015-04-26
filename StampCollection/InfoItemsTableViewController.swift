//
//  InfoItemsTableViewController.swift
//  StampCollection
//
//  Created by Michael L Mehr on 4/24/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import UIKit

class InfoItemsTableViewController: UITableViewController {
    
    var model = CollectionStore.sharedInstance
    
    var category = CollectionStore.CategoryAll
    var categoryItem : Category!
    
    var ftype : CollectionStore.FetchType = .Info

    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
//        model.fetchType(.Info, category: category) {
//            self.refreshData()
//            self.updateUI()
//        }
        updateUI() // prelim version
    }
    
    @IBAction func refreshButtonPressed(sender: UIBarButtonItem) {
        model.fetchType(.Info, category: category, background: false) {
            self.refreshData()
            self.updateUI()
        }
    }
    
    @IBAction func picButtonPressed(sender: UIBarButtonItem) {
        
    }
    
    func refreshData() {
        tableView.reloadData()
    }
    
    func updateUI() {
        let typename = "\(ftype)"
        let num = model.info.count
        let numcats = model.categories.count
        var name = "All Categories"
        if category != CollectionStore.CategoryAll {
            //name = "Category \(categoryItem.name)"
            name = "Category \(category) of \(numcats)"
        }
        title = typename + ":" + name + " - \(num) items"
    }

    // MARK: - Table view data source
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        // Return the number of sections.
        return 1
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Return the number of rows in the section.
        return model.info.count
    }
    
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("Info Item Cell", forIndexPath: indexPath) as! UITableViewCell
        
        // Configure the cell...
        let row = indexPath.row
        let item = model.info[row]
        cell.textLabel?.text = item.descriptionX
        cell.detailTextLabel?.text = formatDealerDetail(item)
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

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using [segue destinationViewController].
        // Pass the selected object to the new view controller.
    }
    */

}
