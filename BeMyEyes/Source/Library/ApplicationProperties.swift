//
//  ApplicationProperties.swift
//  BeMyEyes
//
//  Created by Andreas Bak-Riemer on 03/11/15.
//  Copyright © 2015 Be My Eyes. All rights reserved.
//

import Foundation

@objc enum ApplicationEnvironment: Int
{
    case Development
    case Staging
    case Production
    
    case Undefined
}

@objc class ApplicationProperties: NSObject
{
    class func environment() -> ApplicationEnvironment
    {
        let bundleId = NSBundle.mainBundle().bundleIdentifier
        
        if (bundleId == BMEBundleIdProduction)
        {
            return .Production
        }
        else if (bundleId == BMEBundleIdStaging)
        {
            return .Staging
        }
        else if (bundleId == BMEBundleIdDevelopment)
        {
            return .Development
        }
        else
        {
            NSLog("Could not determine application environment with bundleId: \(bundleId)")
        }
        
        return .Undefined
    }
}