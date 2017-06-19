//
//  AlbumCollectionViewController.swift
//  StampCollection
//
//  Created by Michael L Mehr on 11/2/15.
//  Copyright © 2015 Michael L. Mehr. All rights reserved.
//

import UIKit

class AlbumCollectionViewController: UICollectionViewController {
    
    var model: CollectionStore!
    
    func startUI(_ store: CollectionStore) {
        families = fetch("AlbumFamily", inContext: model.getContextForThread(CollectionStore.mainContextToken)!)
        print("Started with \(families.count) album family groups")
        collectionView?.reloadData()
    }
    
    var families: [AlbumFamily] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Register cell classes // NOTE: this introduces bugs if uncommented - Oh, Apple!
   //     self.collectionView!.registerClass(UICollectionViewCell.self, forCellWithReuseIdentifier: reuseIdentifier)

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    /*
    // MARK: - Navigation
    */

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ShowAlbumSegue" {
            // Get the new view controller using [segue destinationViewController].
            if let destinationVC = segue.destination as? AlbumPageViewController,
                let theAlbum = sender as? AlbumRef {
                    // Pass the selected object to the new view controller.
                    destinationVC.model = model
                    destinationVC.setStartAlbum(theAlbum)
            }
        }
    }

    // MARK: UICollectionViewDataSource

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return families.count
    }


    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return families[section].theRefs.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "AlbumCell", for: indexPath) as! AlbumRefCell
    
        // Configure the cell
        // set the title from the ViewModel here
        let album = families[indexPath.section].theRefs[indexPath.item]
        let albumTitle = album.code ?? ""
        let (_, actualNumber) = splitNumericEndOfString(albumTitle)
        cell.title = actualNumber
    
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let sectionHeaderView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "AlbumHeader", for: indexPath) as! AlbumSectionHeaderView
        
        // set the title from the ViewModel here
        let family = families[indexPath.section]
        let album = family.theRefs[0]
        let albumTitle = album.code ?? ""
        let (actualTitle, _) = splitNumericEndOfString(albumTitle)
        let type = family.type.code ?? ""
        sectionHeaderView.title = "\(actualTitle) (\(type))"
        
        return sectionHeaderView
    }

    // MARK: UICollectionViewDelegate

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let family = families[indexPath.section]
        let album = family.theRefs[indexPath.item]
        let sections = album.theSections
        let pageCount = sections.reduce(0) { (total, section) -> Int in
            return total + section.thePages.count
        }
        let secnames = sections.reduce("") { (x, y) -> String in return "\(x)\(x.characters.count > 0 ? ", " : "")\(y.code!)" }
        print("Displaying album \(album.code!) with \(pageCount) pages in \(sections.count) sections: [\(secnames)].")
        
        // and go there ...
        performSegue(withIdentifier: "ShowAlbumSegue", sender: album)
    }
    
}
