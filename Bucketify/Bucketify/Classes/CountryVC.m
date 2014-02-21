//
//  ViewController.m
//  Bucketify
//
//  Created by Christopher Loessl on 02/11/13.
//  Copyright (c) 2013 Christopher Loessl. All rights reserved.
//

// song -> NSString that is a spotify:track:...
// track -> SPTrack

#import "CountryVC.h"
#import "common.h"
#import "Bucketify.h"
#import "config.h"

@interface CountryVC ()

@property (strong, nonatomic) Bucketify *bucketify;
@property (weak, nonatomic) IBOutlet UILabel *labelStatus;
@property (weak, nonatomic) IBOutlet UITextField *textFieldCountry;

@end

@implementation CountryVC

#pragma mark - View

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    self.textFieldCountry.delegate = self;
}

#pragma mark - Memory

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
    
    DLog(@"Info: didReceiveMemoryWarning");
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

#pragma mark - Actions

- (IBAction)doItButton:(id)sender
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    DLog(@"Button pressed (:");

    @try {
        [self.bucketify removeObserver:self forKeyPath:@"status"];
    }
    @catch (NSException * __unused exception) {}
    self.bucketify = [[Bucketify alloc] init];
    [self.bucketify addObserver:self
                     forKeyPath:@"status"
                        options:0
                        context:nil];
    [self.bucketify filterPlaylistName:[userDefaults stringForKey:kInPlaylist] byCountry:self.textFieldCountry.text toPlaylist:[userDefaults stringForKey:kOutPlaylist]];
}

#pragma mark - KVO/KVC

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"status"]) {
        self.labelStatus.text = self.bucketify.status;
    }
}

#pragma mark - dealloc

-(void)dealloc {
    @try {
        [self.bucketify removeObserver:self forKeyPath:@"status"];
    }
    @catch (NSException * __unused exception) {}
}

@end
