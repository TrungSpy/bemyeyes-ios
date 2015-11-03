//
//  AnalyticsManager.swift
//  BeMyEyes
//
//  Created by Andreas Bak-Riemer on 03/11/15.
//  Copyright © 2015 Be My Eyes. All rights reserved.
//

import Foundation


@objc enum AnalyticsEvent: Int
{
    case _TestEvent
    
    // General:
    
    
    // Sigthed:
    
    
    // Blind:
}



@objc class AnalyticsManager: NSObject
{
    // MARK: - The methods to actually use from outside:
    static func trackEvent(event: AnalyticsEvent, withProperties properties: [NSObject: AnyObject]?)
    {
        AnalyticsManager.instance.trackEvent(event, withProperties: properties)
    }
    
    
    // MARK: - Internal workings:
    private static let instance = AnalyticsManager()
    
    private override init()
    {
        switch (ApplicationProperties.environment())
        {
        case .Development:
            Mixpanel.sharedInstanceWithToken("b8a82537f03c536a6e73f430d6ab9872")
            
        case .Staging:
            Mixpanel.sharedInstanceWithToken("???") // TODO: Fill this in.
            
        case .Production:
            Mixpanel.sharedInstanceWithToken("???") // TODO: Fill this in.
        
        case .Undefined:
            NSLog("Cannot initialize Mixpanel without determined environment")
        }
        
        super.init()
    }
    
    private func trackEvent(event: AnalyticsEvent, withProperties properties: [NSObject: AnyObject]?)
    {
        NSLog("Track event: \(event) - properties: \(properties)")
        Mixpanel.sharedInstance().track(stringForAnalyticsEvent(event), properties: properties)
    }

    private func stringForAnalyticsEvent(event: AnalyticsEvent) -> String
    {
        switch (event)
        {
            case ._TestEvent: return "TestEvent"
        }
    }
}