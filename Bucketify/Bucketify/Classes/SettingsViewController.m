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

@interface SettingsViewController ()

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
}

#pragma mark - Memory

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Actions

- (IBAction)logoutButton {
    DLog(@"Log out of Spotify");
    [[SPSession sharedSession] logout:nil];
}

@end
