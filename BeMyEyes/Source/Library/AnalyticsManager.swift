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
    case _Call
    
    // Sigthed:
    case _Sighted_Answer
    case _Sighted_RefusedToAnswer
    
    // Blind:
    case _Blind_Request
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
    
    static func beginTrackingEventWithType(event: AnalyticsEvent)
    {
        AnalyticsManager.instance.beginTrackingEventWithType(event)
    }
    
    static func endTrackingEventWithType(event: AnalyticsEvent, withProperties properties: [NSObject: AnyObject]?)
    {
        AnalyticsManager.instance.endTrackingEventWithType(event, withProperties: properties)
    }
    
    static func trackSignupWithType(type: SignupType)
    {
        // Make sure user has been identified!
        AnalyticsManager.instance.trackEvent(._Signup, withProperties: ["Signup Type": [AnalyticsManager.stringForSignupType(type)]])
        AnalyticsManager.instance.updateUserInformation(BMEClient.sharedClient().currentUser, andCreated:NSDate())
    }
    
    
    
    
    // MARK: - Internal workings:
    private static let instance = AnalyticsManager()
    
    private override init()
    {
        if (ApplicationProperties.environment() == .Production)
        {
            Mixpanel.sharedInstanceWithToken(BMEMixpanelToken)
        }
        else
        {
            Mixpanel.sharedInstanceWithToken(BMEMixpanelDevlopmentToken)
        }
        
        if let bundleId = NSBundle.mainBundle().bundleIdentifier
        {
             Mixpanel.sharedInstance().registerSuperProperties(["Bundle Id": bundleId])
        }
        else
        {
            Mixpanel.sharedInstance().registerSuperProperties(["Bundle Id": "Unknown"])
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
                AnalyticsManager.LogWhite("---- Analytics: Identifying user: \(email)")
            }
            else
            {
                AnalyticsManager.LogWhite("---- Analytics: Identifying user")
            }
            
            updateUserInformation(theUser)
        }
        else
        {
            AnalyticsManager.LogWhite("---- Analytics: Identifying nil user")
        }
    }
    
    private func updateUserInformation(user: BMEUser, andCreated createdTime: NSDate? = nil)
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
            
            if let created = createdTime {
                personalProperties["$created"] = created
            }
            
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
        
        AnalyticsManager.LogWhite("---- Analytics: Updating user information: \(personalProperties)")
        
        Mixpanel.sharedInstance().people.set(personalProperties)
    }
    
    private func trackEvent(event: AnalyticsEvent, withProperties properties: [NSObject: AnyObject]?)
    {
        if (_pendingTimedEvents.contains(event))
        {
            AnalyticsManager.LogWhite("---- Ending a timed event (\(AnalyticsManager.stringForAnalyticsEvent(event))) with trackEvent... Mistake?")
            _pendingTimedEvents.removeAtIndex(_pendingTimedEvents.indexOf(event)!)
        }
        
        AnalyticsManager.LogWhite("---- Track event: \(AnalyticsManager.stringForAnalyticsEvent(event)) - properties: \(properties)")
        Mixpanel.sharedInstance().track(AnalyticsManager.stringForAnalyticsEvent(event), properties: properties)
    }
    
    private var _pendingTimedEvents = [AnalyticsEvent]()
    
    private func beginTrackingEventWithType(event: AnalyticsEvent)
    {
        if (_pendingTimedEvents.contains(event))
        {
            AnalyticsManager.LogWhite("---- Already timing event of type \(AnalyticsManager.stringForAnalyticsEvent(event))")
            return
        }
        
        AnalyticsManager.LogWhite("---- Beginning event track: \(AnalyticsManager.stringForAnalyticsEvent(event))")
        _pendingTimedEvents.append(event)
        Mixpanel.sharedInstance().timeEvent(AnalyticsManager.stringForAnalyticsEvent(event))
    }
    
    private func endTrackingEventWithType(event: AnalyticsEvent, withProperties properties: [NSObject: AnyObject]?)
    {
        if (!_pendingTimedEvents.contains(event))
        {
            AnalyticsManager.LogWhite("---- Ending a timed event (\(event)) that was not tracked...?")
            return
        }
        
        _pendingTimedEvents.removeAtIndex(_pendingTimedEvents.indexOf(event)!)
        trackEvent(event, withProperties: properties)
    }
    
    
    
    
    private class func stringForAnalyticsEvent(event: AnalyticsEvent) -> String
    {
        switch (event)
        {
        case ._TestEvent:               return "TestEvent"
            
        // General:
        case ._Signup:                  return "Signup"
        case ._Call:                    return "Call"
            
        // Sigthed:
        case ._Sighted_Answer:          return "Answer"
        case ._Sighted_RefusedToAnswer: return "Refused to answer"
            
        // Blind:
        case ._Blind_Request:           return "Request"
            
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
    
    private class func LogWhite<T>(object: T)
    {
        let ESCAPE = "\u{001b}["
        let RESET = ESCAPE + ";"
        
        print("\(ESCAPE)fg255,255,255;\(object)\(RESET)")
    }
}