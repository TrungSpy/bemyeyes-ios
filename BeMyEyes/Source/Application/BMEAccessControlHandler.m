//
//  BMEAccessControlHandler.m
//  BeMyEyes
//
//  Created by Tobias DM on 09/10/14.
//  Copyright (c) 2014 Be My Eyes. All rights reserved.
//

#import "BMEAccessControlHandler.h"
#import <AVFoundation/AVFoundation.h>


@interface BMEAccessControlHandler() <UIAlertViewDelegate>

@property (strong, nonatomic) void (^notificationsCompletion)(BOOL);

@end


@implementation BMEAccessControlHandler

+ (BMEAccessControlHandler *)sharedInstance
{
    static BMEAccessControlHandler *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [BMEAccessControlHandler new];
        
        [[GVUserDefaults standardUserDefaults] addObserver:sharedInstance
                                                forKeyPath:NSStringFromSelector(@selector(deviceToken))
                                                   options:0
                                                   context:NULL];
    });
    return sharedInstance;
}

+ (void)registerForRemoteNotifications {
    NSLog(@"Register for remote notifications");
    
    if ([[UIApplication sharedApplication] respondsToSelector:@selector(registerUserNotificationSettings:)]) {
        UIUserNotificationType types = (UIUserNotificationTypeAlert | UIUserNotificationTypeSound | UIUserNotificationTypeBadge);
        UIUserNotificationSettings *notificationSettings = [UIUserNotificationSettings settingsForTypes:types categories:nil];
        [[UIApplication sharedApplication] registerUserNotificationSettings:notificationSettings];
    } else {
        [[UIApplication sharedApplication] registerForRemoteNotificationTypes:(UIRemoteNotificationTypeAlert | UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound)];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:NSStringFromSelector(@selector(deviceToken))] &&
        object == [GVUserDefaults standardUserDefaults]) {
        [BMEAccessControlHandler hasNotificationsEnabled:^(BOOL isEnabled) {
            if (!isEnabled) {
                [BMEAccessControlHandler showNotificationsAlert];
            }
            if (self.notificationsCompletion) {
                self.notificationsCompletion(isEnabled);
                self.notificationsCompletion = nil;
            }
        }];
        return;
    }
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}


#pragma mark -
#pragma mark Public Methods

+ (void)enabledForRole:(BMERole)role completion:(void (^)(BOOL))completion
{
    [self hasNotificationsEnabled:^(BOOL isEnabled) {
        if (!isEnabled) {
            completion(NO);
            return;
        }
        [self hasMicrophoneEnabled:^(BOOL isEnabled) {
            if (!isEnabled) {
                completion(NO);
                return;
            }
            [self hasVideoEnabled:^(BOOL isEnabled) {
                completion(isEnabled);
            }];
        }];
    }];
}


// Remote notifications

+ (void)requireNotificationsEnabled:(void(^)(BOOL isEnabled))completion {
    // Store completion block
    [self sharedInstance].notificationsCompletion = completion;
    [self registerForRemoteNotifications];
}

+ (void)hasNotificationsEnabled:(void(^)(BOOL isEnabled))completion {
    BOOL hasNotificationsToken = [GVUserDefaults standardUserDefaults].deviceToken != nil;
    BOOL isTemporary = [GVUserDefaults standardUserDefaults].isTemporaryDeviceToken;
    BOOL isEnabled = hasNotificationsToken && !isTemporary;
    completion(isEnabled);
}


// Microphone

+ (void)requireMicrophoneEnabled:(void(^)(BOOL isEnabled))completion {
    [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
        if (!granted) {
            [self showMicrophoneAlert];
        }
        
        if (completion) {
            completion(granted);
        }
    }];
}

+ (void)hasMicrophoneEnabled:(void(^)(BOOL isEnabled))completion {
    if ([[AVAudioSession sharedInstance] respondsToSelector:@selector(recordPermission)]) {
        BOOL enabled;
        switch ([AVAudioSession sharedInstance].recordPermission) {
            case AVAudioSessionRecordPermissionUndetermined:
                enabled = NO;
                break;
            case AVAudioSessionRecordPermissionDenied:
                enabled = NO;
                break;
            case AVAudioSessionRecordPermissionGranted:
                enabled = YES;
            default:
                break;
        }
        completion(enabled);
    } else {
        // Fallback for iOS 7
        [self requireMicrophoneEnabled:completion];
    }
}


// Video

+ (void)requireCameraEnabled:(void(^)(BOOL isEnabled))completion {
    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!granted) {
                [self showCameraAlert];
            }
            if (completion) {
                completion(granted);
            }
        });
    }];
}

+ (void)hasVideoEnabled:(void(^)(BOOL isEnabled))completion {
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    AVCaptureDeviceInput *deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:nil];
    if (deviceInput)
    {
        // Access to the camera succeeded.
        if (completion) {
            completion(YES);
        }
        return;
    }
    if (completion) {
        completion(NO);
    }
}


#pragma mark - Private


+ (void)showNotificationsAlert
{
    [self showAlertWithTitle:MKLocalizedFromTable(BME_APP_DELEGATE_ALERT_FAILED_REGISTERING_REMOTE_NOTIFICATIONS_TITLE, BMEAppDelegateLocalizationTable)
                     message:MKLocalizedFromTable(BME_APP_DELEGATE_ALERT_FAILED_REGISTERING_REMOTE_NOTIFICATIONS_MESSAGE, BMEAppDelegateLocalizationTable)];
}

+ (void)showMicrophoneAlert
{
    [self showAlertWithTitle:MKLocalizedFromTable(BME_APP_DELEGATE_ALERT_MICROPHONE_DISABLED_TITLE, BMEAppDelegateLocalizationTable)
            message:MKLocalizedFromTable(BME_APP_DELEGATE_ALERT_MICROPHONE_DISABLED_MESSAGE, BMEAppDelegateLocalizationTable)];
}

+ (void)showCameraAlert
{
    [self showAlertWithTitle:MKLocalizedFromTable(BME_APP_DELEGATE_ALERT_CAMERA_DISABLED_TITLE, BMEAppDelegateLocalizationTable)
            message:MKLocalizedFromTable(BME_APP_DELEGATE_ALERT_CAMERA_DISABLED_MESSAGE, BMEAppDelegateLocalizationTable)];
}

+ (void)showAlertWithTitle:(NSString *)title message:(NSString *)message
{
    NSString *cancelButton;
    if ([self canGoToSystemSettings]) {
        cancelButton = MKLocalizedFromTable(BME_APP_DELEGATE_ALERT_ACCESS_DISABLED_CANCEL_CAN_GO_TO_SETTINGS, BMEAppDelegateLocalizationTable);
    } else {
        cancelButton = MKLocalizedFromTable(BME_APP_DELEGATE_ALERT_ACCESS_DISABLED_CANCEL, BMEAppDelegateLocalizationTable);
    }
    UIAlertView *alert;
    if ([self canGoToSystemSettings]) {
        NSString *openSettingsButton =  MKLocalizedFromTable(BME_APP_DELEGATE_ALERT_ACCESS_DISABLED_GO_TO_SETTINGS, BMEAppDelegateLocalizationTable);
        alert = [[UIAlertView alloc] initWithTitle:title message:message delegate:[self sharedInstance] cancelButtonTitle:cancelButton otherButtonTitles:openSettingsButton, nil];
    } else {
        alert = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:cancelButton otherButtonTitles:nil, nil];
    }
    [alert show];
}


#pragma mark - System Settings

+ (BOOL)canGoToSystemSettings
{
    @try {
        NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
        return [[UIApplication sharedApplication] canOpenURL:url];
    }
    @catch (NSException *exception) {
        NSLog(@"ff");
        return NO;
    }
}

+ (void)openSystemSettings
{
    NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
    if ([[UIApplication sharedApplication] canOpenURL:url]) {
        [[UIApplication sharedApplication] openURL:url];
    }
}


#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == alertView.cancelButtonIndex) {
        return;
    }
    [BMEAccessControlHandler openSystemSettings];
}

@end
