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
    case _Login
    
    case _Call
    case _ArchivingStarted
    
    case _ReportAbuse
    case _ReportAbuseFailed
    
    // Sigthed:
    case _Sighted_AttemptsToAnswerFromOpenApp
    case _Sighted_AttemptsToAnswerFromClosedApp
    case _Sighted_Answer
    case _Sighted_RefusedToAnswer
    case _Sighted_RequestToggleTorch
    
    // Blind:
    case _Blind_Request
    case _Blind_ToggledTorch
}

@objc enum SignupType: Int
{
    case _Email
    case _Facebook
}



@objc class AnalyticsManager: NSObject
{
    // Configuration:
    static let trackToLogEntries = false
    
    // Keys for tracked properties:
    static let propertyKey_RequestId =      "Request Id"
    static let propertyKey_SessionId =      "Session Id"
    static let propertyKey_ArchiveId =      "Archive Id"
    static let propertyKey_ArchiveLink =    "Archive Link"
    static let propertyKey_Result =         "Result"
    static let propertyKey_Reason =         "Reason"
    static let propertyKey_Value =          "Value"
    static let propertyKey_Error =          "Error"
    
    
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
    
    
    static func trackTestEvent()
    {
        AnalyticsManager.instance.trackEvent(
            ._TestEvent,
            withProperties: [
                "random0": Int(arc4random_uniform(10)),
                "random1": Int(arc4random_uniform(10)),
                "nested_random" : [
                    "nested_random0": Int(arc4random_uniform(10)),
                    "nested_random1": Int(arc4random_uniform(10))
                ]
            ]
        )
    }
    
    
    
    // MARK: - Internal workings:
    private static let instance = AnalyticsManager()
    
    private override init()
    {
        if (ApplicationProperties.environment() == .Production)
        {
            Mixpanel.sharedInstanceWithToken(BMEMixpanelToken)
            LELog.sharedInstance().token = BMELogEntriesToken
        }
        else
        {
            Mixpanel.sharedInstanceWithToken(BMEMixpanelDevlopmentToken)
            LELog.sharedInstance().token = BMELogEntriesDevelopmentToken
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
        if (eventIsPending(event))
        {
            AnalyticsManager.LogWhite("---- Ending a timed event (\(AnalyticsManager.stringForAnalyticsEvent(event))) with trackEvent... Mistake?")
            _pendingTimedEvents.removeAtIndex(_pendingTimedEvents.indexOf(event)!)
        }
        
        AnalyticsManager.LogWhite("---- Track event: \(AnalyticsManager.stringForAnalyticsEvent(event)) - properties: \(properties)")
        
        trackEventToMixPanel(event, withProperties: properties)
        
       if (AnalyticsManager.trackToLogEntries)
       {
            trackEventToLogEntries(event, withProperties: properties)
        }
    }
    
    private func trackEventToMixPanel(event: AnalyticsEvent, withProperties properties: [NSObject: AnyObject]?)
    {
        Mixpanel.sharedInstance().track(AnalyticsManager.stringForAnalyticsEvent(event), properties: properties)
    }
    
    private func trackEventToLogEntries(event: AnalyticsEvent, withProperties properties: [NSObject: AnyObject]?)
    {
        let user = BMEClient.sharedClient().currentUser
        
        var logData = [NSObject: AnyObject]()
        
        logData["event"] = AnalyticsManager.stringForAnalyticsEvent(event)

        if let user = user
        {
            logData["user.email"] = user.email != nil ? user.email! : "N/A"
            logData["user.usertype"] = user.isBlind() ? "blind" : "helper"
            logData["user.name_first"] = user.firstName != nil ? user.firstName! : "N/A"
            logData["user.name_last"] = user.lastName != nil ? user.lastName! : "N/A"
        }
        else
        {
            logData["user"] = "N/A"
        }
        
        if let eventProperties = properties
        {
            for (key, value) in eventProperties
            {
                if let _ = logData[key]
                {
                    NSLog("Merging analytics dictionaries: Key already exists: \(key)")
                }
                
                logData[key] = value
            }
        }
        
        do
        {
            let theJSONData = try NSJSONSerialization.dataWithJSONObject(logData, options: NSJSONWritingOptions(rawValue: 0))
            let theJSONText = NSString(data: theJSONData, encoding: NSASCIIStringEncoding)
            
            LELog.sharedInstance().log(theJSONText)
        }
        catch let error
        {
            NSLog("Failed tracking to LogEntries: \(error)")
        }
    }
    
    private var _pendingTimedEvents = [AnalyticsEvent]()
    
    private func beginTrackingEventWithType(event: AnalyticsEvent)
    {
        if (eventIsPending(event))
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
        if (!eventIsPending(event))
        {
            //AnalyticsManager.LogWhite("---- Ending a timed event (\(AnalyticsManager.stringForAnalyticsEvent(event))) that was not tracked...?")
            return
        }
        
        AnalyticsManager.LogWhite("---- Ending timed event: \(AnalyticsManager.stringForAnalyticsEvent(event))")
        removePendingEvent(event)
        trackEvent(event, withProperties: properties)
    }
    
    func eventIsPending(event: AnalyticsEvent) -> Bool
    {
        for pendingEvent in _pendingTimedEvents
        {
            if (pendingEvent.rawValue == event.rawValue)
            {
                return true
            }
        }
        
        return false
    }
    
    func removePendingEvent(event: AnalyticsEvent)
    {
        var index: Int = 0
        
        var found = false
        for pendingEvent in _pendingTimedEvents
        {
            if (pendingEvent.rawValue == event.rawValue)
            {
                found = true
                break;
            }
            
            index++
        }
        
        if (found)
        {
            _pendingTimedEvents.removeAtIndex(index)
        }
    }
    
    
    private class func stringForAnalyticsEvent(event: AnalyticsEvent) -> String
    {
        switch (event)
        {
        case ._TestEvent:                               return "TestEvent"
            
        // General:
        case ._Signup:                                  return "Signup"
        case ._Login:                                   return "Login"
            
        case ._Call:                                    return "Call"
        case ._ArchivingStarted:                        return "Archiving started"
           
        case ._ReportAbuse:                             return "Report abuse"
        case ._ReportAbuseFailed:                       return "Report abuse failed"
            
        // Sigthed:
        case ._Sighted_AttemptsToAnswerFromOpenApp:     return "Attempts answer from open app"
        case ._Sighted_AttemptsToAnswerFromClosedApp:   return "Attempts answer from closed app"
        case ._Sighted_RefusedToAnswer:                 return "Refused to answer"
        case ._Sighted_Answer:                          return "Answer"
        case ._Sighted_RequestToggleTorch:              return "Request torch toggle"
            
        // Blind:
        case ._Blind_Request:                           return "Request"
        case ._Blind_ToggledTorch:                      return "Torch toggled"
        }
    }
    
    private class func stringForSignupType(type: SignupType) -> String
    {
        switch (type)
        {
            case ._Email:     return "Email"
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