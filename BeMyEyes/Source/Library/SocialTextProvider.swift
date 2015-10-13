//
//  SocialTextProvider.swift
//  BeMyEyes
//
//  Created by Simon Støvring on 21/01/15.
//  Copyright (c) 2015 Be My Eyes. All rights reserved.
//

import UIKit

class SocialTextProvider: UIActivityItemProvider {
	
	private var facebookText: String
	private var twitterText: String
	private var defaultText: String
	
	init(facebookText: String, twitterText: String, defaultText: String) {
		self.facebookText = facebookText
		self.twitterText = twitterText
		self.defaultText = defaultText
		super.init(placeholderItem: defaultText)
	}
	
	override func activityViewController(activityViewController: UIActivityViewController, itemForActivityType activityType: String) -> AnyObject? {
		switch activityType {
		case UIActivityTypePostToFacebook:
			return facebookText
		case UIActivityTypePostToTwitter:
			return twitterText
		default:
			return defaultText
		}
	}
	
}
