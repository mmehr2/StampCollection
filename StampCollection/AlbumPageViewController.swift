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
        if let invBuilder = model.invBuilder {
            activePageAdds = invBuilder.isItemAddable(navigator!)
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
        navigator?.movePageRelative(.forward, byCount: 10)
        updateUI()
    }
    
    @IBAction func swipeTwoLeftDetected(_ sender: AnyObject) {
        navigator?.movePageRelative(.reverse, byCount: 10)
        updateUI()
    }
    
    @IBAction func longPressDetected(_ sender: AnyObject) {
        navigator?.gotoEndOfAlbum()
        updateUI()
    }
    
    @IBAction func addToThisPageButtonPressed(_ sender: Any) {
        print("Item will be added to this page.")
        if let invBuilder = model.invBuilder,
            let page = navigator?.currentPage {
            if invBuilder.addLocation(page) {
                if invBuilder.createItem(for: model) {
                    print("Added item OK, removing Builder \(invBuilder)")
                    model.invBuilder = nil
                } else {
                    print("Item add error for Builder \(invBuilder)")
                }
                updateUI()
            }
        }
    }
    
    @IBAction func addToNewNextPageButtonPressed(_ sender: Any) {
        print("Item will be added to the next page.")
    }
    
    @IBAction func addToNewIntermediatePageButtonPressed(_ sender: Any) {
        print("Item will be added to the next intermediate page.")
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
