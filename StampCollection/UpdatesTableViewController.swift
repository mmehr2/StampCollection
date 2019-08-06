//
//  UpdatesTableViewController.swift
//  StampCollection
//
//  Created by Michael L Mehr on 5/23/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import UIKit

class UpdatesTableViewController: UITableViewController {
    
    var model: CollectionStore!

    var category = CollectionStore.CategoryAll
    
    fileprivate var output: UpdateComparisonTable?
    fileprivate var showSection = 0
    fileprivate let NUM_SECTIONS = 5
    fileprivate var tableID: UpdateComparisonTable.TableID {
        return UpdateComparisonTable.TableID(rawValue: showSection)!
    }
    fileprivate var showTable: [UpdateComparisonResult]? {
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
    
    @IBAction func nextButtonPressed(_ sender: AnyObject) {
        showSection += 1
        if showSection > NUM_SECTIONS {
            showSection = 0
        }
        refreshData()
    }
    
    @IBAction func commitButtonPressed(_ sender: UIBarButtonItem) {
        if let output = output , showTable != nil {
            output.commit([tableID])
            navigationController?.popViewController(animated: true)
        }
    }
    
    @IBAction func commitAllButtonPressed(_ sender: UIBarButtonItem) {
        if let output = output {
            output.commit()
            navigationController?.popViewController(animated: true)
        }
    }
    
    @IBAction func commitKeyButtonPressed(_ sender: UIBarButtonItem) {
        if showTable != nil && output != nil {
            let key = formatActionKeyForSection(tableID)
            messageBoxWithTitle("Commit Actions", andBody: key, forController: self)
        }
    }
    
    @IBAction func changeActionButtonPressed(_ sender: UIBarButtonItem) {
        // will provide cancelable action menu for user to modify selected item, then modify if asked
        let selection = tableView.indexPathForSelectedRow
        if let showTable = showTable, let output = output, let selection = selection {
            let item = showTable[selection.row]
            let idCode = item.commitActionCode
            let currentAction = output.getActionForResult(item)
            let currentActionStr = formatUpdateAction(currentAction, isLong: true, withParens: false)
            let title = "Change action for selection (currently \(currentActionStr)) on ID=\(idCode)"
            // build the menu box table one line at a time
            // the first action is always the default, and should remove any override in the output's commitItems table
            // other actions, if provided, should set the override for the selected ID to the action selected from the possibilities provided
            let actions = UpdateComparisonTable.getAllowedActionsForSection(tableID)
            let actionStrings = getFormattedActionKeysForSection(tableID)
            let defaultActionString = actionStrings.first! // guaranteed to always have a default
            // NOTE: for the following lines, we really should have a non-mutating dropFirst() that returns another array minus the first element
            var otherActionStrings = actionStrings
            otherActionStrings.remove(at: 0)
            var otherActions = actions
            otherActions.remove(at: 0)
            var menuBody: [MenuBoxEntry] = []
            var menuBody2: [MenuBoxEntry] = []
            var act: MenuBoxEntry
            act = (defaultActionString, { x in
                // default removes any override action for the given idCode in the output's commitItems table
                output.setDefaultActionForID( idCode )
                self.tableView.reloadRows(at: [selection], with: .none)
            })
            menuBody.append(act)
            act = (defaultActionString + " ALL", { x in
                // apply default action (removal) to all items in showTable
                for item in showTable {
                    let idCode = item.commitActionCode
                    output.setDefaultActionForID( idCode )
                }
                self.tableView.reloadData()
            })
            menuBody2.append(act)
            for (index, actionString) in otherActionStrings.enumerated() {
                act = (actionString, { x in
                    // other actions set selected item's action override in output's commitItems table
                    output.setAction(otherActions[index], forID: idCode)
                    self.tableView.reloadRows(at: [selection], with: .none)
                })
                menuBody.append(act)
                act = (actionString + " ALL", { x in
                    // apply given action to all items in showTable
                    for item in showTable {
                        let idCode = item.commitActionCode
                        output.setAction(otherActions[index], forID: idCode)
                    }
                    self.tableView.reloadData()
                })
                menuBody2.append(act)
            }
            menuBoxWithTitle(title, andBody: menuBody + menuBody2, forController: self)
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
                name = "\(categoryItem.name!) (#\(category))"
            }
        }
        let text = "\(count) Updates for \(name)"
        title = text
        
        // automated row height calcs: taken from http://www.raywenderlich.com/87975/dynamic-table-view-cell-height-ios-8-swift
        tableView.rowHeight = UITableView.automaticDimension
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

    override func numberOfSections(in tableView: UITableView) -> Int {
        // Return the number of sections.
        return NUM_SECTIONS
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Return the number of rows in the section.
        if let table = showTable , section == showSection {
            return table.count
        }
        return 0
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
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
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = showTable![indexPath.row]
        let action = output?.getActionForResult(item) ?? .none
        let actionString = formatUpdateAction(action)
        let actionColor = getColorForAction(action, inSection: tableID)
        switch item {
        case .addedItem(let btitem, _ ):
            let cell = tableView.dequeueReusableCell(withIdentifier: "Update Comparison Single Cell", for: indexPath) 
            cell.textLabel?.text = "\(actionString) \(btitem.descr)"
            cell.detailTextLabel?.text = formatBTDetail(btitem)
            cell.backgroundColor = actionColor
            return cell
        case .removedItem(let dlritemID):
            let cell = tableView.dequeueReusableCell(withIdentifier: "Update Comparison Single Cell", for: indexPath) 
            let dlritem = model.fetchInfoItemByID(dlritemID)!
            cell.textLabel?.text = "\(actionString) \(dlritem.descriptionX)"
            cell.detailTextLabel?.text = formatDealerDetail(dlritem)
            cell.backgroundColor = actionColor
            return cell
        case .changedItem(let dlritemID, let btitem, _, let comprec ):
            let cell = tableView.dequeueReusableCell(withIdentifier: "Update Comparison Double Cell", for: indexPath) as! UpdateTableViewDoubleCell
            let dlritem = model.fetchInfoItemByID(dlritemID)!
            cell.textLabelTop?.text = dlritem.descriptionX
            cell.detailTextLabelTop?.text = formatDealerDetail(dlritem)
            cell.textLabelBottom?.text = "\(btitem.descr)"
            cell.detailTextLabelBottom?.text = formatBTDetail(btitem)
            cell.changeLabel?.text = actionString + " " + formatComparisonRecord(comprec)
            cell.backgroundColor = actionColor
            return cell
        case .changedIDItem(let dlritemID, let btitem, _, let comprec ):
            let cell = tableView.dequeueReusableCell(withIdentifier: "Update Comparison Double Cell", for: indexPath) as! UpdateTableViewDoubleCell
            let dlritem = model.fetchInfoItemByID(dlritemID)!
            cell.textLabelTop?.text = dlritem.descriptionX
            cell.detailTextLabelTop?.text = formatDealerDetail(dlritem)
            cell.textLabelBottom?.text = "\(btitem.descr)"
            cell.detailTextLabelBottom?.text = formatBTDetail(btitem)
            cell.changeLabel?.text = actionString + " " + formatComparisonRecord(comprec)
            cell.backgroundColor = actionColor
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
