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
    
    var storeModel = BTDealerStore.model
    @IBOutlet weak var progressView: UIProgressView!
    
//    var spinner: UIActivityIndicatorView? {
//        didSet {
//            self.tableView.tableHeaderView = spinner
//        }
//    }
//    
//    func setSpinnerView(_ onOff: Bool = false) {
//        if !onOff {
//            spinner?.stopAnimating()
//            spinner = nil
//            return
//        }
//        let sp = UIActivityIndicatorView(activityIndicatorStyle: .gray)
//        sp.hidesWhenStopped = true
//        sp.startAnimating()
//        spinner = sp
//    }

    // NOTE: the app delegate will send this message to all top-level VCs when starting up
    // we can use this to autoload the persisted data before the user actually loads this
    // NOTE: this happens before the progressView has been loaded
    func setModel(_ store: CollectionStore) {
        // use persisted copy with manual updates from web
        //setSpinnerView(true)
        progressView?.isHidden = false
        progressView?.observedProgress = storeModel.importData() {
            self.tableView.reloadData()
            //self.setSpinnerView(false)
            self.progressView?.isHidden = true
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // make sure the toolbar is visible
        self.navigationController?.isToolbarHidden = false

        title = "Dealer Categories"
        progressView.isHidden = false
    }
    
    @IBAction func refreshButtonPressed(_ sender: UIBarButtonItem) {
        // reload the BT categories page
        //setSpinnerView(true)
        storeModel.loadStore(.justCategories) {
            self.tableView.reloadData()
            //self.setSpinnerView(false)
        }
    }
    
    @IBAction func reloadButtonPressed(_ sender: UIBarButtonItem) {
        //setSpinnerView(true)
        storeModel.loadStore(.populate) {
            self.tableView.reloadData()
            //self.setSpinnerView(false)
        }
    }
    
    @IBAction func exportButtonPressed(_ sender: UIBarButtonItem) {
        progressView.isHidden = false
        progressView.observedProgress = storeModel.exportData() {
            self.progressView.isHidden = true
        }
    }
    
    @IBAction func importButtonPressed(_ sender: UIBarButtonItem) {
        //setSpinnerView(true)
        progressView.isHidden = false
        progressView.observedProgress = storeModel.importData() {
            self.tableView.reloadData()
            //self.setSpinnerView(false)
            self.progressView.isHidden = true
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
    
    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle {
        return .none
    }
    
    
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
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

