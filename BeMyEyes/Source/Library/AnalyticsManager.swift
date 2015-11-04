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
    case _Signup
    
    
    // Sigthed:
    
    
    // Blind:
}

@objc enum SignupType: Int
{
    case _Email
    case _Facebook
}



@objc class AnalyticsManager: NSObject
{
    // MARK: - The methods to actually use from outside:
    
    static func identifyUser(user: BMEUser?)
    {
        AnalyticsManager.instance.identifyUser(user)
    }
    
    static func updateUserInformation(user: BMEUser)
    {
        AnalyticsManager.instance.updateUserInformation(user)
    }

    static func trackEvent(event: AnalyticsEvent, withProperties properties: [NSObject: AnyObject]?)
    {
        AnalyticsManager.instance.trackEvent(event, withProperties: properties)
    }
    
    static func trackSignupWithType(type: SignupType)
    {
        // Make sure user has been identified!
        AnalyticsManager.instance.trackEvent(._Signup, withProperties: ["Signup Type": [AnalyticsManager.stringForSignupType(type)]])
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
    
    private func identifyUser(user: BMEUser?)
    {
        if (user?.identifier != Mixpanel.sharedInstance().distinctId)
        {
            updateDistinctIdWithUser(user)
        }
    }
    
    private func updateDistinctIdWithUser(user: BMEUser?)
    {
        Mixpanel.sharedInstance().identify(user?.identifier)
        
        if let theUser = user
        {
            if let email = theUser.email
            {
                NSLog("Analytics: Identifying user: \(email)")
            }
            else
            {
                NSLog("Analytics: Identifying user")
            }
            
            updateUserInformation(theUser)
        }
        else
        {
            NSLog("Analytics: Identifying nil user")
        }
    }
    
    private func updateUserInformation(user: BMEUser)
    {
        var personalProperties = [NSObject: AnyObject]()
        if let user = BMEClient.sharedClient().currentUser
        {
            if let firstName = user.firstName {
                personalProperties["$first_name"] = firstName
            }
            
            if let lastName = user.lastName {
                personalProperties["$last_name"] = lastName
            }
            
            /*if let created = user.created  {
            personalProperties["$created"] = created
            }*/
            
            if let email = user.email {
                personalProperties["$email"] = email
            }
            
            if (user.isBlind())
            {
                personalProperties["User Type"] = "Blind"
            }
            else
            {
                personalProperties["User Type"] = "Sighted"
            }
        }
        
        NSLog("Analytics: Updating user information: \(personalProperties)")
        
        Mixpanel.sharedInstance().people.set(personalProperties)
    }
    
    private func trackEvent(event: AnalyticsEvent, withProperties properties: [NSObject: AnyObject]?)
    {
        NSLog("Track event: \(event) - properties: \(properties)")
        Mixpanel.sharedInstance().track(AnalyticsManager.stringForAnalyticsEvent(event), properties: properties)
    }

    private class func stringForAnalyticsEvent(event: AnalyticsEvent) -> String
    {
        switch (event)
        {
            case ._TestEvent:   return "TestEvent"
            case ._Signup:      return "Signup"
        }
    }
    
    private class func stringForSignupType(type: SignupType) -> String
    {
        switch (type)
        {
            case ._Email:   return "Email"
            case ._Facebook:  return "Facebook"
        }
    }
}