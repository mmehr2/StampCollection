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
    private var showSection = 0
    private let NUM_SECTIONS = 5
    private var showTable: [UpdateComparisonResult]? {
        if let table = output {
            switch showSection {
            case 0: return table.addedItems
            case 1: return table.removedItems
            case 2: return table.changedIDItems
            case 3: return table.changedItems
            case 4: return table.ambiguousChangedItems
            default: break
            }
        }
        return nil
    }
    
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
        showSection = NUM_SECTIONS
        // and make sure we're current 1st thing
        updateUI()
    }
    
    @IBAction func nextButtonPressed(sender: AnyObject) {
        ++showSection
        if showSection > NUM_SECTIONS {
            showSection = 0
        }
        refreshData()
    }
    
    @IBAction func commitButtonPressed(sender: UIBarButtonItem) {
        if let showTable = showTable, output = output,
            tableID = UpdateComparisonTable.TableID(rawValue: showSection) {
                output.commit(sections: [tableID])
                navigationController?.popViewControllerAnimated(true)
        }
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
        
        // automated row height calcs: taken from http://www.raywenderlich.com/87975/dynamic-table-view-cell-height-ios-8-swift
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = showSection < 2 ? 50.0 : 160.0
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
    
    func refreshData() {
        tableView.reloadData()
        updateUI()
    }

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        // Return the number of sections.
        return NUM_SECTIONS
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Return the number of rows in the section.
        if let table = showTable where section == showSection {
            return table.count
        }
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
            case 4: return "Changed OR add/del: \(table.ambiguousChangedItems.count) Items"
            default: break
            }
        }
        return nil
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let item = showTable![indexPath.row]
        switch item {
        case .AddedItem(let btitem , let btcat ):
            let cell = tableView.dequeueReusableCellWithIdentifier("Update Comparison Single Cell", forIndexPath: indexPath) as! UITableViewCell
            cell.textLabel?.text = "\(btitem.descr)"
            cell.detailTextLabel?.text = formatBTDetail(btitem)
            return cell
        case .RemovedItem(let dlritemID):
            let cell = tableView.dequeueReusableCellWithIdentifier("Update Comparison Single Cell", forIndexPath: indexPath) as! UITableViewCell
            let dlritem = model.fetchInfoItemByID(dlritemID)!
            cell.textLabel?.text = dlritem.descriptionX
            cell.detailTextLabel?.text = formatDealerDetail(dlritem)
            return cell
        case .ChangedItem(let dlritemID, let btitem, let btcat, let comprec ):
            let cell = tableView.dequeueReusableCellWithIdentifier("Update Comparison Double Cell", forIndexPath: indexPath) as! UpdateTableViewDoubleCell
            let dlritem = model.fetchInfoItemByID(dlritemID)!
            cell.textLabelTop?.text = dlritem.descriptionX
            cell.detailTextLabelTop?.text = formatDealerDetail(dlritem)
            cell.textLabelBottom?.text = "\(btitem.descr)"
            cell.detailTextLabelBottom?.text = formatBTDetail(btitem)
            cell.changeLabel?.text = formatComparisonRecord(comprec)
            return cell
        case .ChangedIDItem(let dlritemID, let btitem, let btcat, let comprec ):
            let cell = tableView.dequeueReusableCellWithIdentifier("Update Comparison Double Cell", forIndexPath: indexPath) as! UpdateTableViewDoubleCell
            let dlritem = model.fetchInfoItemByID(dlritemID)!
            cell.textLabelTop?.text = dlritem.descriptionX
            cell.detailTextLabelTop?.text = formatDealerDetail(dlritem)
            cell.textLabelBottom?.text = "\(btitem.descr)"
            cell.detailTextLabelBottom?.text = formatBTDetail(btitem)
            return cell
        default:
            break
        }

        // Configure the cell...

        return UITableViewCell() // should never happen
    }
    

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
