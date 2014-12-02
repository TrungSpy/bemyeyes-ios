//
//  BlindMainViewController_Tests.swift
//  BeMyEyes
//
//  Created by Tobias Due Munk on 02/12/14.
//  Copyright (c) 2014 Be My Eyes. All rights reserved.
//

import UIKit
import XCTest

class BlindMainViewController_Tests: FBSnapshotTestCase {
    
    var helperVC: BMEBlindMainViewController?
    
    override func setUp() {
        super.setUp()
        recordMode = false
        
        helperVC = UIApplication.sharedApplication().keyWindow?.rootViewController?.storyboard?.instantiateViewControllerWithIdentifier(BMEMainBlindControllerIdentifier) as? BMEBlindMainViewController
        helperVC?.viewDidLoad()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testOnAllDevices() {
        verifyViewOnAllDevices(helperVC!.view)
    }
    
    func testCreatePromoScreenshots() {
        verifyViewForPromoScreenshots(helperVC!.view)
    }
}
