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
    
    var ftype : CollectionStore.DataType = .Info

    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
        
        // fetch the items under consideration
        refetchData()
        //updateUI() // prelim version
    }
    
    @IBOutlet weak var picButtonItem: UIBarButtonItem!
    @IBAction func refreshButtonPressed(sender: UIBarButtonItem) {
        refetchData()
    }
    
    @IBAction func picButtonPressed(sender: UIBarButtonItem) {
        if ftype == .Info { ftype = .Inventory }
        else if ftype == .Inventory { ftype = .Info }
        refetchData()
    }
    
    func refetchData() {
        model.fetchType(ftype, category: category, background: false) {
            self.refreshData()
            self.updateUI()
        }
    }
    
    func refreshData() {
        tableView.reloadData()
    }
    
    func updateUI() {
        let typename = "\(ftype)"
        let num = ftype == .Info ? model.info.count : model.inventory.count
        //let numcats = model.categories.count // this is less than certain category #s, so best to hide it for now
        var name = "All Categories"
        if category != CollectionStore.CategoryAll {
            //name = "Category \(categoryItem.name)"
            name = "\(categoryItem.name) (#\(category))"
        }
        title = typename + ": " + name + " - \(num) items"
        // set the caption on the type(pic) button
        if ftype == .Info {
            picButtonItem.title = "Inv"
        } else {
            picButtonItem.title = "Info"
        }
    }

    // MARK: - Table view data source
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        // Return the number of sections.
        return 1
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Return the number of rows in the section.
        return ftype == .Info ? model.info.count : model.inventory.count
    }
    
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("Info Item Cell", forIndexPath: indexPath) as! UITableViewCell
        
        // Configure the cell...
        let row = indexPath.row
        var useDisclosure = false
        if ftype == .Info {
            // format a DealerItem cell
            let item = model.info[row]
            cell.textLabel?.text = item.descriptionX
            cell.detailTextLabel?.text = formatDealerDetail(item)
            useDisclosure = false
        } else {
            // format an InventoryItem cell
            let item = model.inventory[row]
            cell.textLabel?.text = formatInventoryMain(item)
            cell.detailTextLabel?.text = formatInventoryDetail(item)
            useDisclosure = false
        }
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
