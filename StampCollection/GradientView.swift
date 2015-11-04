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
  
  lazy private var gradientLayer: CAGradientLayer = {
    let layer = CAGradientLayer()
    layer.colors = [UIColor(white: 0.25, alpha: 0.50).CGColor, UIColor(white: 0.0, alpha: 0.75).CGColor]
    if self.topDown {
        layer.colors = layer.colors?.reverse()
    }
    layer.locations = [NSNumber(float: 0.0), NSNumber(float: 1.0)]
    return layer
    }()
  
  override func awakeFromNib() {
    super.awakeFromNib()
    backgroundColor = UIColor.clearColor()
    layer.addSublayer(gradientLayer)
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    gradientLayer.frame = bounds
  }
  
}
