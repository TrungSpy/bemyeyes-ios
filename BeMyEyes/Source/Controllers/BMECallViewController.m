//
//  BMECallViewController.m
//  BeMyEyes
//
//  Created by Simon Støvring on 23/03/14.
//  Copyright (c) 2014 Be My Eyes. All rights reserved.
//

#import "BMECallViewController.h"
#import <OpenTok/OpenTok.h>
#import "UINavigationController+BMEPopToClass.h"
#import "BMEMainViewController.h"
#import "BMEReportAbuseViewController.h"
#import "BMEClient.h"
#import "BMEUser.h"
#import "BMERequest.h"
#import "BMESpeaker.h"
#import "BMECallAudioPlayer.h"
#import "BMEOpenTokVideoCapture.h"


static NSString *BMECallPostSegue = @"PostCall";


// Signals to send over the OpenTok session:
static NSString* signalTypeTorch = @"torch";
static NSString* signalTypeRequestVersion = @"request_version";
static NSString* signalTypeProvideVersion = @"provide_version";

static NSString* signalValueOn = @"on";
static NSString* signalValueOff = @"off";


@interface BMECallViewController () <OTSessionDelegate, OTPublisherDelegate, OTSubscriberKitDelegate>

@property (weak, nonatomic) IBOutlet UIView *videoContainerView;
@property (weak, nonatomic) IBOutlet UILabel *statusLabel;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicatorView;
@property (weak, nonatomic) IBOutlet Button *disconnectButton;
@property (weak, nonatomic) IBOutlet UIButton *toggleTorchButton;

@property (strong, nonatomic) NSString *requestIdentifier;
@property (strong, nonatomic) NSString *sessionId;
@property (strong, nonatomic) NSString *token;

@property (strong, nonatomic) OTSession *session;
@property (strong, nonatomic) OTPublisher *publisher;
@property (strong, nonatomic) OTSubscriber *subscriber;
@property (strong, nonatomic) OTConnection* connection;
@property (strong, nonatomic) UIView *videoView;

@property (strong, nonatomic) BMECallAudioPlayer *callAudioPlayer;

@property (assign, nonatomic, getter = isDisconnecting) BOOL disconnecting;

@property (assign, nonatomic, getter = shouldPresentReportAbuseWhenDismissing) BOOL presentReportAbuseWhenDismissing;

@end


@implementation BMECallViewController
{
    NSDate* _callInitiated;
    
    BOOL _expectedTorchStateOn;
}

#pragma mark -
#pragma mark Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _toggleTorchButton.hidden = true;
    _expectedTorchStateOn = false;
    
    _toggleTorchButton.layer.borderColor = [UIColor whiteColor].CGColor;
    _toggleTorchButton.layer.borderWidth = 1;
    _toggleTorchButton.cornerRadius = 5;
    
    
    [MKLocalization registerForLocalization:self];
    
    self.statusLabel.text = MKLocalizedFromTable(BME_CALL_STATUS_PLEASE_WAIT, BMECallLocalizationTable);
    self.activityIndicatorView.isAccessibilityElement = NO;
    
    _callInitiated = nil;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    [UIApplication sharedApplication].idleTimerDisabled = YES;
 
    if (self.callMode == BMECallModeCreate) {
        [self createNewRequest];
    } else {
        [self answerRequestWithShortId:self.shortId];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    
    [self stopCallTone];
}

- (void)dealloc {
    [self stopCallTone];
	
	NSLog(@"DEALLOC CALL VIEW CONTROLLER");
    
    _requestIdentifier = nil;
    _shortId = nil;
    _sessionId = nil;
    _token = nil;
    _session = nil;
    _publisher = nil;
    _videoView = nil;
    _callAudioPlayer = nil;
}

- (void)shouldLocalize {
    self.disconnectButton.title = MKLocalizedFromTable(BME_CALL_DISCONNECT, BMECallLocalizationTable);
}

- (BOOL)accessibilityPerformMagicTap {
    if (self.disconnecting) {
        return NO;
    }
    [self disconnectWithError:nil];
    return YES;
}

- (BOOL)accessibilityPerformEscape {
    if (self.disconnecting) {
        return NO;
    }
    [self disconnectWithError:nil];
    return YES;
}


#pragma mark -
#pragma mark Private Methods


- (IBAction)toggleTorchButtonPressed:(id)sender
{
    _toggleTorchButton.enabled = false;
    _toggleTorchButton.alpha = 0.5;
    
    [UIView
     animateWithDuration:1.0
     animations:^{
         _toggleTorchButton.alpha = 1.0;
     }
     completion:^(BOOL finished) {
         _toggleTorchButton.enabled = true;
     }
     ];
    
    _expectedTorchStateOn = !_expectedTorchStateOn;
    UIImage* image = [UIImage imageNamed:(_expectedTorchStateOn ? @"Flashlight_Off" : @"Flashlight_On")];
    [_toggleTorchButton setImage:image forState:UIControlStateNormal];
    
    OTError* error;
    [_session
     signalWithType:signalTypeTorch
     string:(_expectedTorchStateOn ? signalValueOn : signalValueOff)
     connection:self.connection
     error:&error
    ];
    
    [AnalyticsManager
     trackEvent:AnalyticsEvent_Sighted_RequestToggleTorch
     withProperties:@{AnalyticsManager.propertyKey_SessionId: self.sessionId,
                      AnalyticsManager.propertyKey_Value: (_expectedTorchStateOn ? signalValueOn : signalValueOff)
                      }
     ];
}

- (IBAction)cancelButtonPressed:(id)sender
{
    [self endTrackingRequestOrAnswerWithError:[[NSError alloc] initWithDomain:@"BeMyEyes" code:-1 userInfo:@{@"cause": @"User cancelled request"}]];
    
    NSString *statusText = MKLocalizedFromTable(BME_CALL_STATUS_DISCONNECTING, BMECallLocalizationTable);
    [self changeStatus:statusText];
    [self disconnectWithError:nil];
}

- (void)createNewRequest
{
    NSString *statusText = MKLocalizedFromTable(BME_CALL_STATUS_CREATING_REQUEST, BMECallLocalizationTable);
    [self changeStatus:statusText];
    
    [AnalyticsManager beginTrackingEventWithType:AnalyticsEvent_Blind_Request];
    
    [[BMEClient sharedClient]
     createRequestWithSuccess:^(BMERequest *request) {
         self.requestIdentifier = request.identifier;
         self.shortId = request.shortId;
         self.sessionId = request.openTok.sessionId;
         self.token = request.openTok.token;
         [self connect];
         [self playCallTone];
     }
     failure:^(NSError *error) {
         NSString *title = MKLocalizedFromTable(BME_CALL_ALERT_FAILED_CREATING_REQUEST_TITLE, BMECallLocalizationTable);
         NSString *message = MKLocalizedFromTable(BME_CALL_ALERT_FAILED_CREATING_REQUEST_MESSAGE, BMECallLocalizationTable);
         NSString *cancel = MKLocalizedFromTable(BME_CALL_ALERT_FAILED_CREATING_REQUEST_CANCEL, BMECallLocalizationTable);
         UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:cancel otherButtonTitles:nil, nil];
         [alertView show];
         
         NSLog(@"Request could not be created: %@", error.localizedDescription);
         
         [self endTrackingRequestOrAnswerWithError:error];
         
         [self dismiss];
     }];
}

- (void)answerRequestWithShortId:(NSString *)shortId
{
    NSString *statusText = MKLocalizedFromTable(BME_CALL_STATUS_ANSWERING_REQUEST, BMECallLocalizationTable);
    [self changeStatus:statusText];
    
    [AnalyticsManager beginTrackingEventWithType:AnalyticsEvent_Sighted_Answer];
    
    [[BMEClient sharedClient]
     answerRequestWithShortId:shortId
     success:^(BMERequest *request) {
         self.requestIdentifier = request.identifier;
         self.shortId = request.shortId;
         self.sessionId = request.openTok.sessionId;
         self.token = request.openTok.token;
         [self connect];
     }
     failure:^(NSError *error) {
         if ([error code] == BMEClientErrorRequestAlreadyAnswered) {
             NSString *title = MKLocalizedFromTable(BME_CALL_ALERT_FAILED_ANSWERING_REQUEST_ANSWERED_TITLE, BMECallLocalizationTable);
             NSString *message = MKLocalizedFromTable(BME_CALL_ALERT_FAILED_ANSWERING_REQUEST_ANSWERED_MESSAGE, BMECallLocalizationTable);
             NSString *cancel = MKLocalizedFromTable(BME_CALL_ALERT_FAILED_ANSWERING_REQUEST_ANSWERED_CANCEL, BMECallLocalizationTable);
             UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:cancel otherButtonTitles:nil, nil];
             [alertView show];
         } else if ([error code] == BMEClientErrorRequestStopped) {
             NSString *title = MKLocalizedFromTable(BME_CALL_ALERT_FAILED_ANSWERING_REQUEST_STOPPED_TITLE, BMECallLocalizationTable);
             NSString *message = MKLocalizedFromTable(BME_CALL_ALERT_FAILED_ANSWERING_REQUEST_STOPPED_MESSAGE, BMECallLocalizationTable);
             NSString *cancel = MKLocalizedFromTable(BME_CALL_ALERT_FAILED_ANSWERING_REQUEST_STOPPED_CANCEL, BMECallLocalizationTable);
             UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:cancel otherButtonTitles:nil, nil];
             [alertView show];
         } else {
             NSString *title = MKLocalizedFromTable(BME_CALL_ALERT_FAILED_ANSWERING_UNKNOWN_TITLE, BMECallLocalizationTable);
             NSString *message = MKLocalizedFromTable(BME_CALL_ALERT_FAILED_ANSWERING_UNKNOWN_MESSAGE, BMECallLocalizationTable);
             NSString *cancel = MKLocalizedFromTable(BME_CALL_ALERT_FAILED_ANSWERING_UNKNOWN_CANCEL, BMECallLocalizationTable);
             UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:cancel otherButtonTitles:nil, nil];
             [alertView show];
         }
         
         NSLog(@"Request could not be answered: %@", error);
         
         [self endTrackingRequestOrAnswerWithError:error];
         
         [self dismiss];
     }];
}

- (void)connect
{
    NSLog(@"Connect to session: %@", self.shortId);
    NSLog(@" - sessionId: %@", self.sessionId);
    NSLog(@" - token: %@", self.token);
    
    NSString *statusText = MKLocalizedFromTable(BME_CALL_STATUS_CONNECTING, BMECallLocalizationTable);
    [self changeStatus:statusText];
    
    self.session = [[OTSession alloc] initWithApiKey:BMEOpenTokAPIKey sessionId:self.sessionId delegate:self];
    
    OTError *error = nil;
    [self.session connectWithToken:self.token error:&error];
    if (error)
    {
        [self endTrackingRequestOrAnswerWithError:error];
        
        NSLog(@"OpenTok: Failed connecting to session with error: %@", error);
        [self disconnectWithError:error];
    }
}

- (void)disconnectWithError:(NSError*)error
{
    self.disconnecting = YES;
    
    [self.videoView removeFromSuperview];
    self.videoView = nil;
    
    if (error)
    {
        [self endTrackingCallWithError:error];
    }
    
    void(^completion)(BOOL, NSError*) = ^(BOOL success, NSError *error)
    {
        if (error)
        {
            NSLog(@"Disconnect client error: %@", error);
            [self endTrackingCallWithError:error];
        }
            
        OTError *otError = nil;
        
        if (self.subscriber) {
            [self.session unsubscribe:self.subscriber error:&otError];
            if (otError)
            {
                [self endTrackingCallWithError:otError];
                NSLog(@"OpenTok: Failed unsubscribing with error: %@", error);
            }
        
            self.subscriber = nil;
        }
        
        if (self.publisher) {
            otError = nil;
            [self.session unpublish:self.publisher error:&otError];
            if (otError)
            {
                [self endTrackingCallWithError:otError];
                 NSLog(@"OpenTok: Failed unpublishing with error: %@", error);
            }
        
            self.publisher = nil;
        }
        
        [self endTrackingCallWithError:nil];

        [self dismiss];
    };
    
    if (!self.subscriber && [self isUserHelper]) {
        [[BMEClient sharedClient] cancelAnswerForRequestWithShortId:self.shortId completion:completion];
    } else {
        [[BMEClient sharedClient] disconnectFromRequestWithShortId:self.shortId completion:completion];
    }
}

- (void)publish
{
    self.publisher = [[OTPublisher alloc] initWithDelegate:self name:[BMEClient sharedClient].currentUser.firstName];
    
    self.publisher.publishAudio = YES;
    self.publisher.publishVideo = [self isUserBlind];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        // Must set video capture async as of 2.4.0 due to regression bug in OpenTok
        BMEOpenTokVideoCapture *videoCapture = [BMEOpenTokVideoCapture new];
        self.publisher.videoCapture = videoCapture;
        
        // Set camera position after setting video capture on
        videoCapture.cameraPosition = AVCaptureDevicePositionBack;
        
        if ([self isUserBlind])
        {
            self.publisher.view.transform = CGAffineTransformMakeScale(-1.0, 1.0);
        }
    });
    
    OTError *error = nil;
    [self.session publish:self.publisher error:&error];
    if (error) {
        NSLog(@"OpenTok: Failed publishing with error: %@", error);
        [self disconnectWithError:error];
    }
}

- (void)subscribeToStream:(OTStream *)stream {
    self.subscriber = [[OTSubscriber alloc] initWithStream:stream delegate:self];
    self.subscriber.subscribeToAudio = YES;
    self.subscriber.subscribeToVideo = ![self isUserBlind];
    
    OTError *error = nil;
    [self.session subscribe:self.subscriber error:&error];
    if (error) {
        NSLog(@"OpenTok: Failed subscribing to stream with error: %@", error);
        [self disconnectWithError:error];
    }
}

- (void)displayViewForPublisher:(OTPublisher *)publisher {
    [self displayVideoView:publisher.view];
}

- (void)displayViewForSubscriber:(OTSubscriber *)subscriber {
    [self displayVideoView:subscriber.view];
}

- (void)displayVideoView:(UIView *)videoView {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.videoContainerView addSubview:videoView];
        [videoView keepInsets:UIEdgeInsetsZero];
        self.videoView = videoView;
    });
}

- (void)changeStatus:(NSString *)string {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.statusLabel.hidden = NO;
        self.statusLabel.text = string;
        
        [self.activityIndicatorView startAnimating];
        
        if ([self isUserBlind]) {
            [BMESpeaker speak:string];
        }
    });
}

- (void)hideStatus {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.statusLabel.hidden = YES;
        [self.activityIndicatorView stopAnimating];
    });
}

- (void)dismiss {
    [[NSNotificationCenter defaultCenter] postNotificationName:BMEDidUpdatePointNotification object:nil];
    
    if (self.shouldPresentReportAbuseWhenDismissing) {
        [self performSegueWithIdentifier:BMECallPostSegue sender:self];
    } else {
        if (self.presentingViewController) {
            [self dismissViewControllerAnimated:YES completion:nil];
        } else {
            [self.navigationController BMEPopToViewControllerOfClass:[BMEMainViewController class] animated:YES];
        }
    }
}

- (BOOL)isUserBlind {
    return [BMEClient sharedClient].currentUser.role == BMERoleBlind;
}

- (BOOL)isUserHelper {
    return [BMEClient sharedClient].currentUser.role == BMERoleHelper;
}

- (void)playCallTone {
    if (!self.callAudioPlayer) {
        NSError *error = nil;
        self.callAudioPlayer = [BMECallAudioPlayer playerWithError:&error];
        if (!error) {
            if ([self.callAudioPlayer prepareToPlay]) {
                [self.callAudioPlayer play];
            }
        }
    }
}

- (void)stopCallTone {
    if (self.callAudioPlayer) {
        [self.callAudioPlayer stop];
        self.callAudioPlayer = nil;
    }
}

#pragma mark -
#pragma mark Session Delegate

- (void) session:(OTSession *)session connectionCreated:(OTConnection *)theConnection
{
    self.connection = theConnection;
}

// Requester and helper communicate over the OpenTok socket connection. Incomming transmissions are handled here:
- (void) session:(OTSession *)session receivedSignalType:(NSString *)type fromConnection:(OTConnection *)connection withString:(NSString *)string
{
    // Be very carefull about handling these
    // - the sender of a signal also receives it, so keep blind/sighted clearly separated, untill communication is labelled better.
    
    if ([self isUserBlind])
    {
        if ([type isEqualToString:signalTypeTorch])
        {
            // Helper wishes to toggle blind person's torch:
            if ([string isEqualToString:signalValueOn])
            {
                NSLog(@"Turn torch on");
                [self setTorchMode:AVCaptureTorchModeOn];
            }
            else if ([string isEqualToString:signalValueOff])
            {
                NSLog(@"Turn torch off");
                [self setTorchMode:AVCaptureTorchModeOff];
            }
            else
            {
                NSLog(@"Unrecognized signal");
            }
            
            return;
        }
        
        if ([type isEqualToString:signalTypeRequestVersion])
        {
            // Helper has requested blind person for app version:
            NSString* build = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
            
            OTError* error;
            [_session
             signalWithType:signalTypeProvideVersion
             string: build
             connection:self.connection
             error:&error
             ];
            
            return;
        }
    }
    else
    {
        // Sighted:
        if ([type isEqualToString:signalTypeProvideVersion])
        {
            // Reply for request about other person's app version number:
            int buildNumber = [string intValue];
            if (buildNumber >= 66)
            {
                _toggleTorchButton.hidden = false;
            }
        }
    }
}

- (void) setTorchMode:(AVCaptureTorchMode)mode
{
    AVCaptureDevice* flashLight = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if (    [flashLight isTorchAvailable]
        &&  [flashLight isTorchModeSupported:mode])
    {
        NSError* error;
        BOOL success = [flashLight lockForConfiguration:&error];
        if (success)
        {
            [flashLight setTorchMode:mode];
            [flashLight unlockForConfiguration];
            
            [AnalyticsManager
             trackEvent:AnalyticsEvent_Blind_ToggledTorch
             withProperties:@{AnalyticsManager.propertyKey_SessionId: self.sessionId,
                              AnalyticsManager.propertyKey_Value: (mode == AVCaptureTorchModeOn ? signalValueOn : signalValueOff)
                              }
             ];
        }
        else
        {
            // TODO: More handling
            NSLog(@"Torch: Could not lock for configuration: %@", error);
        }
    }
}


- (void)sessionDidConnect:(OTSession *)session
{
    NSLog(@"OpenTok: [Session] Did connect");
    if (!self.isDisconnecting)
    {
        NSString *statusText = MKLocalizedFromTable(BME_CALL_STATUS_CONNECTION_ESTABLISHED, BMECallLocalizationTable);
        [self changeStatus:statusText];
        [self publish];
        
        if (![self isUserBlind])
        {
            OTError* error;
            [_session
             signalWithType:signalTypeRequestVersion
             string: @""
             connection:self.connection
             error:&error
             ];
        }
    }
}

- (void)sessionDidDisconnect:(OTSession *)session
{
    NSLog(@"OpenTok: [Session] Did disconnect");
    [self dismiss];
}

- (void)session:(OTSession *)session didFailWithError:(OTError *)error {
    NSLog(@"Session failed: %@", error);
    
    NSString *statusText = MKLocalizedFromTable(BME_CALL_STATUS_SESSION_FAILED, BMECallLocalizationTable);
    [self changeStatus:statusText];
    [self disconnectWithError:error];
}

- (void)session:(OTSession *)session streamCreated:(OTStream *)stream {
    NSLog(@"OpenTok: [Session] Stream created");
    if (!self.isDisconnecting)
    {
        // Make sure we don't subscribe to our own stream
        if (![stream.connection.connectionId isEqualToString:session.connection.connectionId]) {
            NSLog(@"OpenTok: [Session] Subscribe to stream");
            [self subscribeToStream:stream];
        }
    }
}

- (void)session:(OTSession *)session streamDestroyed:(OTStream *)stream
{
    NSLog(@"OpenTok: [Session] Stream destroyed");
    if (!self.isDisconnecting)
    {
        [self endTrackingCallWithError:nil];
        
        // If we are not disconnecting ourselves, then the other part has disconnected
        NSString *title = MKLocalizedFromTable(BME_CALL_ALERT_OTHER_PART_DISCONNECTED_TITLE, BMECallLocalizationTable);;
        NSString *message = MKLocalizedFromTable(BME_CALL_ALERT_OTHER_PART_DISCONNECTED_MESSAGE, BMECallLocalizationTable);
        NSString *cancel = MKLocalizedFromTable(BME_CALL_ALERT_OTHER_PART_DISCONNECTED_CANCEL, BMECallLocalizationTable);
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:cancel otherButtonTitles:nil, nil];
        [alertView show];
        
        [self disconnectWithError:nil];
    }
}


- (void) session:(OTSession*)session archiveStartedWithId:(NSString*)archiveId name:(NSString*)name
{
    [AnalyticsManager
     trackEvent:AnalyticsEvent_ArchivingStarted
     withProperties:@{
                      AnalyticsManager.propertyKey_SessionId: session.sessionId,
                      AnalyticsManager.propertyKey_ArchiveId: archiveId
                      }
    ];
}

- (void) session:(OTSession*)session archiveStoppedWithId:(NSString*)archiveId
{
    [AnalyticsManager
     trackEvent:AnalyticsEvent_ArchivingEnded
     withProperties:@{
                      AnalyticsManager.propertyKey_SessionId: session.sessionId,
                      AnalyticsManager.propertyKey_ArchiveId: archiveId
                      }
     ];
}


#pragma mark -
#pragma mark Publisher Delegate

- (void)publisher:(OTPublisherKit *)publisher streamCreated:(OTStream *)stream
{
    NSLog(@"OpenTok: [Publisher] Stream created");
}

- (void)publisher:(OTPublisherKit *)publisher streamDestroyed:(OTStream *)stream {
    NSLog(@"OpenTok: [Publisher] Stream destroyed");
}

- (void)publisher:(OTPublisherKit *)publisher didFailWithError:(OTError *)error {
    NSLog(@"OpenTok: [Publisher] Did fail with error: %@", error);
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *statusText = MKLocalizedFromTable(BME_CALL_STATUS_FAILED_PUBLISHING, BMECallLocalizationTable);
        [self changeStatus:statusText];
    });
    
    [self disconnectWithError:error];
}

#pragma mark -
#pragma mark Subscriber Delegate

- (void)subscriberDidConnectToStream:(OTSubscriberKit *)subscriber
{
    NSLog(@"OpenTok: [Subscriber] Did connect to stream");
    
    [self endTrackingRequestOrAnswerWithError:nil];
    [AnalyticsManager beginTrackingEventWithType:AnalyticsEvent_Call];
    _callInitiated = [NSDate new];
    
    [self hideStatus];
    
    if (!self.isDisconnecting) {
        if ([self isUserBlind]) {
            NSString *speech = MKLocalizedFromTable(BME_CALL_SPEECH_DID_SUBSCRIBE, BMECallLocalizationTable);
            [BMESpeaker speak:speech];
        }
        
        if ([self isUserBlind]) {
            NSLog(@"Display publisher view");
            [self displayViewForPublisher:self.publisher];
            [self stopCallTone];
        } else {
            NSLog(@"Display subscriber view");
            [self displayViewForSubscriber:self.subscriber];
        }
        
        self.presentReportAbuseWhenDismissing = YES;
    }
}

- (void)subscriber:(OTSubscriberKit *)subscriber didFailWithError:(OTError *)error {
    NSLog(@"OpenTok: [Subscriber] Did fail with error: %@", error);
    NSString *statusText = MKLocalizedFromTable(BME_CALL_STATUS_FAILED_SUBSCRIBING, BMECallLocalizationTable);
    [self changeStatus:statusText];
    [self disconnectWithError:error];
}

#pragma mark -
#pragma mark Segue

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:BMECallPostSegue])
    {
        PostCallViewController *postCallViewController = (PostCallViewController *)segue.destinationViewController;
        postCallViewController.requestIdentifier = self.requestIdentifier;
        postCallViewController.sessionIdentifier = self.sessionId;
    }
}

#pragma mark - Analytics

- (void) endTrackingRequestOrAnswerWithError:(NSError*)error
{
    if (error == nil)
    {
        if ([BMEClient sharedClient].currentUser.isBlind)
        {
            [AnalyticsManager endTrackingEventWithType:AnalyticsEvent_Blind_Request withProperties:@{AnalyticsManager.propertyKey_SessionId: self.sessionId != nil ? self.sessionId : @"No session", AnalyticsManager.propertyKey_Result: [NSString stringWithFormat:@"Success"]}];
        }
        else
        {
            [AnalyticsManager endTrackingEventWithType:AnalyticsEvent_Sighted_Answer withProperties:@{AnalyticsManager.propertyKey_SessionId: self.sessionId != nil ? self.sessionId : @"No session", AnalyticsManager.propertyKey_Result: [NSString stringWithFormat:@"Success"]}];
        }
    }
    else
    {
        if ([BMEClient sharedClient].currentUser.isBlind)
        {
            [AnalyticsManager endTrackingEventWithType:AnalyticsEvent_Blind_Request withProperties:@{AnalyticsManager.propertyKey_SessionId: self.sessionId != nil ? self.sessionId : @"No session", AnalyticsManager.propertyKey_Result: [NSString stringWithFormat:@"Failure - %@", error]}];
        }
        else
        {
            [AnalyticsManager endTrackingEventWithType:AnalyticsEvent_Sighted_Answer withProperties:@{AnalyticsManager.propertyKey_SessionId: self.sessionId != nil ? self.sessionId : @"No session", AnalyticsManager.propertyKey_Result: [NSString stringWithFormat:@"Failure - %@", error]}];
        }
    }
}

- (void) endTrackingCallWithError:(NSError*)error
{
    if (!_callInitiated)
    {
        return;
    }
    
    if (error)
    {
        [AnalyticsManager endTrackingEventWithType:AnalyticsEvent_Call withProperties:@{AnalyticsManager.propertyKey_SessionId: self.sessionId != nil ? self.sessionId : @"No session", AnalyticsManager.propertyKey_Result: [NSString stringWithFormat:@"Failure - %@", error]}];
    }
    else
    {
        NSDate* now = [NSDate new];
        
        if ([now timeIntervalSinceDate:_callInitiated] < 20)
        {
            [AnalyticsManager endTrackingEventWithType:AnalyticsEvent_Call withProperties:@{AnalyticsManager.propertyKey_SessionId: self.sessionId != nil ? self.sessionId : @"No session", AnalyticsManager.propertyKey_Result: @"Failure - call lasted less than 20 seconds"}];
        }
        else
        {
            [AnalyticsManager endTrackingEventWithType:AnalyticsEvent_Call withProperties:@{AnalyticsManager.propertyKey_SessionId: self.sessionId != nil ? self.sessionId : @"No session", AnalyticsManager.propertyKey_Result: @"Success"}];
        }
    }
    _callInitiated = nil;
}

@end
