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
#import "EchonestWollmilchsau.h"
#import "EchoNestTicket.h"

@interface CountryVC ()

@property (strong, nonatomic) EchonestWollmilchsau *filterStarredItems;
@property (weak, nonatomic) IBOutlet UILabel *statusLabel;
@property (weak, nonatomic) IBOutlet UITextField *countryTextField;

@end

@implementation CountryVC

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
    
    DLog(@"Info: didReceiveMemoryWarning");
}

#pragma mark - Buttons

- (IBAction)doItButton:(id)sender
{
    DLog(@"Button pressed (:");
 

    [self.filterStarredItems removeObserver:self forKeyPath:@"status"];
    self.filterStarredItems = [[EchonestWollmilchsau alloc] init];
    [self.filterStarredItems addObserver:self
                              forKeyPath:@"status"
                                 options:0
                                 context:nil];
    [self.filterStarredItems filerStarredItemsByCountry:self.countryTextField.text];
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
