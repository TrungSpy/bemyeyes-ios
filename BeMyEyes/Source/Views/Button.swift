//
//  Button.swift
//  BeMyEyes
//
//  Created by Tobias DM on 08/10/14.
//  Copyright (c) 2014 Be My Eyes. All rights reserved.
//

import UIKit


@IBDesignable class Button: UIControl {
    
    enum Style: Int {
        case Filled
        case Border
    }

    @IBInspectable var title: String? {
        didSet {
            titleLabelFilled.text = title
            titleLabelBorder.text = title
        }
    }
    
    @IBInspectable var font: UIFont = UIFont.preferredFontForTextStyle(UIFontTextStyleHeadline) {
        didSet {
            titleLabelFilled.font = font
            titleLabelBorder.font = font
        }
    }

    var mainStyle: Style = .Filled {
        didSet {
            updateToState()
        }
    }
    private var secondaryStyle: Style {
        get {
            switch mainStyle {
                case .Filled: return .Border
                case .Border: return .Filled
            }
        }
    }
    private var currentStyle: Style = .Filled {
        didSet {
            let isFilled = currentStyle == .Filled
            titleLabelFilled.hidden = !isFilled
            titleLabelBorder.hidden = isFilled
        }
    }
    
    var color: UIColor = .whiteColor()
    var secondaryColor: UIColor = .lightTextColor()
    
    override var enabled: Bool {
        didSet {
            updateToState()
        }
    }
    override var highlighted: Bool {
        didSet {
            updateToState()
        }
    }
    override var accessibilityLabel: String! {
        get {
            return titleLabelFilled.accessibilityLabel
        }
        set {
            titleLabelFilled.accessibilityLabel = newValue
        }
    }
    
    private lazy var titleLabelFilled: MaskedLabel = {
        let label = MaskedLabel()
        label.font = self.font
        label.textAlignment = .Center
        label.layer.cornerRadius = 2
        return label
    }()
    
    private lazy var titleLabelBorder: UILabel = {
        let label = UILabel()
        label.font = self.font
        label.textAlignment = .Center
        label.layer.borderWidth = 2
        label.layer.cornerRadius = 2
        return label
    }()
    
    enum Centering: Int {
        case Normal
        case AtBottomEdge
        case AtTopEdge
    }
    var centering: Centering = .Normal {
        didSet {
            setNeedsLayout()
        }
    }
    private let inset: CGFloat = 14
    private var contentInsets: UIEdgeInsets {
        get {
            switch centering {
                case .Normal: return UIEdgeInsets(top: inset/2, left: inset, bottom: inset/2, right: inset)
                case .AtBottomEdge: return UIEdgeInsets(top: inset/2, left: inset, bottom: inset, right: inset)
                case .AtTopEdge: return UIEdgeInsets(top: inset, left: inset, bottom: inset/2, right: inset)
            }
        }
    }
    
    convenience init() {
        self.init(frame: CGRectZero)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let innerRect = bounds.inset(contentInsets)
        titleLabelFilled.frame = innerRect
        titleLabelBorder.frame = innerRect
    }
    
    override func prepareForInterfaceBuilder() {
        setup()
    }
    
    // Adapter for Storyboard inspectability
    @IBInspectable var mainStyleAsInt: Int = 0 {
        didSet {
            mainStyle = Style(rawValue: mainStyleAsInt) ?? .Border
        }
    }
    @IBInspectable var centeringAsInt: Int = 0 {
        didSet {
            centering = Centering(rawValue: centeringAsInt) ?? .Normal
        }
    }
}

extension Button {
    
    func setup() {
        opaque = false
        backgroundColor = UIColor.clearColor()
        addSubview(titleLabelFilled)
        addSubview(titleLabelBorder)
        updateToState()
    }
    
    func updateToState() {
        titleLabelFilled.color = colorForState(state)
        titleLabelBorder.textColor = colorForState(state)
        titleLabelBorder.layer.borderColor = colorForState(state).CGColor
        
        switch (state) {
            case UIControlState.Selected: fallthrough
            case UIControlState.Highlighted:
                currentStyle = secondaryStyle
            default:
                currentStyle = mainStyle
        }
    }
    
    func colorForState(state: UIControlState) -> UIColor {
        switch (state) {
            case UIControlState.Normal: fallthrough
            case UIControlState.Selected: fallthrough
            case UIControlState.Highlighted: return color
            case UIControlState.Disabled: return secondaryColor
            default: return color
        }
    }
}

extension CGRect {
    
    func inset(insets: UIEdgeInsets) -> CGRect {
        var rect = self
        rect.offsetInPlace(dx: insets.left, dy: insets.top)
        rect.size.width -= insets.left + insets.right
        rect.size.height -= insets.top + insets.bottom
        return rect
    }
}
