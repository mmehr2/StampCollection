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
    
    func setStartAlbum( album: AlbumRef ) {
        // setup the navigator for this album family
        navigator = AlbumFamilyNavigator(album: album)
    }
    
    func setStartPage( page: AlbumPage ) {
        // setup the navigator for this album family
        navigator = AlbumFamilyNavigator(page: page)
    }
    
    private var navigator: AlbumFamilyNavigator!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false
        
        // Register cell classes
        //    self.collectionView!.registerClass(UICollectionViewCell.self, forCellWithReuseIdentifier: reuseIdentifier)
        
        // Do any additional setup after loading the view.
        // set some gesture recognizers for command usage:
        let rightGR1 = UISwipeGestureRecognizer(target: self, action: "swipeRightDetected:")
        rightGR1.direction = .Right
        rightGR1.numberOfTouchesRequired = 1
        collectionView?.addGestureRecognizer(rightGR1)
        let leftGR1 = UISwipeGestureRecognizer(target: self, action: "swipeLeftDetected:")
        leftGR1.direction = .Left
        leftGR1.numberOfTouchesRequired = 1
        collectionView?.addGestureRecognizer(leftGR1)
        
        let rightGR2 = UISwipeGestureRecognizer(target: self, action: "swipeTwoRightDetected:")
        rightGR2.direction = .Right
        rightGR2.numberOfTouchesRequired = 2
        collectionView?.addGestureRecognizer(rightGR2)
        let leftGR2 = UISwipeGestureRecognizer(target: self, action: "swipeTwoLeftDetected:")
        leftGR2.direction = .Left
        leftGR2.numberOfTouchesRequired = 2
        collectionView?.addGestureRecognizer(leftGR2)
        
        let longGR = UILongPressGestureRecognizer(target: self, action: "longPressDetected:")
        collectionView?.addGestureRecognizer(longGR)
        
        updateUI()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func swipeRightDetected(sender: AnyObject) {
        navigator?.movePageRelative(.Forward)
        updateUI()
    }
    
    @IBAction func swipeLeftDetected(sender: AnyObject) {
        navigator?.movePageRelative(.Reverse)
        updateUI()
    }
    
    @IBAction func swipeTwoRightDetected(sender: AnyObject) {
        navigator?.movePageRelative(.Forward, byCount: 10)
        updateUI()
    }
    
    @IBAction func swipeTwoLeftDetected(sender: AnyObject) {
        navigator?.movePageRelative(.Reverse, byCount: 10)
        updateUI()
    }
    
    @IBAction func longPressDetected(sender: AnyObject) {
        navigator?.gotoEndOfAlbum()
        updateUI()
    }
    
    private func updateUI() {
        // set the nav bar title to the page/section/ref indicator and show # of items
        title = navigator?.getCurrentPageTitle()
        // refresh the display of items on the current page
        collectionView?.reloadData()
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "InventoryItemSegue" {
            // Get the new view controller using [segue destinationViewController].
            if let destinationVC = segue.destinationViewController as? InventoryItemViewController,
                theItem = sender as? InventoryItem {
                    // Pass the selected object to the new view controller.
                    destinationVC.model = model
                    destinationVC.item = theItem
            }
        }
    }

    // MARK: UICollectionViewDataSource

    override func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return 1
    }


    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return navigator?.currentPage.theItems.count ?? 0
    }
    
    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("InventoryItemCell", forIndexPath: indexPath) as! InventoryItemCell
    
        // Configure the cell
        let item = navigator.currentPage.theItems[indexPath.item]
        let (top, btm) = getTitlesForInventoryItem(item)
        cell.title = btm
        cell.condition = top
        cell.wanted = item.wanted
        
        cell.image = nil // pave the way, delete any old image in dequeued cell
        let infoItem = item.dealerItem
        cell.picURL = infoItem.picFileRemoteURL
    
        return cell
    }

    // MARK: UICollectionViewDelegate
    
    override func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        let item = navigator.currentPage.theItems[indexPath.item]
        
        // and go there ...
        performSegueWithIdentifier("InventoryItemSegue", sender: item)
    }

}
