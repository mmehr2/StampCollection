//
//  InventoryItemCell.swift
//  StampCollection
//
//  Created by Michael L Mehr on 11/2/15.
//  Copyright © 2015 Michael L. Mehr. All rights reserved.
//

import UIKit

class InventoryItemCell: UICollectionViewCell {
    
    @IBOutlet private weak var bottomLabel: UILabel!
    
    var title: String? {
        didSet {
            bottomLabel.text = title
        }
    }
    
    @IBOutlet private weak var topLabel: UILabel!
    
    var condition: String? {
        didSet {
            topLabel.text = condition
        }
    }
    
    @IBOutlet private weak var imageView: UIImageView!

    /// allows setting the image directly
    var image: UIImage? {
        didSet {
            imageView.image = image
        }
    }

    /// set the image by providing a (remote) URL
    var picURL: NSURL? {
        didSet {
            imageView.imageFromUrl(picURL) { image, urlReceived in
                if let image = image where urlReceived == self.picURL {
                    self.imageView.image = image
                }
            }
        }
    }
    
    var wanted: Bool = false {
        didSet {
            if wanted {
                self.backgroundColor = UIColor.redColor()
            } else {
                self.backgroundColor = UIColor.fern()
            }
        }
    }
    
}
