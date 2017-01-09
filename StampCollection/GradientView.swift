//
//  GradientView.swift
//  Wallpapers
//
//  Created by Mic Pringle on 09/01/2015.
//  Copyright (c) 2015 Razeware LLC. All rights reserved.
//
// Customized by mmehr2: from RayW Video Tutorial Series on Collection Views here: http://www.raywenderlich.com/94079/video-tutorial-collection-views-part-2-custom-cells
// 11/4/2015 - added inspectable topDown property to use with top edges as well as bottom
// 11/4/2015 - fade to lighter, transparent gray instead of clear

import UIKit

class GradientView: UIView {
    
  @IBInspectable var topDown: Bool = false
  
  lazy fileprivate var gradientLayer: CAGradientLayer = {
    let layer = CAGradientLayer()
    layer.colors = [UIColor(white: 0.25, alpha: 0.50).cgColor, UIColor(white: 0.0, alpha: 0.75).cgColor]
    if self.topDown {
        layer.colors = layer.colors?.reversed()
    }
    layer.locations = [NSNumber(value: 0.0 as Float), NSNumber(value: 1.0 as Float)]
    return layer
    }()
  
  override func awakeFromNib() {
    super.awakeFromNib()
    backgroundColor = UIColor.clear
    layer.addSublayer(gradientLayer)
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    gradientLayer.frame = bounds
  }
  
}
