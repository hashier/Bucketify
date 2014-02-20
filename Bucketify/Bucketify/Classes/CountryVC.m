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
#import "EchoNestWollmilchsau.h"
#import "config.h"

@interface CountryVC ()

@property (strong, nonatomic) EchoNestWollmilchsau *filterStarredItems;
@property (weak, nonatomic) IBOutlet UILabel *statusLabel;
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
        [self.filterStarredItems removeObserver:self forKeyPath:@"status"];
    }
    @catch (NSException * __unused exception) {}
    self.filterStarredItems = [[EchoNestWollmilchsau alloc] init];
    [self.filterStarredItems addObserver:self
                              forKeyPath:@"status"
                                 options:0
                                 context:nil];
//    [self.filterStarredItems filerStarredItemsByCountry:self.countryTextField.text];
//    [self.filterStarredItems filerPlaylistName:@"Starred" byCountry:@"Sweden" toPlaylist:@"test555"];
//    [self.filterStarredItems filterPlaylistName:@"test555" byCountry:@"Sweden" toPlaylist:@"test666"];
    [self.filterStarredItems filterPlaylistName:[userDefaults stringForKey:kInPlaylist] byCountry:self.textFieldCountry.text toPlaylist:[userDefaults stringForKey:kOutPlaylist]];
}

#pragma mark - KVO/KVC

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"status"]) {
        self.statusLabel.text = self.filterStarredItems.status;
    }
}

#pragma mark - dealloc

-(void)dealloc {
    @try {
        [self.filterStarredItems removeObserver:self forKeyPath:@"status"];
    }
    @catch (NSException * __unused exception) {}
}

@end
