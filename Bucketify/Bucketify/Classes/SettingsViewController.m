//
//  SettingsViewController.m
//  Bucketify
//
//  Created by Christopher Loessl on 03/02/14.
//  Copyright (c) 2014 Christopher Loessl. All rights reserved.
//

#import "SettingsViewController.h"
#import "common.h"
#import "CocoaLibSpotify.h"
#import "config.h"

@interface SettingsViewController ()
@property (weak, nonatomic) IBOutlet UITextField *textFieldInPlaylist;
@property (weak, nonatomic) IBOutlet UITextField *textFieldOutPlaylist;
@end

@implementation SettingsViewController

#pragma mark - init

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

#pragma mark - View

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.

    self.textFieldInPlaylist.delegate = self;
    self.textFieldOutPlaylist.delegate = self;
}

- (void)viewWillAppear:(BOOL)animated {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];

    [super viewDidAppear:animated];

    // layout
//    [userDefaults registerDefaults:@{kInPlaylist: @"Starred", kOutPlaylist: @"Starred_Filtered"}];

    self.textFieldInPlaylist.text = [userDefaults stringForKey:kInPlaylist];
    self.textFieldOutPlaylist.text = [userDefaults stringForKey:kOutPlaylist];
}

#pragma mark - Memory

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

#pragma mark - Actions

- (IBAction)logoutButton {
    DLog(@"Log out of Spotify");
    [[SPSession sharedSession] logout:nil];
}

- (IBAction)editDidEnd:(UITextField *)sender {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];

    if (sender == self.textFieldInPlaylist) {
        if ([sender.text isEqualToString:@""]) {
            sender.text = @"Starred";
        }
        [userDefaults setObject:self.textFieldInPlaylist.text forKey:kInPlaylist];
    } else if (sender == self.textFieldOutPlaylist) {
        if ([sender.text isEqualToString:@""]) {
            sender.text = @"Starred_Filtered";
        }
        [userDefaults setObject:self.textFieldOutPlaylist.text forKey:kOutPlaylist];
    }

    [userDefaults synchronize];
}


@end
