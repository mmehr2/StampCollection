//
//  UpdatesTableViewController.swift
//  StampCollection
//
//  Created by Michael L Mehr on 5/23/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import UIKit

class UpdatesTableViewController: UITableViewController {
    
    var model = CollectionStore.sharedInstance

    var category = CollectionStore.CategoryAll
    
    private var output: UpdateComparisonTable?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
        
        // on loading,
        // (re)run the update analysis for this category or group
        // then reload the data display
        refetchData()
        // and make sure we're current 1st thing
        updateUI()
    }
    
    func updateUI() {
        var count = 0
        if let output = output {
            count = output.count
            printSummaryStats(output)
        }
        var name = "All Categories"
        if let categoryItem = model.fetchCategory(category) {
            if category != CollectionStore.CategoryAll {
                name = "\(categoryItem.name) (#\(category))"
            }
        }
        let text = "\(count) Updates for \(name)"
        title = text
    }
    
    func refetchData() {
        // (re)run the update analysis for this category or group
        // then reload the data display
        model.updateCategory(category) { table in
            self.output = table
            self.tableView.reloadData()
            self.updateUI()
        }
    }

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        // Return the number of sections.
        return 4
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Return the number of rows in the section.
//        if let table = output {
//            switch section {
//            case 0: return table.addedItems.count
//            case 1: return table.removedItems.count
//            case 2: return table.changedIDItems.count
//            case 3: return table.changedItems.count
//            default: break
//            }
//        }
        return 0
    }
    
    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        // Return the number of rows in the section.
        if let table = output {
            switch section {
            case 0: return "Added \(table.addedItems.count) Items"
            case 1: return "Removed \(table.removedItems.count) Items"
            case 2: return "Changed \(table.changedIDItems.count) ID Items"
            case 3: return "Changed \(table.changedItems.count) Items"
            default: break
            }
        }
        return nil
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("Update Comparison Cell", forIndexPath: indexPath) as! UITableViewCell

        // Configure the cell...

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
