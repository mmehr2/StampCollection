//
//  AlbumPageViewController.swift
//  StampCollection
//
//  Created by Michael L Mehr on 11/2/15.
//  Copyright © 2015 Michael L. Mehr. All rights reserved.
//

import UIKit

/// This view controller will display the current page of interest in an album.
/// It will also allow navigation through the album by gesture recognizers:
/// 1. single-touch swipe left or right - increment/decrement by single pages
/// 2. double-touch swipe left or right - increment/decrement by 10-page jumps
/// 3. long press - go to start/end of album, or if already there, start/end of series
class AlbumPageViewController: UICollectionViewController {
    
    var model: CollectionStore!
    var callerUpdate: ((CollectionStore) -> ())?
    
    @IBOutlet weak var addToNewNextPageButton: UIBarButtonItem!
    @IBOutlet weak var addToThisPageButton: UIBarButtonItem!
    @IBOutlet weak var addToNewIntermediatePageButton: UIBarButtonItem!
    
    
    func setStartAlbum( _ album: AlbumRef ) {
        // setup the navigator for this album family using individual volume of series
        navigator = AlbumFamilyNavigator(album: album)
    }
    
    func setStartPage( _ page: AlbumPage ) {
        // setup the navigator for this album family using current page to display
        navigator = AlbumFamilyNavigator(page: page)
    }
    
    fileprivate var navigator: AlbumFamilyNavigator!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false
        
        // Register cell classes
        //    self.collectionView!.registerClass(UICollectionViewCell.self, forCellWithReuseIdentifier: reuseIdentifier)
        
        // Do any additional setup after loading the view.
        // set some gesture recognizers for command usage:
        let rightGR1 = UISwipeGestureRecognizer(target: self, action: #selector(AlbumPageViewController.swipeRightDetected(_:)))
        rightGR1.direction = .right
        rightGR1.numberOfTouchesRequired = 1
        collectionView?.addGestureRecognizer(rightGR1)
        let leftGR1 = UISwipeGestureRecognizer(target: self, action: #selector(AlbumPageViewController.swipeLeftDetected(_:)))
        leftGR1.direction = .left
        leftGR1.numberOfTouchesRequired = 1
        collectionView?.addGestureRecognizer(leftGR1)
        
        let rightGR2 = UISwipeGestureRecognizer(target: self, action: #selector(AlbumPageViewController.swipeTwoRightDetected(_:)))
        rightGR2.direction = .right
        rightGR2.numberOfTouchesRequired = 2
        collectionView?.addGestureRecognizer(rightGR2)
        let leftGR2 = UISwipeGestureRecognizer(target: self, action: #selector(AlbumPageViewController.swipeTwoLeftDetected(_:)))
        leftGR2.direction = .left
        leftGR2.numberOfTouchesRequired = 2
        collectionView?.addGestureRecognizer(leftGR2)
        
        let longGR = UILongPressGestureRecognizer(target: self, action: #selector(AlbumPageViewController.longPressDetected(_:)))
        collectionView?.addGestureRecognizer(longGR)
        
        updateUI()
    }
    
    // Make the toolbar visible as we enter
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setToolbarHidden(false, animated: animated)
        setAddButtonStates()
    }
    
    fileprivate func setAddButtonStates() {
        // decide if the add-page buttons are active and set them accordingly
        var activePageAdds = false
        if let invBuilder = model?.invBuilder {
            activePageAdds = invBuilder.isItemAddable(to: navigator!)
        }
        addToNewNextPageButton.isEnabled = activePageAdds
        addToThisPageButton.isEnabled = activePageAdds
        addToNewIntermediatePageButton.isEnabled = activePageAdds
    }
   
    // Make the toolbar invisible as we leave
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.navigationController?.setToolbarHidden(true, animated: animated)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func swipeRightDetected(_ sender: AnyObject) {
        navigator?.movePageRelative(.forward)
        updateUI()
    }
    
    @IBAction func swipeLeftDetected(_ sender: AnyObject) {
        navigator?.movePageRelative(.reverse)
        updateUI()
    }
    
    @IBAction func swipeTwoRightDetected(_ sender: AnyObject) {
        navigator?.moveToSectionMarker(.forward)
        updateUI()
    }
    
    @IBAction func swipeTwoLeftDetected(_ sender: AnyObject) {
        navigator?.moveToSectionMarker(.reverse)
        updateUI()
    }
    
    @IBAction func longPressDetected(_ sender: AnyObject) {
        navigator?.gotoMarker(.CurrentAlbumEnd)
        updateUI()
    }
    
    @IBAction func addToThisPageButtonPressed(_ sender: Any) {
        addToNewPageEx(.ThisPage)
    }
    
    @IBAction func addToNewNextPageButtonPressed(_ sender: Any) {
        addToNewPageEx(.NextPage)
    }
    
    @IBAction func addToNewIntermediatePageButtonPressed(_ sender: Any) {
        // create an action controller with N items for extra haves/wants (N<=6 depending on category.prices string)
        let ac = UIAlertController(title: "Add Item To ..", message: nil, preferredStyle: .alert)
        var act: UIAlertAction
        // add action to add item to a new intermediate page
        act = UIAlertAction(title: "New (.X) page", style: .default) { x in
            self.addToNewPageEx(.NextPageEx)
        }
        ac.addAction(act)
        // add action to add item to a new page in a new section of current album
        act = UIAlertAction(title: "Named section...", style: .default) { x in
            self.addToNamedSection() // uses page 1, current album; dialog asks for section name
        }
        ac.addAction(act)
        // add action to add item to a new page in next album of series
        act = UIAlertAction(title: "Next album, current section", style: .default) { x in
            self.addToNewPageEx(.NextAlbum) // uses next page code in default section numbering
        }
        ac.addAction(act)
        // add action to add item to a new page in a new section of next album
        act = UIAlertAction(title: "Next album, named section...", style: .default) { x in
            self.addToNamedSectionInNextAlbum() // uses page 1, next album; dialog asks for section name
        }
        ac.addAction(act)
        // add action to add item to a new page in a new section of a new album family
        act = UIAlertAction(title: "New album group...", style: .default) { x in
            self.addToNewAlbumFamily() // uses page 1 and default section, dialog asks album name, uses first ref (01), 2nd dialog selects type from list
        }
        ac.addAction(act)
        // add action to add item to a new page in a new section of a new album family
        act = UIAlertAction(title: "New album group, named section...", style: .default) { x in
            self.addToNamedSectionInNewAlbumFamily() // uses page 1, dialog asks for name of section and album, uses first ref (01), 2nd dialog selects type from list
        }
        ac.addAction(act)
        // add a cancel (None) operation and present the controller
        act = UIAlertAction(title: "Cancel", style: .cancel) { x in
            // no action here
        }
        ac.addAction(act)
        self.present(ac, animated: true, completion: nil)
    }
    
    fileprivate func addToNamedSection() {
        // run SEC name dialog, get name or cancel operation
        let existingNames = AlbumSection.allTheNames.sorted().joined(separator: ",")
        let qa = UIQueryAlert(type: .invAskSection(existingNames)) { result in
            if case let SearchType.location(secname) = result {
                return self.addToNewPageEx(.NamedSection(secname))
            }
        }
        qa.RunWithViewController(self)
    }
    
    fileprivate func addToNamedSectionInNextAlbum() {
        // run SEC name dialog, get name or cancel operation
        let existingNames = AlbumSection.allTheNames.sorted().joined(separator: ",")
        let qa = UIQueryAlert(type: .invAskSection(existingNames)) { result in
            if case let SearchType.location(secname) = result {
                return self.addToNewPageEx(.NextAlbumNamedSection(secname))
            }
        }
        qa.RunWithViewController(self)
    }
    
    fileprivate func addToNewAlbumFamily() {
        // run FAM name dialog, get name or cancel operation
        let existingNames = AlbumFamily.allTheNames.sorted().joined(separator: ",")
        let qa = UIQueryAlert(type: .invAskAlbum(existingNames)) { result in
            if case let SearchType.location(famname) = result {
                // run TYP name selector or cancel operation
                self.runAlbumTypeSelector() { typename in
                    return self.addToNewPageEx(.NewAlbumFamily(famname, ofType: typename))
                }
            }
        }
        qa.RunWithViewController(self)
   }
    
    fileprivate func addToNamedSectionInNewAlbumFamily() {
        // run SEC+FAM name dialog, get name or cancel operation
        let existingSectionNames = AlbumSection.allTheNames.sorted().joined(separator: ",")
        let existingFamilyNames = AlbumFamily.allTheNames.sorted().joined(separator: ",")
        let qa = UIQueryAlert(type: .invAskSectionAndAlbum(existingSectionNames,existingFamilyNames)) { result in
            if case let SearchType.location(asnames) = result {
                let comps = asnames.components(separatedBy: ";")
                let secname = comps[0]
                let famname = comps[1]
                // run TYP name selector or cancel operation
                self.runAlbumTypeSelector() { altypename in
                    return self.addToNewPageEx(.NewAlbumFamilyNamedSection(secname, inFamily: famname, ofType: altypename))
                }
            }
        }
        qa.RunWithViewController(self)
    }

    // run a selection box for album types, with a completion block to decide what to do with the selection
    func runAlbumTypeSelector(_ completion: ((String)->())? = nil) {
        var lines: [MenuBoxEntry] = []
        //print("Album types in use:")
        for name in AlbumType.allTheNames {
            //print(name)
            let y:MenuBoxEntry = (name, { x in
                if let tname = x?.title {
                    // place the title string into the invBuilder and call the next step
                    //print("Set TYPE name to \(tname)")
                    if let completion = completion {
                        completion(tname)
                    }
                }
            })
            lines.append(y)
        }
        menuBoxWithTitle("Choose Album Type", andBody: lines, forController: self)
    }

    enum AddType {
        case ThisPage, NextPageEx, NextPage, NextAlbum
        , NamedSection(String) // needs section name
        , NextAlbumNamedSection(String) // needs section name
        , NewAlbumFamily(String, ofType: String) // needs album and albumtype names
        , NewAlbumFamilyNamedSection(String, inFamily:String, ofType:String) // needs section, album and albumtype names
    }
    
    fileprivate func addToNewPageEx(_ type: AddType) {
        if let invBuilder = model.invBuilder, let nav = navigator {
            var description = "Item will be added to "
            var addedNewAlbum = false
            var debug = false
            // create a ref to the next page of the end of the current section in whatever album that's in
            // step 1. make sure we are at the proper EOS marker (for current section page add)
            // step 2. get the data ref of the current page
            let pageDataOrg, pageData: [String:String]
            // step 3. increment the ref properly (3 inc styles: page, exPage, albumIndex)
            switch type {
            case .ThisPage:
                description += "the current page of the current section in the current album."
                // no need to change positions
                pageDataOrg = nav.getRefAsData()
                pageData = pageDataOrg
           case .NextPageEx:
                description += "the next intermediate page of the current section in the current album."
                // no need to change positions
                pageDataOrg = nav.getRefAsData()
                pageData = offsetAlbumPageExInData(pageDataOrg)
            case .NextPage:
                description += "the next page of the current section of the current album group."
                // must be at end of section (across all albums in family)
                nav.gotoEndOfSectionAcrossVolumes()
                pageDataOrg = nav.getRefAsData()
                pageData = offsetAlbumPageInData(pageDataOrg)
            case .NextAlbum:
                description += "the next page of the current section of the next album in the current album group."
                // must be in last album of family
                nav.gotoMarker(.SeriesEnd)
                pageDataOrg = nav.getRefAsData()
                pageData = offsetAlbumIndexInData(pageDataOrg)
                addedNewAlbum = true
            case .NamedSection(let secname):
                description += "page 1 of the new section [\(secname)] of the current album group."
                // must be at end of last section (across all albums in family)
                nav.gotoMarkerAcrossVolumes([.SeriesEnd])
                pageDataOrg = nav.getRefAsData()
                pageData = addPageOneOfNewSection(secname, toAlbumData: pageDataOrg)
                //debug = true
                break
            case .NextAlbumNamedSection(let secname):
                description += "page 1 of the new section [\(secname)] of the next album in the current album group."
                // must be in last album of family
                nav.gotoMarker(.SeriesEnd)
                pageDataOrg = nav.getRefAsData()
                pageData = addPageOneOfNewSection(secname, toNextAlbumData: pageDataOrg)
                //debug = true
                break
            case .NewAlbumFamily(let famname, let typename):
                description += "page 1 of the default section [] of a new album group (name: \(famname), type: \(typename))."
                // no need to change positions
                pageDataOrg = nav.getRefAsData() // is this needed?
                pageData = addPageOneOfSection("", toNewAlbumFamily: famname, ofType: typename, withData: pageDataOrg)
                //debug = true
                break
            case .NewAlbumFamilyNamedSection(let secname, let famname, let typename):
                description += "page 1 of the new section [\(secname)] of a new album group (name: \(famname), type: \(typename))."
                // no need to change positions
                pageDataOrg = nav.getRefAsData() // is this needed?
                pageData = addPageOneOfSection(secname, toNewAlbumFamily: famname, ofType: typename, withData: pageDataOrg)
                //debug = true
                break
            }
            print(description)
            print("Repos Page data: \(pageDataOrg)")
            print("New Page data: \(pageData)")
            // step 4. use alternate form of invBuilder.addLocation to create new location from reference
            if debug {
                updateUI() // in case of repositioning side-effects
                messageBoxWithTitle("Add to Inventory", andBody: description, forController: self)
           } else if invBuilder.addLocation(pageData) {
                print("About to add item on page: \(invBuilder)")
                if invBuilder.createItem(for: model) {
                    if let newnav = invBuilder.navigatorForNewPage {
                        print("Added item OK, updated page navigator")
                        navigator = newnav
                        // multiple descriptions will be buffered for multiple partial set entry
                        if (invBuilder.nextMultiDescription() == false) {
                            print("No multi-descriptions, removing \(invBuilder)")
                            model.invBuilder = nil
                        }
                    } else {
                        print("Unable to update page navigator for \(invBuilder)")
                    }
                } else {
                    print("Item add error for \(invBuilder)")
                }
                updateUI()
                // new album will also affect calling VC
                if addedNewAlbum, let callerUpdate = callerUpdate {
                    callerUpdate(model)
                }
            } else {
                print("Unable to add location for \(invBuilder)")
            }
        }
    }
    
    fileprivate func updateUI() {
        // set the nav bar title to the page/section/ref indicator and show # of items
        title = navigator?.getCurrentPageTitle()
        // make sure state of add buttons is updated
        setAddButtonStates()
        // refresh the display of items on the current page
        collectionView?.reloadData()
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "InventoryItemSegue" {
            // Get the new view controller using [segue destinationViewController].
            if let destinationVC = segue.destination as? InventoryItemViewController,
                let theItem = sender as? InventoryItem {
                    // Pass the selected object to the new view controller.
                    destinationVC.model = model
                    destinationVC.item = theItem
            }
        }
    }

    // MARK: UICollectionViewDataSource

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }


    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return navigator?.currentPage.theItems.count ?? 0
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "InventoryItemCell", for: indexPath) as! InventoryItemCell
    
        // Configure the cell
        let item = navigator.currentPage.theItems[indexPath.item]
        let (top, btm) = getTitlesForInventoryItem(item)
        cell.title = btm
        cell.condition = top
        cell.wanted = item.wanted
        
        cell.image = nil // pave the way, delete any old image in dequeued cell
        let infoItem = item.dealerItem
        cell.picURL = infoItem?.picFileRemoteURL
    
        return cell
    }

    // MARK: UICollectionViewDelegate
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = navigator.currentPage.theItems[indexPath.item]
        
        // and go there ...
        performSegue(withIdentifier: "InventoryItemSegue", sender: item)
    }

}
