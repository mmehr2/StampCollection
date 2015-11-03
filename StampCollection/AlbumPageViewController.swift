//
//  AlbumPageViewController.swift
//  StampCollection
//
//  Created by Michael L Mehr on 11/2/15.
//  Copyright © 2015 Michael L. Mehr. All rights reserved.
//

import UIKit

class AlbumPageViewController: UICollectionViewController {
    
    var album: AlbumRef! {
        didSet {
            maxSectionIndex = album.theSections.count
            currentSectionIndex = 0
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false
        
        // Register cell classes
        //    self.collectionView!.registerClass(UICollectionViewCell.self, forCellWithReuseIdentifier: reuseIdentifier)
        
        // Do any additional setup after loading the view.
        // set some gesture recognizers for command usage:
        // 1. single touch left or right - increment/decrement by single pages
        // 2. double touch left or right - increment/decrement by 10-page jumps
        // 3. long press - go to start/end of album, or if already there, start/end of series
        let rightGR1 = UISwipeGestureRecognizer(target: self, action: "swipeRightDetected:")
        rightGR1.direction = .Right
        rightGR1.numberOfTouchesRequired = 1
        collectionView!.addGestureRecognizer(rightGR1)
        let leftGR1 = UISwipeGestureRecognizer(target: self, action: "swipeLeftDetected:")
        leftGR1.direction = .Left
        leftGR1.numberOfTouchesRequired = 1
        collectionView!.addGestureRecognizer(leftGR1)
        
        let rightGR2 = UISwipeGestureRecognizer(target: self, action: "swipeTwoRightDetected:")
        rightGR2.direction = .Right
        rightGR2.numberOfTouchesRequired = 2
        collectionView!.addGestureRecognizer(rightGR2)
        let leftGR2 = UISwipeGestureRecognizer(target: self, action: "swipeTwoLeftDetected:")
        leftGR2.direction = .Left
        leftGR2.numberOfTouchesRequired = 2
        collectionView!.addGestureRecognizer(leftGR2)
        
        let longGR = UILongPressGestureRecognizer(target: self, action: "longPressDetected:")
        collectionView!.addGestureRecognizer(longGR)
        
        updateUI()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func swipeRightDetected(sender: AnyObject) {
        gotoNextPage()
        updateUI()
    }
    
    @IBAction func swipeLeftDetected(sender: AnyObject) {
        gotoPrevPage()
        updateUI()
    }
    
    @IBAction func swipeTwoRightDetected(sender: AnyObject) {
        gotoNextPage(10)
        updateUI()
    }
    
    @IBAction func swipeTwoLeftDetected(sender: AnyObject) {
        gotoPrevPage(10)
        updateUI()
    }
    
    @IBAction func longPressDetected(sender: AnyObject) {
        gotoEndOfAlbum()
        updateUI()
    }
    
    /*
    NOTE: The album can have multiple sections, and each one multiple pages.
    We only want to display the contents of one page at a time here. Other controllers will deal with bulk page operations, such as renumbering or moving between albums.
    We need an operation to move to the next page or previous page, continuing when we hit the end of a section (start or stop) in this album ref.
    Some nice-to-have ops would be FirstPageOfSection (to browse) and LastPageOfSection (to add new ones) too.
    Might we not also want to switch to previous or next ref in our parent family when trying to exit the album? Hmmm...
    We also need an operation to switch sections, if there are more than one.
    Finally, we need operations to edit the current page, or add a new page. Page deletion will be unlikely, but must follow strict protocols (all objects moved away).
    
    So, how to tell which page we are on? We need a section/page# pair, sounds like an NSIndexPath of sorts. Actual access should come from this ref via the album object's theSections array.
    */
    
    private var currentSectionIndex = 0 {
        didSet {
            currentSection = album.theSections[currentSectionIndex]
            // also reset the current page index
            maxPageIndexInSection = currentSection.thePages.count
            currentPageIndex = 0 // sets a page object as well
        }
    }
    private var currentPageIndex = 0 {
        didSet {
            currentPage = currentSection.thePages[currentPageIndex]
        }
    }
    
    private var maxSectionIndex = 0
    private var maxPageIndexInSection = 0
    
    private var currentSection: AlbumSection!
    private var currentPage: AlbumPage!
    
    private func updateUI() {
        // set the nav bar title to the page/section/ref indicator and show # of items
        let numItems = currentPage.theItems.count
        let albumcode = album.code
        let sectioncode = currentSection.code
        let pagenum = currentPage.code
        //let pagenum = Int(pagenumF)
        title = "\(albumcode) \(sectioncode == "" ? "" : "[\(sectioncode)] ")Page \(pagenum) - \(numItems) items"
        // refresh the display too
        collectionView!.reloadData()
    }

    // MARK: navigating the album hierarchy by pages
    // This type of nav is extended to go thru section and ref boundaries as if browsing one big book
    private func gotoNextPage(by: Int = 1) {
        let next = currentPageIndex + by
        if (0 ..< maxPageIndexInSection).contains(next) {
            currentPageIndex = next
            print("Set page index to \(currentPageIndex)")
        } else {
            print("Reached end of section")
            gotoNextSection()
        }
    }
    
    private func gotoPrevPage(by: Int = 1) {
        let next = currentPageIndex - by
        if (0 ..< maxPageIndexInSection).contains(next) {
            currentPageIndex = next
            print("Set page index to \(currentPageIndex)")
        } else {
            print("Reached start of section")
            gotoPrevSection()
        }
    }
    
    private func gotoNextSection() {
        let next = currentSectionIndex + 1
        if next < maxSectionIndex {
            currentSectionIndex = next
            print("Set section index to \(currentSectionIndex)")
        } else {
            print("Reached end of album")
            gotoNextAlbum()
        }
    }
    
    private func gotoPrevSection() {
        let next = currentSectionIndex - 1
        if next >= 0 {
            currentSectionIndex = next
            currentPageIndex = maxPageIndexInSection - 1
            print("Set section index to \(currentSectionIndex)")
        } else {
            print("Reached start of album")
            gotoPrevAlbum()
        }
    }
    
    private func gotoEndOfAlbum() {
        currentSectionIndex = maxSectionIndexInAlbum - 1
        currentPageIndex = maxPageIndexInSection - 1
    }

    private var currentAlbumIndex: Int? {
        get {
            let (_, index) = splitNumericEndOfString(album.code)
            guard let result = Int(index) else { return nil }
            return result - 1
        }
        set {
            guard let value = newValue else { return }
            album = album.family.theRefs[value]
        }
    }
    
    private var maxAlbumIndex: Int {
        return album.family.theRefs.count
    }
    
    private var maxSectionIndexInAlbum: Int {
        return album.theSections.count
    }
    
    private func gotoNextAlbum() {
        guard let currentAlbumIndexValue = currentAlbumIndex else {
            print("Singleton album not a series, cannot goto next.")
            return
        }
        let next = currentAlbumIndexValue + 1
        if next < maxAlbumIndex {
            currentAlbumIndex = next
            print("Set album index to \(currentAlbumIndex!)")
        } else {
            print("Reached end of series")
        }
    }
    
    private func gotoPrevAlbum() {
        guard let currentAlbumIndexValue = currentAlbumIndex else {
            print("Singleton album not a series, cannot goto previous.")
            return
        }
        let next = currentAlbumIndexValue - 1
        if next >= 0 {
            currentAlbumIndex = next
            gotoEndOfAlbum()
            print("Set album index to \(currentAlbumIndex!)")
        } else {
            print("Reached start of series")
        }
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using [segue destinationViewController].
        // Pass the selected object to the new view controller.
    }
    */

    // MARK: UICollectionViewDataSource

    override func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return 1
    }


    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return currentPage.theItems.count
    }

    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("InventoryItemCell", forIndexPath: indexPath) as! InventoryItemCell
    
        // Configure the cell
        let item = currentPage.theItems[indexPath.item]
        let infoItem = item.dealerItem
        cell.title = "\(infoItem.descriptionX) \(item.desc) \(item.notes)"
        cell.condition = "\(infoItem.id) \(item.itemCondition) \(item.itemPrice)"
        cell.wanted = item.wantHave == "w"
        cell.picURL = infoItem.picFileRemoteURL
    
        return cell
    }

    // MARK: UICollectionViewDelegate


}
