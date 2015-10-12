//
//  UIView+IBInspectable.swift
//  BeMyEyes
//
//  Created by Tobias Due Munk on 04/02/15.
//  Copyright (c) 2015 Be My Eyes. All rights reserved.
//

import UIKit

extension UIView {
    
    @IBInspectable var cornerRadius: CGFloat {
        get {
            return layer.cornerRadius
        }
        set {
            layer.cornerRadius = newValue
            layer.masksToBounds = newValue > 0
        }
    }
    
    @IBInspectable var borderWidth: CGFloat {
        get {
            return layer.borderWidth
        }
        set {
            layer.borderWidth = newValue
        }
    }
    @IBInspectable var borderColor: UIColor {
        get {
            if let borderColor = layer.borderColor {
                return UIColor(CGColor: borderColor)
            }
            
            return UIColor.clearColor()
        }
        set {
            layer.borderColor = newValue.CGColor
        }
    }
}
