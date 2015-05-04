//
//  InfoCategoriesTableViewController.swift
//  StampCollection
//
//  Created by Michael L Mehr on 4/24/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import UIKit

class InfoCategoriesTableViewController: UITableViewController {
    
    lazy var csvFileImporter = ImportExport()
    
    var model = CollectionStore.sharedInstance

    @IBAction func doImportAction(sender: UIBarButtonItem) {
        // wipe the slate
        // BEWARE - DO NOT USE WITH CORE DATA! See documentation for this function
        model.removeAllItemsInStore()
        updateUI()
        // load the data from CSV files
        let sourceType = ImportExport.Source.Bundle // TBD: make this a setting, once we can do AirDrop and EmailAttachment
        csvFileImporter.importData(sourceType) {
            // when done, load the data, then update the UI
            self.model.fetchType(.Categories) {
                self.updateUI()
            }
        }
    }
    
    @IBAction func refreshButtonPressed(sender: UIBarButtonItem) {
        let catcount = model.categories.count
        model.fetchType(.Categories) {
            self.updateUI()
        }
    }
    
    @IBAction func doExportAction(sender: UIBarButtonItem) {
        // TBD: select type of export (email, airdrop, ??)
        let exporter = EmailAttachmentExporter(forController: self) { error in
            messageBoxWithTitle("Email Send Error", andBody: error.localizedDescription, forController: self)
        }
        exporter.sendFiles()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // make sure the toolbar is visible
        self.navigationController?.toolbarHidden = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
        
        // load the data from CSV files
//        let sourceType = ImportExport.Source.Bundle // TBD: make this a setting, once we can do AirDrop and EmailAttachment
//        csvFileImporter.importData(sourceType) {
//            // when done, write it back to other CSV files
//            self.csvFileImporter.exportData(true) {
//                println("Completed write test. Time to update the UI!")
//            }
//        }
        title = "Collection Categories"
        self.updateUI()
    }

    func updateUI() {
        tableView.reloadData()
    }
    
    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        // Return the number of sections.
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Return the number of rows in the section.
        return model.categories.count + 1
    }

    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("Info Category Cell", forIndexPath: indexPath) as! UITableViewCell

        // Configure the cell...
        let row = indexPath.row
        if row == model.categories.count {
            // special handling for the AllData row
            cell.textLabel?.text = "All Categories"
            let categoryItems = model.getInfoCategoryCount(CollectionStore.CategoryAll)
            cell.detailTextLabel?.text = "(\(categoryItems) items)"
            cell.accessoryType = .None
        } else {
            let category = model.categories[row]
            let categoryItems = model.getInfoCategoryCount(category.number)
            cell.textLabel?.text = category.name
            cell.detailTextLabel?.text = "(\(categoryItems) items)"
            let allowDisc = (category.code[0] != "*")
            cell.accessoryType = allowDisc ? .DisclosureIndicator : .None
        }

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

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using [segue destinationViewController].
        if segue.identifier == "Show Info Items Segue" {
            if let dvc = segue.destinationViewController as? InfoItemsTableViewController,
                cell = sender as? UITableViewCell {
                    // get row number of cell
                    let indexPath = tableView.indexPathForCell(cell)!
                    let row = indexPath.row
                    if row == model.categories.count {
                        // special handling for the AllData row
                        dvc.category = CollectionStore.CategoryAll
                    } else {
                        let category = model.categories[row]
                        // set the destination category object accordingly
                        let catnum = (category.number)
                        dvc.category = catnum
                        dvc.categoryItem = model.fetchCategory(catnum)
                    }
            }
        }
    }

}
