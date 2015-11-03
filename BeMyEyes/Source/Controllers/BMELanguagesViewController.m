//
//  BMELanguagesViewController.m
//  BeMyEyes
//
//  Created by Simon Støvring on 07/07/14.
//  Copyright (c) 2014 Be My Eyes. All rights reserved.
//

#import "BMELanguagesViewController.h"
#import "BMEClient.h"
#import "BMEUser.h"
#import <PSTAlertController.h>

#define BMELanguageCellReuseIdentifier @"LanguageCell"

@interface BMELanguagesViewController ()
@property (strong, nonatomic) NSArray *languageCodes;
@property (strong, nonatomic) NSMutableArray *knowLanguageCodes;
@property (assign, nonatomic) BOOL hasChanges;
@end

@implementation BMELanguagesViewController

#pragma mark -
#pragma mark Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [MKLocalization registerForLocalization:self];
    
    self.knowLanguageCodes = [NSMutableArray arrayWithArray:[BMEClient sharedClient].currentUser.languages];
    self.languageCodes = self.knowLanguageCodes; // Use users languages untill server responds with all available languages
    [[BMEClient sharedClient] loadAvailableLanguagesWithCompletion:^(NSArray *languages, NSError *error) {
        self.languageCodes = languages;
        [self.tableView reloadData];
    }];
}

- (void)dealloc {
    _languageCodes = nil;
    _knowLanguageCodes = nil;
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    return UIInterfaceOrientationPortrait;
}

- (void)shouldLocalize {
    self.title = MKLocalizedFromTable(BME_LANGUAGES_TITLE, BMELanguagesLocalizationTable);
}

#pragma mark -
#pragma mark Private Methods

- (IBAction)cancelButtonPressed:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)saveButtonPressed:(id)sender {
    if (!self.hasChanges) {
        [self dismissViewControllerAnimated:YES completion:nil];
    } else {
        
        if (self.knowLanguageCodes.count == 0) {
            [self _showNoLanguagesSelectedAlertView];
        }else{
            [self _saveLanguagesAndDismissController];
        }
    }
}

- (void) _showNoLanguagesSelectedAlertView
{
    PSTAlertController *alertView =
    [PSTAlertController alertControllerWithTitle: MKLocalizedFromTable(BME_LANGUAGES_ALERT_NO_LANGS_SELECTED, BMELanguagesLocalizationTable)
                                         message: MKLocalizedFromTable(BME_LANGUAGES_ALERT_PROCEED_QUESTION, BMELanguagesLocalizationTable)
                                  preferredStyle: PSTAlertControllerStyleAlert];
    
    PSTAlertAction *proceedAction =
    [PSTAlertAction actionWithTitle: MKLocalizedFromTable(BME_LANGUAGES_ALERT_PROCEED_QUESTION_ANSWER_YES, BMELanguagesLocalizationTable)
                            handler:^(PSTAlertAction *action) {
                                [self _saveLanguagesAndDismissController];
                            }];
    
    PSTAlertAction *stayAction =
    [PSTAlertAction actionWithTitle: MKLocalizedFromTable(BME_LANGUAGES_ALERT_PROCEED_QUESTION_ANSWER_NO, BMELanguagesLocalizationTable)
                              style: PSTAlertActionStyleCancel
                            handler: nil];
    
    [alertView addAction: proceedAction];
    [alertView addAction: stayAction];
    [alertView showWithSender: nil
                   controller: self
                     animated: YES
                   completion: nil];
}

- (void) _saveLanguagesAndDismissController
{
    void (^completion)(BOOL, NSError*) = ^(BOOL success, NSError *error) {
        if (success) {
            [self dismissViewControllerAnimated:YES completion:nil];
        } else {
            NSString *title = MKLocalizedFromTable(BME_LANGUAGES_ALERT_COULD_NOT_SAVE_TITLE, BMELanguagesLocalizationTable);
            NSString *message = MKLocalizedFromTable(BME_LANGUAGES_ALERT_COULD_NOT_SAVE_MESSAGE, BMELanguagesLocalizationTable);
            NSString *cancelButton = MKLocalizedFromTable(BME_LANGUAGES_ALERT_COULD_NOT_SAVE_CANCEL, BMELanguagesLocalizationTable);
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:cancelButton otherButtonTitles:nil, nil];
            [alert show];
        }
        
        if (error) {
            NSLog(@"Could not update user with known languages: %@", error);
        }
    };
    
    [[BMEClient sharedClient] updateUserWithKnownLanguages: self.knowLanguageCodes
                                                completion: completion];
}

#pragma mark -
#pragma mark Table View Data Source

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:BMELanguageCellReuseIdentifier];
    NSString *languageCode = [self.languageCodes objectAtIndex:indexPath.row];
    NSLocale *locale = [NSLocale localeWithLocaleIdentifier:languageCode];
    cell.textLabel.text = [[locale displayNameForKey:NSLocaleIdentifier value:languageCode] capitalizedStringWithLocale:[NSLocale currentLocale]];
    
    BOOL isKnownLanguage = [self.knowLanguageCodes containsObject:languageCode];
    cell.accessoryType = isKnownLanguage ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    
    return cell;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.languageCodes count];
}

#pragma mark -
#pragma mark Table View Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *languageCode = [self.languageCodes objectAtIndex:indexPath.row];
    BOOL isAlreadyKnownLanguage = [self.knowLanguageCodes containsObject:languageCode];
    
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    if (isAlreadyKnownLanguage) {
        [self.knowLanguageCodes removeObject:languageCode];
        cell.accessoryType = UITableViewCellAccessoryNone;
    } else {
        [self.knowLanguageCodes addObject:languageCode];
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    }
    
    cell.selected = !isAlreadyKnownLanguage;
    
    self.hasChanges = YES;
}

@end
