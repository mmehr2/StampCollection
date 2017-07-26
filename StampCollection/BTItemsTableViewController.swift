//
//  BTItemsTableViewController.swift
//  StampCollection
//
//  Created by Michael L Mehr on 4/19/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import UIKit
import WebKit

class BTItemsTableViewController: UITableViewController {

    var categoryNumber = 0
    var storeModel = BTDealerStore.model
    var category : BTCategory!
    
    @IBOutlet weak var progressView: UIProgressView!
    //private var items : [BTDealerItem] = []
    
    var uiEnabled: Bool = true {
        willSet(newValue) {
            // enable buttons when variable set to T
            notesButton.isEnabled = newValue
            refreshButton.isEnabled = newValue
            // hide progress view when variable set to T
            progressView.isHidden = newValue
        }
    }

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
        uiEnabled = true
    }

    func updateUI() {
        uiEnabled = true
        tableView.reloadData()
    }
    
    @IBOutlet weak var notesButton: UIBarButtonItem!
    @IBAction func notesButtonPressed(_ sender: UIBarButtonItem) {
        messageBoxWithTitle("Notes", andBody: category.notes, forController: self)
    }
    
    @IBOutlet weak var refreshButton: UIBarButtonItem!
    @IBAction func refreshButtonPressed(_ sender: UIBarButtonItem) {
        // load the BT category items page for scraping
        uiEnabled = false
        progressView.observedProgress = storeModel.loadStoreCategory(category.number, whenDone: updateUI)
    }
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // Return the number of sections.
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Return the number of rows in the section.
        return category.dataItemCount
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "BT Item Cell", for: indexPath) 

        // Configure the cell...
        let item = category.getAllDataItems()[indexPath.row]
        cell.textLabel?.text = "\(item.descr)"
        cell.detailTextLabel?.text = formatBTDetail(item)
//        let useDisclosure = true
//        cell.accessoryType = useDisclosure ? .DetailDisclosureButton : .None

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
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using [segue destinationViewController].
        if segue.identifier == "Show Dealer Item Segue" {
            if let dvc = segue.destination as? InfoItemViewController,
                let cell = sender as? UITableViewCell  {
                    // create an info item for the dealer item selected, if possible
                    let indexPath = tableView.indexPath(for: cell)!
                    let row = indexPath.row
                    let btitem = category.getAllDataItems()[row]
                    dvc.btitem = btitem
                    dvc.btcat = category
            }
        }
    }

}
