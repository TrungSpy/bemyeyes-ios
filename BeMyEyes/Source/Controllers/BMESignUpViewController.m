//
//  BMESignUpViewController.m
//  BeMyEyes
//
//  Created by Simon Støvring on 22/02/14.
//  Copyright (c) 2014 Be My Eyes. All rights reserved.
//

#import "BMESignUpViewController.h"
#import <MRProgress/MRProgress.h>
#import "BMEAppDelegate.h"
#import "BMEClient.h"
#import "BMEEmailValidator.h"
#import "BMEScrollViewTextFieldHelper.h"

#define BMESignUpMinimumPasswordLength 6

@interface BMESignUpViewController () <UITextFieldDelegate>
@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;
@property (weak, nonatomic) IBOutlet UIButton *backButton;
@property (weak, nonatomic) IBOutlet UITextField *firstNameTextField;
@property (weak, nonatomic) IBOutlet UITextField *lastNameTextField;
@property (weak, nonatomic) IBOutlet UITextField *emailTextField;
@property (weak, nonatomic) IBOutlet UITextField *passwordTextField;
@property (weak, nonatomic) IBOutlet Button *registerButton;
@property (strong, nonatomic) BMEScrollViewTextFieldHelper *scrollViewHelper;
@end

@implementation BMESignUpViewController

#pragma mark -
#pragma mark Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [MKLocalization registerForLocalization:self];
    
    self.scrollViewHelper = [[BMEScrollViewTextFieldHelper alloc] initWithScrollview:self.scrollView inViewController:self];
}

- (void)shouldLocalize {
    [self.backButton setTitle:MKLocalizedFromTable(BME_SIGN_UP_BACK, BMESignUpLocalizationTable) forState:UIControlStateNormal];
    
    self.firstNameTextField.placeholder = MKLocalizedFromTable(BME_SIGN_UP_FIRST_NAME_PLACEHOLDER, BMESignUpLocalizationTable);
    self.lastNameTextField.placeholder = MKLocalizedFromTable(BME_SIGN_UP_LAST_NAME_PLACEHOLDER, BMESignUpLocalizationTable);
    
    self.emailTextField.placeholder = MKLocalizedFromTable(BME_SIGN_UP_EMAIL_PLACEHOLDER, BMESignUpLocalizationTable);
    self.passwordTextField.placeholder = MKLocalizedFromTable(BME_SIGN_UP_PASSWORD_PLACEHOLDER, BMESignUpLocalizationTable);
    
    self.registerButton.title = MKLocalizedFromTable(BME_SIGN_UP_REGISTER, BMESignUpLocalizationTable);
}

- (BOOL)prefersStatusBarHidden
{
    return self.scrollViewHelper.prefersStatusBarHidden;
}

- (UIStatusBarAnimation)preferredStatusBarUpdateAnimation
{
    return self.scrollViewHelper.preferredStatusBarUpdateAnimation;
}

- (BOOL)accessibilityPerformEscape {
    [self.navigationController popViewControllerAnimated:NO];
    return YES;
}


#pragma mark -
#pragma mark Private Methods

- (IBAction)signUpButtonPressed:(id)sender {
    [self performRegistration];
}

- (void)performRegistration {
    if ([self isInformationValid]) {
        [self dismissKeyboard];
        
        MRProgressOverlayView *progressOverlayView = [MRProgressOverlayView showOverlayAddedTo:self.view.window animated:YES];
        progressOverlayView.mode = MRProgressOverlayViewModeIndeterminate;
        progressOverlayView.titleLabelText = MKLocalizedFromTable(BME_SIGN_UP_OVERLAY_REGISTERING_TITLE, BMESignUpLocalizationTable);
        
        // Trim whitespace
        NSString *email = [self.emailTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSString *password = [self.passwordTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSString *firstName = [self.firstNameTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSString *lastName = [self.lastNameTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        [[BMEClient sharedClient] createUserWithEmail:email password:password firstName:firstName lastName:lastName role:self.role completion:^(BOOL success, NSError *error) {
            [progressOverlayView hide:YES];
            if (success && !error) {
                [self didLogin];
                
                [AnalyticsManager trackSignupWithType:SignupType_Email];
            } else {
                if ([error code] == BMEClientErrorUserEmailAlreadyRegistered) {
                    NSString *title = MKLocalizedFromTable(BME_SIGN_UP_ALERT_EMAIL_ALREADY_REGISTERED_TITLE, BMESignUpLocalizationTable);
                    NSString *message = MKLocalizedFromTable(BME_SIGN_UP_ALERT_EMAIL_ALREADY_REGISTERED_MESSAGE, BMESignUpLocalizationTable);
                    NSString *cancelButton = MKLocalizedFromTable(BME_SIGN_UP_ALERT_EMAIL_ALREADY_REGISTERED_CANCEL, BMESignUpLocalizationTable);
                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:cancelButton otherButtonTitles:nil, nil];
                    [alert show];
                } else {
                    NSString *title = MKLocalizedFromTable(BME_SIGN_UP_ALERT_UNKNOWN_ERROR_TITLE, BMESignUpLocalizationTable);
                    NSString *message = MKLocalizedFromTable(BME_SIGN_UP_ALERT_UNKNOWN_ERROR_MESSAGE, BMESignUpLocalizationTable);
                    NSString *cancelButton = MKLocalizedFromTable(BME_SIGN_UP_ALERT_UNKNOWN_ERROR_CANCEL, BMESignUpLocalizationTable);
                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:cancelButton otherButtonTitles:nil, nil];
                    [alert show];
                }
            }
        }];
    }
}

- (void)didLogin {
    [[BMEClient sharedClient] updateUserInfoWithUTCOffset:nil];
    [[BMEClient sharedClient] upsertDeviceWithNewToken:nil production:[GVUserDefaults standardUserDefaults].isRelease completion:nil];
    
    NSDictionary *userInfo = nil;
    if (self.role == BMERoleHelper) {
        userInfo = @{ BMEDidLogInNotificationDisplayHelperWelcomeKey : @(YES) };
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:BMEDidLogInNotification object:nil userInfo:userInfo];
}

- (BOOL)isInformationValid {
    NSString *email = [self.emailTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *password = [self.passwordTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *firstName = [self.firstNameTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *lastName = [self.lastNameTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    BOOL isFirstNameEmpty = firstName.length == 0;
    BOOL isLastNameEmpty = lastName.length == 0;
    BOOL isEmailEmpty = email.length == 0;
    BOOL isPasswordEmpty = email.length == 0;
    
    if (isFirstNameEmpty || isLastNameEmpty || isEmailEmpty || isPasswordEmpty) {
        if (isFirstNameEmpty) {
            [self.firstNameTextField becomeFirstResponder];
        } else if (isLastNameEmpty) {
            [self.lastNameTextField becomeFirstResponder];
        } else if (isEmailEmpty) {
            [self.emailTextField becomeFirstResponder];
        } else if (isPasswordEmpty) {
            [self.passwordTextField becomeFirstResponder];
        }
        
        NSString *title = MKLocalizedFromTable(BME_SIGN_UP_ALERT_EMPTY_FIELDS_TITLE, BMESignUpLocalizationTable);
        NSString *message = MKLocalizedFromTable(BME_SIGN_UP_ALERT_EMPTY_FIELDS_MESSAGE, BMESignUpLocalizationTable);
        NSString *cancelButton = MKLocalizedFromTable(BME_SIGN_UP_ALERT_EMPTY_FIELDS_CANCEL, BMESignUpLocalizationTable);
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:cancelButton otherButtonTitles:nil, nil];
        [alert show];
        
        return NO;
    } else if (![BMEEmailValidator isEmailValid:email]) {
        NSString *title = MKLocalizedFromTable(BME_SIGN_UP_ALERT_EMAIL_NOT_VALID_TITLE, BMESignUpLocalizationTable);
        NSString *message = MKLocalizedFromTable(BME_SIGN_UP_ALERT_EMAIL_NOT_VALID_MESSAGE, BMESignUpLocalizationTable);
        NSString *cancelButton = MKLocalizedFromTable(BME_SIGN_UP_ALERT_EMAIL_NOT_VALID_CANCEL, BMESignUpLocalizationTable);
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:cancelButton otherButtonTitles:nil, nil];
        [alert show];
        
        return NO;
    } else if ([password length] < BMESignUpMinimumPasswordLength) {
        NSString *title = MKLocalizedFromTable(BME_SIGN_UP_ALERT_PASSWORD_TOO_SHORT_TITLE, BMESignUpLocalizationTable);
        NSString *message = MKLocalizedFromTable(BME_SIGN_UP_ALERT_PASSWORD_TOO_SHORT_MESSAGE, BMESignUpLocalizationTable);
        NSString *cancelButton = MKLocalizedFromTable(BME_SIGN_UP_ALERT_PASSWORD_TOO_SHORT_CANCEL, BMESignUpLocalizationTable);
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:cancelButton otherButtonTitles:nil, nil];
        [alert show];
        
        return NO;
    }
    
    return YES;
}

- (void)dismissKeyboard {
    if ([self.firstNameTextField isFirstResponder]) {
        [self.firstNameTextField resignFirstResponder];
    } else if ([self.lastNameTextField isFirstResponder]) {
        [self.lastNameTextField resignFirstResponder];
    } else if ([self.emailTextField isFirstResponder]) {
        [self.emailTextField resignFirstResponder];
    } else if ([self.passwordTextField isFirstResponder]) {
        [self.passwordTextField resignFirstResponder];
    }
}

#pragma mark -
#pragma mark Text Field Delegate

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    self.scrollViewHelper.activeView = textField;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    self.scrollViewHelper.activeView = nil;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == self.firstNameTextField) {
        [self.lastNameTextField becomeFirstResponder];
    } else if (textField == self.lastNameTextField) {
        [self.emailTextField becomeFirstResponder];
    } else if (textField == self.emailTextField) {
        [self.passwordTextField becomeFirstResponder];
    } else if (textField == self.passwordTextField) {
        [textField resignFirstResponder];
        [self performRegistration];
    }
    
    return YES;
}

@end
