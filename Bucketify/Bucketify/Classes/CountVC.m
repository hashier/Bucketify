//
//  CountVC.m
//  Bucketify
//
//  Created by Christopher Loessl on 21/02/14.
//  Copyright (c) 2014 Christopher Loessl. All rights reserved.
//

#import "CountVC.h"
#import "common.h"
#import "Bucketify.h"
#import "config.h"

@interface CountVC ()

@property (strong, nonatomic) Bucketify *bucketify;
@property (weak, nonatomic) IBOutlet UILabel *labelStatus;

@end

@implementation CountVC

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Action

- (IBAction)bucketifyButton:(UIButton *)sender {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];

    NSString *inPlaylist = [userDefaults stringForKey:kInPlaylist];

    @try {
        [self.bucketify removeObserver:self forKeyPath:@"status"];
    }
    @catch (NSException * __unused exception) {}
    self.bucketify = [[Bucketify alloc] init];
    [self.bucketify addObserver:self
                     forKeyPath:@"status"
                        options:0
                        context:nil];
    [self.bucketify countSongsInPlaylist:inPlaylist];
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
