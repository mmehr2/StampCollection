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
    var itype : WantHaveType = .All
    var startYear = 0
    var endYear = 0
    var keywords : [String] = []
    var useAllKeywords = false

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

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
//        refreshData()
//        updateUI()
    }
    
    @IBAction func refreshButtonPressed(sender: UIBarButtonItem) {
        refetchData()
    }
    
    private func getSearchingArray() -> [SearchType] {
        var output : [SearchType] = []
        var names: [String] = []
        if ftype == .Inventory && itype != .All {
            let stype = SearchType.WantHave(itype)
            output.append(stype)
            names.append("\(stype)")
        }
        if startYear != 0 && endYear >= startYear {
            let stype = SearchType.YearInRange(startYear...endYear)
            output.append(stype)
            names.append("\(stype)")
        }
        if keywords.count > 0 {
            let stype = useAllKeywords ? SearchType.KeyWordListAll(keywords) : SearchType.KeyWordListAny(keywords)
            output.append(stype)
            names.append("\(stype)")
        }
        let cname = categoryItem?.name ?? "ALL"
        var caption = "Showing \(cname) (#\(category)) \(ftype) Items"
        if names.count > 0 {
            caption += " filtered by " + "; ".join(names)
        }
        println(caption)
        return output
    }
    
    private func getNextInvState() -> (CollectionStore.DataType, WantHaveType) {
        switch (ftype, itype) {
        case (.Info, .All): return (.Inventory, .All)
        case (.Inventory, .All): return (.Inventory, .Haves)
        case (.Inventory, .Haves): return (.Inventory, .Wants)
        case (.Inventory, .Wants): return (.Info, .All)
        default: return (.Info, .All) // should never happen tho
        }
    }
    
    @IBOutlet weak var infoButtonItem: UIBarButtonItem!
    @IBAction func infoButtonPressed(sender: UIBarButtonItem) {
        (ftype, itype) = getNextInvState()
        refetchData()
    }
    
    @IBAction func picButtonPressed(sender: UIBarButtonItem) {
        // TBD: download and show the image identified by the selection's pictid property
        // URL is http://www.bait-tov.com/store/products/XXX.jpg where XXX is the pictid
        // NOTE: should probably be a part of a detail controller instead
        //println("Pic button pressed.")
        // I AM NOW COMMANDEERING THIS TO DO COMPARISON UPDATES!
//        if category == CollectionStore.CategoryAll {
//            println("Cannot compare all items at once; only do this for individual categories (for now)")
//        } else {
//            processComparison(model.info)
//        }
    }
    
    @IBAction func searchButtonPressed(sender: AnyObject) {
        // show an action sheet to choose Keyword or YearRange filtering
        // other action types may be added in the future depending on category
        var ac = UIAlertController(title: "Choose Search Method", message: nil, preferredStyle: .ActionSheet)
        var act = UIAlertAction(title: "By Keywords", style: .Default) { x in
            // action here
            let kwc = UIQueryAlert(type: .Keyword) { srchType in
                // put the related data into the master VC's variables
                switch srchType {
                case .KeyWordListAll(let words):
                    self.keywords = words
                    self.useAllKeywords = true
                    self.refetchData()
                    break
                case .KeyWordListAny(let words):
                    self.keywords = words
                    self.useAllKeywords = false
                    self.refetchData()
                    break
                default:
                    break
                }
            }
            kwc.RunWithViewController(self)
        }
        ac.addAction(act)
        act = UIAlertAction(title: "By Year Range", style: .Default) { x in
            // action here
            let kwc = UIQueryAlert(type: .YearRange) { srchType in
                // put the related data into the master VC's variables
                switch srchType {
                case .YearInRange(let range):
                    self.startYear = range.start
                    self.endYear = range.end
                    self.refetchData()
                    break
                default:
                    break
                }
            }
            kwc.RunWithViewController(self)
        }
        ac.addAction(act)
        act = UIAlertAction(title: "Cancel", style: .Cancel) { x in
            // no action here
        }
        ac.addAction(act)
        presentViewController(ac, animated: true, completion: nil)
    }

    private func addSortAction( type: SortType, forDataType dataType: CollectionStore.DataType, toController ac: UIAlertController ) {
        let typeName = ftype == .Info ? "INFO" : "INVENTORY"
        let title = ""
        var act = UIAlertAction(title: "Sort by \(type)", style: .Default) { x in
            // resort current info data by id code (depends on category being shown)
            println("Sorting \(typeName) by \(type)")
            if dataType == .Info {
                let temp = sortCollection(self.model.info, byType: type)
                self.model.info = temp
            } else {
                let temp = sortCollectionEx(self.model.inventory, byType: type)
                self.model.inventory = temp
            }
            self.refreshData()
            self.updateUI()
            println("Completed sorting \(typeName) by \(type)")
        }
        ac.addAction(act)
    }
    
    @IBAction func sortButtonPressed(sender: AnyObject) {
        // implementing sorting functionality
        var ac = UIAlertController(title: "Choose Info Sort Method", message: nil, preferredStyle: .Alert)
        var act = UIAlertAction(title: "Unsorted", style: .Default) { x in
            // TBD resort current info data by exOrder (or category+exOrder if showing ALL)
            println("Reverting to Unsorted data")
            self.refetchData()
//            println("First of \(self.model.info.count): \(self.model.info.first?.normalizedCode)")
//            println("Last: \(self.model.info.last?.normalizedCode)")
        }
        ac.addAction(act)
        addSortAction(.ByCode(true), forDataType: ftype, toController: ac)
        addSortAction(.ByCode(false), forDataType: ftype, toController: ac)
        addSortAction(.ByImport(true), forDataType: ftype, toController: ac)
        addSortAction(.ByImport(false), forDataType: ftype, toController: ac)
        addSortAction(.ByDate(true), forDataType: ftype, toController: ac)
        addSortAction(.ByDate(false), forDataType: ftype, toController: ac)
        if ftype == .Inventory {
            addSortAction(.ByAlbum(true), forDataType: ftype, toController: ac)
            addSortAction(.ByAlbum(false), forDataType: ftype, toController: ac)
        }
        act = UIAlertAction(title: "Cancel", style: .Cancel) { x in
            // no action here
        }
        ac.addAction(act)
        presentViewController(ac, animated: true, completion: nil)
    }
    
    func refetchData(modifier: (() -> Void)? = nil) {
        model.fetchType(ftype, category: category, searching: getSearchingArray()) {
            if let modifier = modifier {
                modifier()
            }
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
        var name = "All Categories"
        if category != CollectionStore.CategoryAll {
            name = "\(categoryItem.name) (#\(category))"
        }
        var itemsname = "items"
        switch (ftype, itype) {
        case (.Info, _): itemsname = "items"
        case (.Inventory, .All): itemsname = "items"
        default: itemsname = "\(itype)";
        }
        title = typename + ": " + name + " - \(num) \(itemsname)"
        // set the caption on the type(pic) button according to NEXT state of its variables
        let (nftype, nitype) = getNextInvState()
        var exwh = ""
        switch (nftype, nitype) {
        case (.Info, _): exwh = "Info"
        case (.Inventory, .All): exwh = "Inv"
        case (.Inventory, .Haves),
            (.Inventory, .Wants): exwh = "Inv" + "\(nitype)"[0]
        default: break
        }
        infoButtonItem.title = "To:" + exwh
        
        // automated row height calcs: taken from http://www.raywenderlich.com/87975/dynamic-table-view-cell-height-ios-8-swift
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 80.0
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
        //let cell = tableView.dequeueReusableCellWithIdentifier("Info Item Cell", forIndexPath: indexPath) as! UITableViewCell
        let cell = tableView.dequeueReusableCellWithIdentifier("Info Item Cell") as! ItemTableViewCell
        
        // Configure the cell...
        let row = indexPath.row
        var useDisclosure = false
        if ftype == .Info {
            // format a DealerItem cell
            let item = model.info[row]
            cell.title?.text = item.descriptionX
            cell.subtitle?.text = formatDealerDetail(item)
            useDisclosure = true
            //println("NormID = \(item.normalizedCode) (len=\(count(item.normalizedCode))) for ID = \(item.id)") // DEBUG
            //println("NormDate = \(item.normalizedDate) (len=\(count(item.normalizedDate))) for Dscr = \(makeStringFit(item.descriptionX, 30))") // DEBUG
        } else {
            // format an InventoryItem cell
            let item = model.inventory[row]
            cell.title?.text = formatInventoryMain(item)
            cell.subtitle?.text = formatInventoryDetail(item)
            useDisclosure = false
            //println("NormID = \(item.normalizedCode) (len=\(count(item.normalizedCode))) for ID = \(item.baseItem)") // DEBUG
            //println("NormDate = \(item.normalizedDate) (len=\(count(item.normalizedDate))) for Dscr = \(makeStringFit(item.dealerItem.descriptionX, 30))") // DEBUG
        }
        cell.accessoryType = useDisclosure ? .DetailButton : .None
        
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
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using [segue destinationViewController].
        // Pass the selected object to the new view controller.
        if segue.identifier == "Show Updates Segue" {
            if let dvc = segue.destinationViewController as? UpdatesTableViewController {
                dvc.category = category
            }
        }
        if segue.identifier == "Show Info Item Segue" {
            if let dvc = segue.destinationViewController as? InfoItemViewController,
                cell = sender as? UITableViewCell where ftype == .Info  {
                    // Info only (for now)
                    let indexPath = tableView.indexPathForCell(cell)!
                    let row = indexPath.row
                    dvc.item = model.info[row]
            }
        }
    }
    

}
