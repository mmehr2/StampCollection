//
//  InventoryItemView.swift
//  StampCollection
//
//  Created by Michael L Mehr on 11/6/15.
//  Copyright © 2015 Michael L. Mehr. All rights reserved.
//

import UIKit

let nibName = "InventoryItemView"

// Reusable view designed thanks to code at: http://iphonedev.tv/blog/2014/12/15/create-an-ibdesignable-uiview-subclass-with-code-from-an-xib-file-in-xcode-6
/**
InventoryItemView: reusable ViewModel class for displaying and editing InventoryItem objects

XIB Design: Thanks to code on iPhoneDev.tv (Paul Solt @PaulSolt)

Gradient View: Thanks to code from raywenderlich.com (Ray Wenderlich @rwenderlich)
*/
@IBDesignable class InventoryItemView: UIView {

    // Our custom view from the XIB file
    fileprivate var view: UIView!
    
    fileprivate func xibSetup() {
        view = loadViewFromNib(nibName)
        
        // use bounds not frame or it'll be offset
        view.frame = bounds
        
        // Make the view stretch with containing view
        view.autoresizingMask = [UIView.AutoresizingMask.flexibleWidth, UIView.AutoresizingMask.flexibleHeight]
        // Adding custom subview on top of our view (over any custom drawing > see note below)
        addSubview(view)
    }
    
    fileprivate func loadViewFromNib(_ nibName: String) -> UIView {
        
        let bundle = Bundle(for: type(of: self))
        let nib = UINib(nibName: nibName, bundle: bundle)
        let view = nib.instantiate(withOwner: self, options: nil)[0] as! UIView
        
        return view
    }
 
    override init(frame: CGRect) {
        // 1. setup any properties here
        
        // 2. call super.init(frame:)
        super.init(frame: frame)
        
        // 3. Setup view from .xib file
        xibSetup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        // 1. setup any properties here
        
        // 2. call super.init(coder:)
        super.init(coder: aDecoder)
        
        // 3. Setup view from .xib file
        xibSetup()
    }
    
    @IBOutlet fileprivate weak var bottomLabel: UILabel!

    /// a multiline description to be placed at the bottom of the image
    var title: String? {
        didSet {
            bottomLabel.text = title
        }
    }
    
    @IBOutlet fileprivate weak var topLabel: UILabel!

    /// an optional multiline label to be placed at the top of the image
    var condition: String? {
        didSet {
            topLabel.text = condition
        }
    }
    
    @IBOutlet fileprivate weak var imageView: UIImageView!
    
    /// allows setting the image directly
    @IBInspectable var image: UIImage? {
        get {
            return imageView.image
        }
        set {
            imageView.image = newValue
        }
    }
    
    /// sets the image by providing a (remote) URL
    var picURL: URL? {
        didSet {
            imageView.imageFromUrl(picURL) { image, urlReceived in
                if let image = image , urlReceived == self.picURL {
                    self.imageView.image = image
                }
            }
        }
    }
    
    /// sets the image background color to red(F) or green(T) to indicate if item is in collection or not
    var wanted: Bool = false {
        didSet {
            if wanted {
                self.imageView.backgroundColor = UIColor.red
            } else {
                self.imageView.backgroundColor = UIColor.fern()
            }
        }
    }
    

}
