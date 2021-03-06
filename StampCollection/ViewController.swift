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

// ON THE NAME OF THIS CLASS (7/14/17)
//=======
// This class should really be renamed BTCategoriesTableViewController, but Xcode doesn't seem to allow this very well.
// When I tried, I had multiple issues:
// 1. Unable to have Automatic Assistant Editor follow from the storyboard any more
// 2. Issues with automatically loading the progressView (although this may have been a timing issue pre/post viewDidLoad())
// 3. Screwy use of Source Repo configuration when I tried to back off (bad to back off without using revert!)
// #1 was probably the valid issue, not sure why making changes to the XML file didn't follow thru when Xcode was restarted
class ViewController: UITableViewController {
    // This class should really be renamed BTCategoriesTableViewController
    
    var storeModel = BTDealerStore.model
    @IBOutlet weak var progressView: UIProgressView!
    
    enum CancellableOperation {
        case None, Import, Export, ReloadAll, Refresh, Details
    }
    private var opInProgress: CancellableOperation = .None
    
    private func setupButton(_ btn: UIBarButtonItem, title: String, forOp opn: CancellableOperation, enabled: Bool) {
        if enabled {
            btn.isEnabled = true
            btn.title = title
        } else if opn == opInProgress {
            btn.isEnabled = true
            btn.title = "Cancel"
        } else {
            btn.isEnabled = false
            btn.title = title
        }
    }
    
    var uiEnabled: Bool = true {
        willSet(newValue) {
            // enable buttons when variable set to T
            importButton.isEnabled = newValue
            exportButton.isEnabled = newValue
            refreshButton.isEnabled = newValue
            reloadButton.isEnabled = newValue
            setupButton(detailsButton, title: "Details", forOp: .Details, enabled: newValue)
            // hide progress view when variable set to T
            progressView.isHidden = newValue
        }
    }

    // NOTE: the app delegate will send this message to all top-level VCs when starting up
    // we can use this to autoload the persisted data before the user actually loads this
    // NOTE: this happens before the progressView has been loaded
    @objc func setModel(_ store: CollectionStore) {
        // use persisted copy with manual updates from web
        //setSpinnerView(true)
        progressView?.isHidden = false
        opInProgress = .Import
        progressView?.observedProgress = storeModel.importData() {
            self.tableView.reloadData()
            //self.setSpinnerView(false)
            self.progressView?.isHidden = true
            self.opInProgress = .None
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // make sure the toolbar is visible
        self.navigationController?.isToolbarHidden = false

        title = "Dealer Categories"
        uiEnabled = true
    }
    
    @IBOutlet weak var refreshButton: UIBarButtonItem!
    @IBAction func refreshButtonPressed(_ sender: UIBarButtonItem) {
        // reload the BT categories page
        opInProgress = .Refresh
        uiEnabled = false
        progressView.observedProgress = storeModel.loadStore(.justCategories) {
            self.tableView.reloadData()
            self.opInProgress = .None
            self.uiEnabled = true
        }
    }
    
    @IBOutlet weak var reloadButton: UIBarButtonItem!
    @IBAction func reloadButtonPressed(_ sender: UIBarButtonItem) {
        opInProgress = .ReloadAll
        uiEnabled = false
        progressView.observedProgress = storeModel.loadStore(.populateAndWait) {
            self.tableView.reloadData()
            self.opInProgress = .None
            self.uiEnabled = true
        }
    }
    
    @IBOutlet weak var exportButton: UIBarButtonItem!
    @IBAction func exportButtonPressed(_ sender: UIBarButtonItem) {
        opInProgress = .Export
        uiEnabled = false
        progressView.observedProgress = storeModel.exportData() {
            self.opInProgress = .None
            self.uiEnabled = true
        }
    }
    
    @IBOutlet weak var importButton: UIBarButtonItem!
    @IBAction func importButtonPressed(_ sender: UIBarButtonItem) {
        opInProgress = .Import
        uiEnabled = false
        progressView.observedProgress = storeModel.importData() {
            self.tableView.reloadData()
            self.opInProgress = .None
            self.uiEnabled = true
        }
    }

    @IBOutlet weak var detailsButton: UIBarButtonItem!
    @IBAction func detailsButtonPressed(_ sender: UIBarButtonItem) {
        if uiEnabled {
            // details button pressed
            opInProgress = .Details
            uiEnabled = false
            progressView.observedProgress = storeModel.loadDataDetails() {
                self.tableView.reloadData()
                self.opInProgress = .None
                self.uiEnabled = true
            }
        } else {
            // cancel button pressed
            print("Data detail loader cancellation request sent.")
            storeModel.cancelLoadDetails()
        }
    }
    
    
    // MARK: - Table view data source
    
    func getCategoryIndexForIndexPath( _ indexPath: IndexPath ) -> Int {
        if indexPath.section == 1 {
            return -1
        } else {
            return indexPath.row
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        // Return the number of sections.
        // NOTE: add section 2 for judaicasales.com (Austria tabs)
        return 2
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Return the number of rows in the section.
        return section == 0 ? storeModel.categories.count : 1
    }
    
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "BT Category Cell", for: indexPath) 
        
        // Configure the cell...
        let catnum = getCategoryIndexForIndexPath(indexPath)
        let category = storeModel.getCategoryByIndex(catnum)
        cell.textLabel?.text = "\(category.number): \(category.name)"
        cell.detailTextLabel?.text = "(\(category.items) items)"
        cell.accessoryType = category.items != 0 ? .disclosureIndicator : .none
        
        return cell
    }
 
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
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
    
    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .none
    }
    
    
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            // then delete the row from the table view
            tableView.deleteRows(at: [indexPath], with: .fade)
            // if the last visible item was deleted, also clear the editing state of the VC
        } else if editingStyle == .insert {
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
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using [segue destinationViewController].
        if segue.identifier == "Show BT Items Segue" {
            if let dvc = segue.destination as? BTItemsTableViewController,
                let cell = sender as? UITableViewCell {
                    // get row number of cell
                    let indexPath = tableView.indexPath(for: cell)!
                    // set the destination category object accordingly
                    let catnum = getCategoryIndexForIndexPath(indexPath)
                    let category = storeModel.getCategoryByIndex(catnum)
                    dvc.categoryNumber = category.number
            }
        }
    }
}

