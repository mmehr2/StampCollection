//
//  InfoItemsTableViewController.swift
//  StampCollection
//
//  Created by Michael L Mehr on 4/24/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import UIKit

class InfoItemsTableViewController: UITableViewController {
    
    var model: CollectionStore!
    
    var category = CollectionStore.CategoryAll
    var categoryItem : Category!
    
    var ftype : CollectionStore.DataType = .info
    var itype : WantHaveType = .all
    var startYear = 0
    var endYear = 0
    var keywords : [String] = []
    var useAllKeywords = false
    var IDPattern = ""

    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
        
        // fetch the items under consideration
        refetchData()
        updateUI() // prelim version
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
//        refreshData()
//        updateUI()
    }
    
    @IBAction func refreshButtonPressed(_ sender: UIBarButtonItem) {
        refetchData()
    }
    
    fileprivate func getSearchingArray() -> [SearchType] {
        var output : [SearchType] = []
        var names: [String] = []
        if ftype == .inventory && itype != .all {
            let stype = SearchType.wantHave(itype)
            output.append(stype)
            names.append("\(stype)")
        }
        if startYear != 0 && endYear >= startYear {
            let stype = SearchType.yearInRange(startYear...endYear)
            output.append(stype)
            names.append("\(stype)")
        }
        if keywords.count > 0 {
            let stype = useAllKeywords ? SearchType.keyWordListAll(keywords) : SearchType.keyWordListAny(keywords)
            output.append(stype)
            names.append("\(stype)")
        }
        if !IDPattern.isEmpty {
            let stype = SearchType.subCategory(IDPattern)
            output.append(stype)
            names.append("\(stype)")
        }
        let cname = categoryItem?.name ?? "ALL"
        var caption = "Showing \(cname) (#\(category)) \(ftype) Items"
        if names.count > 0 {
            caption += " filtered by " + names.joined(separator: "; ")
        }
        print(caption)
        return output
    }
    
    fileprivate func getNextInvState() -> (CollectionStore.DataType, WantHaveType) {
        switch (ftype, itype) {
        case (.info, .all): return (.inventory, .all)
        case (.inventory, .all): return (.inventory, .haves)
        case (.inventory, .haves): return (.inventory, .wants)
        case (.inventory, .wants): return (.info, .all)
        default: return (.info, .all) // should never happen tho
        }
    }
    
    @IBOutlet weak var infoButtonItem: UIBarButtonItem!
    @IBAction func infoButtonPressed(_ sender: UIBarButtonItem) {
        (ftype, itype) = getNextInvState()
        refetchData()
    }
    
    @IBAction func picButtonPressed(_ sender: UIBarButtonItem) {
        // TBD: download and show the image identified by the selection's pictid property
        // URL is http://www.bait-tov.com/store/products/XXX.jpg where XXX is the pictid
        // NOTE: should probably be a part of the info item view controller instead
        //println("Pic button pressed.")
    }

    fileprivate func getRelatedItemsFromMain( _ item: InventoryItem ) -> [DealerItem] {
        let id = item.dealerItem.id
        let splitID = IDParser(code: id!, forCat: item.catgDisplayNum)
        let mainID = splitID.main
        // create a subcat pattern for any ID with this base ("base@")
        let subcat = SearchType.subCategory(mainID + "@")
        // fetch the IDs in this list but without any .retired items
        let items0 = model.fetchInfoInCategory(splitID.catnum, withSearching: [subcat], andSorting: SortType.byCode(true))
        let items = items0.filter{ !$0.retired }
        //            let ids = items.map{ $0.id + " - " + $0.descriptionX }
        //            let idstr = "\n".join(ids)
        //            println("Searching for \(subcat): found \n\(idstr)")
        return items
    }
    
    fileprivate func createBaseAssignmentMenu( _ items: [DealerItem], forItem invItem: InventoryItem, withCompletion completion: (() -> Void)? = nil ) -> [MenuBoxEntry] {
        var menuItems : [MenuBoxEntry] = []
        for item in items {
            let apos = item.descriptionX.index(item.descriptionX.startIndex, offsetBy: 16)
            let title = item.id + ":" + item.descriptionX[apos...]
            menuItems.append( (title, { x in
                print("Assigning new base item=\(item.id): \(item.descriptionX) \nto INV\(invItem.baseItem): \(invItem.desc).")
                invItem.updateBaseItem(item)
                if let completion = completion {
                    completion()
                }
            }) )
        }
        return menuItems
    }
    
    @IBOutlet weak var moreButton: UIBarButtonItem!
    @IBAction func moreButtonPressed(_ sender: UIBarButtonItem) {
        // run an alert controller to choose from a menu of less-used functions
        guard let path = self.tableView.indexPathForSelectedRow else { return }
        let row = path.row
        if ftype == .info {
            let infoitem = self.model.info[row]
            
            let masterMenuItems : [MenuBoxEntry] = [
                ("Remove Info Item", { x in
                    // first selection: run the box to delete the item if possible
                    let delMenuItems : [MenuBoxEntry] = [
                        ("!Delete Item", { x in
                            let _ = self.model.removeInfoItem(infoitem, commit: true)
                            self.refetchData()
                        }),
                        ]
                    menuBoxWithTitle("Remove selected item from database", andBody: delMenuItems, forController: self)
                }),
                ("Modify Add Action", { x in
                    // second selection: run a box to select options on the inventory builder
                    let ibMenuItems : [MenuBoxEntry] = [
                        ("Disable FDC Folder", {x in
                            // code that will disable the invBuilder's folder additions
                            if let ivb = self.model.invBuilder {
                                ivb.allowRelatedFolder = false
                            }
                        }),
                        ("Split Set in Parts", {x in
                            // code that will setup Partial Set description in invBuilder
                            let kwc = UIQueryAlert(type: .invAskPartialSetValues) { srchType in
                                // put the related data into the master VC's variables
                                switch srchType {
                                case .keyWordListAny(let values):
                                    if let ivb = self.model.invBuilder {
                                        ivb.setPartialSetInfo(values)
                                    }
                                    break
                                default:
                                    break
                                }
                            }
                            kwc.RunWithViewController(self)
                        }),
                        ]
                    menuBoxWithTitle("Modify Add Action", andBody: ibMenuItems, forController: self)
                }),
                ]
            menuBoxWithTitle("Info Tools", andBody: masterMenuItems, forController: self)
           
        }
        if ftype == .inventory {
            let invitem = self.model.inventory[row]
            let menuItems : [MenuBoxEntry] = [
                ("Reassign Base Item", { x in
                    // get base ID number minus suffix for inv item selected
                    let items = self.getRelatedItemsFromMain(invitem)
                    // create a menu controller to hold the list of IDs
                    let menu = self.createBaseAssignmentMenu(items, forItem: invitem) {
                        let _ = self.model.saveMainContext()
                        self.tableView.reloadRows(at: [path], with: .automatic)
                    }
                    //  (action is to call the function that would assign the base item to this ID)
                    menuBoxWithTitle("Reassign Base to \( (invitem.desc ?? "?desc?") )", andBody: menu, forController: self)
                }),
            ]
            menuBoxWithTitle("Choose action for selected item", andBody: menuItems, forController: self)
        }
    }
    
    @IBAction func searchButtonPressed(_ sender: AnyObject) {
        // show an action sheet to choose Keyword or YearRange filtering
        // other action types may be added in the future depending on category
        let ac = UIAlertController(title: "Choose Search Method", message: nil, preferredStyle: .actionSheet)
        var act = UIAlertAction(title: "By Keywords", style: .default) { x in
            // action here
            let kwc = UIQueryAlert(type: .keyword) { srchType in
                // put the related data into the master VC's variables
                switch srchType {
                case .keyWordListAll(let words):
                    self.keywords = words
                    self.useAllKeywords = true
                    self.refetchData()
                    break
                case .keyWordListAny(let words):
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
        act = UIAlertAction(title: "By ID SubCategory", style: .default) { x in
            // action here
            let kwc = UIQueryAlert(type: .subCategory) { srchType in
                // put the related data into the master VC's variables
                switch srchType {
                case .subCategory(let pattern):
                    self.IDPattern = pattern
                    self.refetchData()
                    break
                default:
                    break
                }
            }
            kwc.RunWithViewController(self)
        }
        ac.addAction(act)
        act = UIAlertAction(title: "By Year Range", style: .default) { x in
            // action here
            let kwc = UIQueryAlert(type: .yearRange) { srchType in
                // put the related data into the master VC's variables
                switch srchType {
                case .yearInRange(let range):
                    self.startYear = range.lowerBound
                    self.endYear = range.upperBound
                    self.refetchData()
                    break
                default:
                    break
                }
            }
            kwc.RunWithViewController(self)
        }
        ac.addAction(act)
        act = UIAlertAction(title: "Cancel", style: .cancel) { x in
            // no action here
        }
        ac.addAction(act)
        present(ac, animated: true, completion: nil)
    }

    fileprivate func addSortAction( _ type: SortType, forDataType dataType: CollectionStore.DataType, toController ac: UIAlertController ) {
        let typeName = ftype == .info ? "INFO" : "INVENTORY"
        //let title = ""
        let act = UIAlertAction(title: "Sort by \(type)", style: .default) { x in
            // resort current info data by id code (depends on category being shown)
            print("Sorting \(typeName) by \(type)")
            if dataType == .info {
                let temp = sortCollection(self.model.info, byType: type)
                self.model.info = temp
            } else {
                let temp = sortCollectionEx(self.model.inventory, byType: type)
                self.model.inventory = temp
            }
            self.refreshData()
            self.updateUI()
            print("Completed sorting \(typeName) by \(type)")
        }
        ac.addAction(act)
    }
    
    @IBAction func sortButtonPressed(_ sender: AnyObject) {
        // implementing sorting functionality
        let ac = UIAlertController(title: "Choose Info Sort Method", message: nil, preferredStyle: .alert)
        var act = UIAlertAction(title: "Unsorted", style: .default) { x in
            // TBD resort current info data by exOrder (or category+exOrder if showing ALL)
            print("Reverting to Unsorted data")
            self.refetchData()
//            println("First of \(self.model.info.count): \(self.model.info.first?.normalizedCode)")
//            println("Last: \(self.model.info.last?.normalizedCode)")
        }
        ac.addAction(act)
        addSortAction(.byCode(true), forDataType: ftype, toController: ac)
        addSortAction(.byCode(false), forDataType: ftype, toController: ac)
        addSortAction(.byImport(true), forDataType: ftype, toController: ac)
        addSortAction(.byImport(false), forDataType: ftype, toController: ac)
        addSortAction(.byDate(true), forDataType: ftype, toController: ac)
        addSortAction(.byDate(false), forDataType: ftype, toController: ac)
        if ftype == .inventory {
            addSortAction(.byAlbum(true), forDataType: ftype, toController: ac)
            addSortAction(.byAlbum(false), forDataType: ftype, toController: ac)
        }
        act = UIAlertAction(title: "Cancel", style: .cancel) { x in
            // no action here
        }
        ac.addAction(act)
        present(ac, animated: true, completion: nil)
    }
    
    func refetchData(_ modifier: (() -> Void)? = nil) {
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
        let num = ftype == .info ? model.info.count : model.inventory.count
        var name = "All Categories"
        if category != CollectionStore.CategoryAll {
            let catname = categoryItem.name ?? "None"
            name = "\(catname) (#\(category))"
        }
        var itemsname = "items"
        switch (ftype, itype) {
        case (.info, _): itemsname = "items"
        case (.inventory, .all): itemsname = "items"
        default: itemsname = "\(itype)";
        }
        title = typename + ": " + name + " - \(num) \(itemsname)"
        // set the caption on the type(pic) button according to NEXT state of its variables
        let (nftype, nitype) = getNextInvState()
        var exwh = ""
        switch (nftype, nitype) {
        case (.info, _): exwh = "Info"
        case (.inventory, .all): exwh = "Inv"
        case (.inventory, .haves),
            (.inventory, .wants): exwh = "Inv" + String("\(nitype)".first!)
        default: break
        }
        infoButtonItem.title = "To:" + exwh
        
        // enable the More button according to whether an item is selected
        moreButton.isEnabled = tableView.indexPathForSelectedRow != nil
        
        // automated row height calcs: taken from http://www.raywenderlich.com/87975/dynamic-table-view-cell-height-ios-8-swift
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 80.0
    }

    // MARK: - Table view delegate
    override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        updateUI()
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        updateUI()
    }
    
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return ftype == .info
    }
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        // Return the number of sections.
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Return the number of rows in the section.
        return ftype == .info ? model.info.count : model.inventory.count
    }
    
    fileprivate func getRowAction(forItem item:DealerItem, wanted: Bool, withPriceType pusage: PriceUsage, inColor color: UIColor) -> UITableViewRowAction {
        let cat = item.category!
        let wantedName = wanted ? "Want" : "Have"
        let wantedTitle, rowTitle: String
        if pusage.numprices == 1 {
            wantedTitle = wantedName.lowercased()
            rowTitle = wantedName;
        } else {
            wantedTitle = "\(wantedName.lowercased()) - \(pusage.ptype.pname)"
            rowTitle = "\(wantedName)\n(\(pusage.ptype.pname))"
        }
        print("Added action for \(wantedName)(\(pusage.ptype.pname))")
        let retval = UITableViewRowAction(style: .normal, title: "\(rowTitle)") { action, index in
            // add selected item to Inventory as a HAVE or WANT
            print("Adding to INV(\(wantedTitle)) in Category \(cat.name!) (\(item.catgDisplayNum)): \(item.id!) \(item.descriptionX!)")
            let bldr = InventoryBuilder(for: item, withPriceType: pusage.ptype.ptype, want: wanted)
            self.model.invBuilder = bldr
            print("\(bldr)")
            self.tableView.setEditing(false, animated: true)
        }
        retval.backgroundColor = color
        return retval
    }
    
    fileprivate func addInventoryAction(forItem item:DealerItem, wanted: Bool, withPriceType pusage: PriceUsage, toController ac: UIAlertController ) {
        let cat = item.category!
        let wantedName = wanted ? "Want" : "Have"
        let wantedTitle: String
        if pusage.numprices == 1 {
            wantedTitle = wantedName.lowercased()
        } else {
            wantedTitle = "\(wantedName.lowercased()) - \(pusage.ptype.pname)"
        }
        print("Added action for \(wantedName)(\(pusage.ptype.pname))")
        let act = UIAlertAction(title: "Add to INV(\(wantedTitle))", style: .default) { x in /// 1
            // add selected item to Inventory as a HAVE or WANT
            print("Adding to INV(\(wantedTitle)) in Category \(cat.name!) (\(item.catgDisplayNum)): \(item.id!) \(item.descriptionX!)")
            let bldr = InventoryBuilder(for: item, withPriceType: pusage.ptype.ptype, want: wanted)
            self.model.invBuilder = bldr
            print("\(bldr)")
            self.tableView.setEditing(false, animated: true)
        }
        ac.addAction(act) /// 2
    }
  
    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        
        var retval:[UITableViewRowAction]?
        
        if ftype == .info {
            // actions for Info items
            let item = self.model.info[indexPath.row]
            let cat = item.category!
            let hasFDC = cat.fdcPriceType != nil
            let hasUsed = cat.usedPriceType != nil
            let numPriceTypes = cat.numPriceTypes
            let hasLessChoices = numPriceTypes <= 2
            let sayUsed = hasUsed && hasLessChoices
            let pumint = PriceUsage(.mint, num: numPriceTypes)
            let pufdc = PriceUsage(.FDC(false), num: numPriceTypes)
            let puused = PriceUsage(.used, num: numPriceTypes)
            let pumnotab = PriceUsage(.mintNoTab, num: numPriceTypes)
            let pufu = sayUsed ? puused : pufdc
            
            let have = getRowAction(forItem: item, wanted: false, withPriceType: pumint, inColor: .blue)
            retval = [have]
            
            if numPriceTypes == 1 {
                let want = getRowAction(forItem: item, wanted: true, withPriceType: pumint, inColor: .orange)
                retval! += [want]
            } else {
                if hasFDC || sayUsed {
                    let haveFDC = getRowAction(forItem: item, wanted: false, withPriceType: pufu, inColor: .orange)
                    retval! += [haveFDC]
                }
                
                let more = UITableViewRowAction(style: .normal, title: "More") { action, index in
                    // run More Actions table selection action controller
                    print("Invoking More Actions for Category \(cat.name!) (\(item.catgDisplayNum)): \(item.id!) \(item.descriptionX!)")
                    let ac = UIAlertController(title: "Choose Inventory Action", message: nil, preferredStyle: .alert)
                    // create an action controller with N items for extra haves/wants (N<=6 depending on category.prices string)
                    if hasLessChoices {
                        //print("Added action for Want(\(pumint.ptype.pname))")
                        self.addInventoryAction(forItem: item, wanted: true, withPriceType: pumint, toController: ac)
                        //print("Added action for Want(\(pufu.ptype.pname))")
                        self.addInventoryAction(forItem: item, wanted: true, withPriceType: pufu, toController: ac)
                    } else {
                        //print("Added action for Have(\(puused.ptype.pname))")
                        self.addInventoryAction(forItem: item, wanted: false, withPriceType: puused, toController: ac)
                        //print("Added action for Have(\(pumnotab.ptype.pname))")
                        self.addInventoryAction(forItem: item, wanted: false, withPriceType: pumnotab, toController: ac)
                        //print("Added action for Want(\(pumint.ptype.pname))")
                        self.addInventoryAction(forItem: item, wanted: true, withPriceType: pumint, toController: ac)
                        //print("Added action for Want(\(pufdc.ptype.pname))")
                        self.addInventoryAction(forItem: item, wanted: true, withPriceType: pufdc, toController: ac)
                        //print("Added action for Want(\(puused.ptype.pname))")
                        self.addInventoryAction(forItem: item, wanted: true, withPriceType: puused, toController: ac)
                        //print("Added action for Want(\(pumnotab.ptype.pname))")
                        self.addInventoryAction(forItem: item, wanted: true, withPriceType: pumnotab, toController: ac)
                    }
                    // add a cancel (None) operation and present the controller
                    let act = UIAlertAction(title: "Cancel", style: .cancel) { x in
                        // no action here
                    }
                    ac.addAction(act)
                    self.present(ac, animated: true, completion: nil)
                }
                more.backgroundColor = .lightGray
                retval! += [more]
            }
        } else {
            // actions for Inventory items TBD
            retval = nil
        }
        
        return retval
    }
    
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        //let cell = tableView.dequeueReusableCellWithIdentifier("Info Item Cell", forIndexPath: indexPath) as! UITableViewCell
        let cell = tableView.dequeueReusableCell(withIdentifier: "Info Item Cell") as! ItemTableViewCell
        
        // Configure the cell...
        let row = indexPath.row
        var useDisclosure = false
        if ftype == .info {
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
        cell.accessoryType = useDisclosure ? .detailButton : .none
        
        return cell
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

    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using [segue destinationViewController].
        // Pass the selected object to the new view controller.
        if segue.identifier == "Show Updates Segue" {
            if let dvc = segue.destination as? UpdatesTableViewController {
                dvc.category = category
                // pass dependency to data model
                dvc.model = self.model
            }
        }
        if segue.identifier == "Show Info Item Segue" {
            if let dvc = segue.destination as? InfoItemViewController,
                let cell = sender as? UITableViewCell , ftype == .info  {
                    // Info only (for now)
                    let indexPath = tableView.indexPath(for: cell)!
                    let row = indexPath.row
                    dvc.item = model.info[row]
            }
        }
    }
    

}
