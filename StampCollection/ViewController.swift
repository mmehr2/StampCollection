//
//  ViewController.swift
//  StampCollection
//
//  Created by Michael L Mehr on 4/9/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import UIKit
import WebKit

// NOTE: WebKit project code from http://www.appcoda.com/webkit-framework-intro/

class ViewController: UITableViewController {
    
    var storeModel = BTDealerStore.model
    
    var spinner: UIActivityIndicatorView? {
        didSet {
            self.tableView.tableHeaderView = spinner
        }
    }
    
    func setSpinnerView(onOff: Bool = false) {
        if !onOff {
            spinner?.stopAnimating()
            spinner = nil
            return
        }
        let sp = UIActivityIndicatorView(activityIndicatorStyle: .Gray)
        sp.hidesWhenStopped = true
        sp.startAnimating()
        spinner = sp
    }

    // NOTE: the app delegate will send this message to all top-level VCs when starting up
    // we can use this to autoload the persisted data before the user actually loads this
    func setModel(store: CollectionStore) {
        // use persisted copy with manual updates from web
        setSpinnerView(true)
        storeModel.importData() {
            self.tableView.reloadData()
            self.setSpinnerView(false)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // make sure the toolbar is visible
        self.navigationController?.toolbarHidden = false

        title = "Dealer Categories"
    }
    
    @IBAction func refreshButtonPressed(sender: UIBarButtonItem) {
        // reload the BT categories page
        setSpinnerView(true)
        storeModel.loadStore(.JustCategories) {
            self.tableView.reloadData()
            self.setSpinnerView(false)
        }
    }
    
    @IBAction func reloadButtonPressed(sender: UIBarButtonItem) {
        setSpinnerView(true)
        storeModel.loadStore(.Populate) {
            self.tableView.reloadData()
            self.setSpinnerView(false)
        }
    }
    
    @IBAction func exportButtonPressed(sender: UIBarButtonItem) {
        storeModel.exportData()
    }
    
    @IBAction func importButtonPressed(sender: UIBarButtonItem) {
        setSpinnerView(true)
        storeModel.importData() {
            self.tableView.reloadData()
            self.setSpinnerView(false)
        }
    }

    // MARK: - Table view data source
    
    func getCategoryIndexForIndexPath( indexPath: NSIndexPath ) -> Int {
        if indexPath.section == 1 {
            return -1
        } else {
            return indexPath.row
        }
    }
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        // Return the number of sections.
        // NOTE: add section 2 for judaicasales.com (Austria tabs)
        return 2
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Return the number of rows in the section.
        return section == 0 ? storeModel.categories.count : 1
    }
    
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("BT Category Cell", forIndexPath: indexPath) 
        
        // Configure the cell...
        let catnum = getCategoryIndexForIndexPath(indexPath)
        let category = storeModel.getCategoryByIndex(catnum)
        cell.textLabel?.text = "\(category.number): \(category.name)"
        cell.detailTextLabel?.text = "(\(category.items) items)"
        cell.accessoryType = category.items != 0 ? .DisclosureIndicator : .None
        
        return cell
    }
 
    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return "From site www.bait-tov.com"
        }
        if section == 1 {
            return "From site www.judaicasales.com"
        }
        return nil
    }
    
    /*
    // Override to support conditional editing of the table view.
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
    // Return NO if you do not want the specified item to be editable.
    return true
    }
    */
    
    override func tableView(tableView: UITableView, editingStyleForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCellEditingStyle {
        return .None
    }
    
    
    // Override to support editing the table view.
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            // Delete the row from the data source
            // then delete the row from the table view
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
            // if the last visible item was deleted, also clear the editing state of the VC
        } else if editingStyle == .Insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
            // MLM - not supported at this time
        }
    }
    
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
        if segue.identifier == "Show BT Items Segue" {
            if let dvc = segue.destinationViewController as? BTItemsTableViewController,
                cell = sender as? UITableViewCell {
                    // get row number of cell
                    let indexPath = tableView.indexPathForCell(cell)!
                    // set the destination category object accordingly
                    let catnum = getCategoryIndexForIndexPath(indexPath)
                    let category = storeModel.getCategoryByIndex(catnum)
                    dvc.categoryNumber = category.number
            }
        }
    }
}

