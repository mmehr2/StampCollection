//
//  AlbumCollectionViewController.swift
//  StampCollection
//
//  Created by Michael L Mehr on 11/2/15.
//  Copyright © 2015 Michael L. Mehr. All rights reserved.
//

import UIKit

private let reuseIdentifier = "AlbumCell"

class AlbumCollectionViewController: UICollectionViewController {
    
    var model: CollectionStore!
    
    func startUI(store: CollectionStore) {
        families = fetch("AlbumFamily", inContext: model.getContextForThread(CollectionStore.mainContextToken)!)
        print("Started with \(families.count) album family groups")
    }
    
    var families: [AlbumFamily] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Register cell classes
   //     self.collectionView!.registerClass(UICollectionViewCell.self, forCellWithReuseIdentifier: reuseIdentifier)

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
        return families.count
    }


    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return families[section].refs.count
    }

    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(reuseIdentifier, forIndexPath: indexPath) as! AlbumRefCell
    
        // Configure the cell
        // set the title from the ViewModel here
        let album = families[indexPath.section].theRefs[indexPath.item]
        let albumTitle = album.code ?? ""
        let (_, actualNumber) = splitNumericEndOfString(albumTitle)
        cell.title = actualNumber
    
        return cell
    }
    
    override func collectionView(collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, atIndexPath indexPath: NSIndexPath) -> UICollectionReusableView {
        let sectionHeaderView = collectionView.dequeueReusableSupplementaryViewOfKind(kind, withReuseIdentifier: "AlbumHeader", forIndexPath: indexPath) as! AlbumSectionHeaderView
        
        // set the title from the ViewModel here
        let family = families[indexPath.section]
        let album = family.theRefs[0]
        let albumTitle = album.code ?? ""
        let (actualTitle, _) = splitNumericEndOfString(albumTitle)
        let type = family.type.code
        sectionHeaderView.title = "\(actualTitle) (\(type))"
        
        return sectionHeaderView
    }

    // MARK: UICollectionViewDelegate

    override func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        let family = families[indexPath.section]
        let album = family.theRefs[indexPath.item]
        let sections = album.theSections
        let pageCount = sections.reduce(0) { (total, section) -> Int in
            return total + section.thePages.count
        }
        let secnames = sections.reduce("") { (x, y) -> String in return "\(x)\(x.characters.count > 0 ? ", " : "")\(y.code)" }
        print("Album \(album.code) has \(pageCount) pages in \(sections.count) sections: [\(secnames)].")
    }
    
    /*
    // Uncomment this method to specify if the specified item should be highlighted during tracking
    override func collectionView(collectionView: UICollectionView, shouldHighlightItemAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    */

    /*
    // Uncomment this method to specify if the specified item should be selected
    override func collectionView(collectionView: UICollectionView, shouldSelectItemAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    */

    /*
    // Uncomment these methods to specify if an action menu should be displayed for the specified item, and react to actions performed on the item
    override func collectionView(collectionView: UICollectionView, shouldShowMenuForItemAtIndexPath indexPath: NSIndexPath) -> Bool {
        return false
    }

    override func collectionView(collectionView: UICollectionView, canPerformAction action: Selector, forItemAtIndexPath indexPath: NSIndexPath, withSender sender: AnyObject?) -> Bool {
        return false
    }

    override func collectionView(collectionView: UICollectionView, performAction action: Selector, forItemAtIndexPath indexPath: NSIndexPath, withSender sender: AnyObject?) {
    
    }
    */

}
