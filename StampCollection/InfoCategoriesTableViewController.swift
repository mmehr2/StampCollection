//
//  InfoCategoriesTableViewController.swift
//  StampCollection
//
//  Created by Michael L Mehr on 4/24/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import UIKit

class InfoCategoriesTableViewController: UITableViewController, ProgressReporting {
    
    lazy var csvFileImporter = ImportExport()
    
    var model: CollectionStore! {
        didSet {
            BTDealerStore.collection = model // allows generation of JS category pic fixups
        }
    }
    
    var uiEnabled: Bool = true {
        willSet(newValue) {
            // enable buttons when variable set to T
            importButton.isEnabled = newValue
            exportButton.isEnabled = newValue
            refreshButton.isEnabled = newValue
            // hide progress view when variable set to T
            progressViewBar.isHidden = newValue
        }
    }

    @IBOutlet weak var progressViewBar: UIProgressView!
    var progress: Progress = Progress()
    
    @IBOutlet weak var importButton: UIBarButtonItem!
    @IBAction func doImportAction(_ sender: UIBarButtonItem) {
        
        let sourceType = ImportExport.Source.bundle
        doImportFromSource(sourceType)
        
    }
    
    func doImportFromEmail(_ url: URL) {
        
        let sourceType = ImportExport.Source.emailAttachment(url: url)
        doImportFromSource(sourceType)
        
    }
    
    private func doImportFromSource( _ sourceType: ImportExport.Source) {

        guard let appDel = UIApplication.shared.delegate as? AppDelegate else {
            print("Unable to get app delegate - should never happen.")
            return
        }
        
        messageBoxWithTitleEx("Import Data from CSV", andBody: "NOTE: Wipes the database first! OK to proceed?", forController: self) { ac in
            var act = UIAlertAction(title: "Cancel", style: .cancel) { _ in
                // dismiss but do nothing
            }
            ac.addAction(act)
            act = UIAlertAction(title: "OK", style: .destructive) { _ in
                // wipe the slate
                self.uiEnabled = false
                self.progressViewBar.observedProgress = self.model.removeAllItemsInStore() {
                    // all items successfully erased here
                    self.progressViewBar.observedProgress = nil
                    // since we are majorly changing the model, we must notify all top level VCs of the change (including ourselves)
                    // NOTE: This will try to run the batch utilities on an empty database
                    // Thus we need a mechanism to suppress the progress viewing if nothing is going on
                    appDel.restartUI()
                    // load the new data from CSV files
                    // this is the active progress object we wish to observe to completion
                    self.progressViewBar.observedProgress = self.csvFileImporter.importData(sourceType, toModel: self.model) {
                        // save all the imported data to its persistence layer
                        self.model.saveMainContext()
                        self.uiEnabled = true
                        self.progressViewBar.observedProgress = nil
                        // trigger the app delegate to update all the top-level UI's with new model data (including self)
                        appDel.restartUI()
                    }
                }
            }
            ac.addAction(act)
        }

    }
    
    @IBOutlet weak var refreshButton: UIBarButtonItem!
    @IBAction func refreshButtonPressed(_ sender: UIBarButtonItem) {
        //?? let catcount = model.categories.count
        model.fetchType(.categories) {
            self.updateUI()
        }
    }
    
    @IBOutlet weak var exportButton: UIBarButtonItem!
    @IBAction func doExportAction(_ sender: UIBarButtonItem) {
        // new version: choose Docs vs. Email
        messageBoxWithTitleEx("Export Data to ...", andBody: "", forController: self) { ac in
            var act = UIAlertAction(title: "Cancel", style: .cancel) { _ in
                // dismiss but do nothing
            }
            ac.addAction(act)
            act = UIAlertAction(title: "CSV", style: .default) { _ in
                self.uiEnabled = false
                self.progressViewBar.observedProgress = self.model.exportAllData() {
                    self.uiEnabled = true
                    self.progressViewBar.observedProgress = nil
               }
            }
            ac.addAction(act)
            act = UIAlertAction(title: "CSV+Email", style: .default) { _ in
                self.uiEnabled = false
                // should use an activity indicator here as well, perhaps even UIProgressView
                // TBD: select type of export (email, airdrop, ??)
                let emailer = EmailAttachmentExporter(forController: self) { error in
                   if error.code != 0 {
                        messageBoxWithTitle("Email Send Error", andBody: error.localizedDescription, forController: self)
                    // turn back on the Export button before we switch to the emailer
                    self.uiEnabled = true
                    }
                }
                // send the data from CoreData to the CSV files
                self.uiEnabled = false
                self.progressViewBar.observedProgress = self.model.exportAllData() {
                    self.uiEnabled = true
                    self.progressViewBar.observedProgress = nil
                    // when done, send the CSV files on their way
                    emailer.sendFiles() // WILL ONLY WORK ON DEVICE, NO EMAIL ON SIMULATOR!!
                }
            }
            ac.addAction(act)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // make sure the toolbar is visible
        self.navigationController?.isToolbarHidden = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
    }
    
    /// special function to kick-start the UI after the data model has been properly set up
    /// NOTE: only provide this in one top-level VC, the one that shows the main screen
    // Progress object protocol:
    /* From the Apple docs - it's obscure: see Ole Bergmann on the issues back in 2014: https://oleb.net/blog/2014/03/nsprogress/
     As an example, consider that you are tracking the progress of code downloading and copying files on disk. You could use a single progress object to track the entire task, but it’s easier to manage each subtask using a separate progress object.
     You start by creating an overall parent progress object with a suitable total unit count,
     then call becomeCurrent(withPendingUnitCount:),
     then create your sub-task progress objects,
     before finally calling resignCurrent().
     A better article can be found here (June 4, 2016, about a year old): https://www.allaboutswift.com/dev/2016/6/4/working-with-nsprogress
     */
    func startUI(_ dataModel: CollectionStore) {
        // save the now-properly-initialized data model object reference
        model = dataModel
        print("startUI triggered in \(self)")
        // load the category data from CoreData
        title = "Collection Categories"
        model.fetchType(.categories) {
            // completion block of initial fetch (which is quick)
            // on completion, update the UI and tell the user any results
            self.updateUI()
            // assure that the JS picture mapping occurs
            if let cat = self.model.fetchCategory(CATNUM_AUSTRIAN) {
                populateJSDictionary(cat)
            }
            // READY any utility tasks on the DB while user is interacting with the last DB
            // perform any registered utility tasks; initial call will create Progress objects
            let utr = UtilityTaskRunner(withModel: self.model)
            // if there is nothing to do, don't clobber the progress object (an overall import may be in progress)
            var viewingProgress = false
            if utr.progress.totalUnitCount > 0 {
                self.progressViewBar.observedProgress = utr.progress
                self.uiEnabled = false
                viewingProgress = true
            }
            // make sure we update our progress bar viewer with the task's progress indicator
            // run the tasks on a background thread with a completion handler
            utr.callUtilityTasks() { uresult in
                if viewingProgress {
                    // if we're in charge of the progress view, we can shut it off now
                    self.uiEnabled = true
                    self.progressViewBar.observedProgress = nil
                }
                // tell the user about the task results last
                if !uresult.isEmpty {
                    messageBoxWithTitle("Utility Task Results", andBody: uresult, forController: self)
                }
            }
        }
    }

    func updateUI() {
        tableView.reloadData()
    }
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // Return the number of sections.
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Return the number of rows in the section.
        return model == nil ? 0 : model.categories.count + 1
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Info Category Cell", for: indexPath) 

        // Configure the cell...
        let row = indexPath.row
        if row == model.categories.count {
            // special handling for the AllData row
            cell.textLabel?.text = "All Categories"
            let categoryItems = model.getCountForType(.info)
            cell.detailTextLabel?.text = "(\(categoryItems) items)"
            cell.accessoryType = .none
        } else {
            let category = model.categories[row]
            let categoryItems = category.dealerItems.count
            cell.textLabel?.text = category.name
            cell.detailTextLabel?.text = "(\(categoryItems) items)"
            let allowDisc = !category.code.hasPrefix("*")
            cell.accessoryType = allowDisc ? .disclosureIndicator : .none
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
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using [segue destinationViewController].
        if segue.identifier == "Show Info Items Segue" {
            if let dvc = segue.destination as? InfoItemsTableViewController,
                let cell = sender as? UITableViewCell {
                    // pass dependency to data model
                    dvc.model = self.model
                    // get row number of cell
                    let indexPath = tableView.indexPath(for: cell)!
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
