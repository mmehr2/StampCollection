//
//  InventoryItemCell.swift
//  StampCollection
//
//  Created by Michael L Mehr on 11/2/15.
//  Copyright © 2015 Michael L. Mehr. All rights reserved.
//

import UIKit

class InventoryItemCell: UICollectionViewCell {
    @IBOutlet fileprivate weak var innerView: InventoryItemView!
    
    var title: String? {
        didSet {
            innerView.title = title
        }
    }
    
    var condition: String? {
        didSet {
            innerView.condition = condition
        }
    }
    
    /// allows setting the image directly
    var image: UIImage? {
        didSet {
            innerView.image = image
        }
    }
    
    /// set the image by providing a (remote) URL
    var picURL: URL? {
        didSet {
            innerView.picURL = picURL
        }
    }
    
    var wanted: Bool = false {
        didSet {
            innerView.wanted = wanted
        }
    }
    
}
