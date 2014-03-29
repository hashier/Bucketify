//
//  GenreVC.m
//  Bucketify
//
//  Created by Christopher Loessl on 02/03/14.
//  Copyright (c) 2014 Christopher Loessl. All rights reserved.
//

#import "GenreVC.h"
#import "common.h"
#import "Bucketify.h"
#import "config.h"

@interface GenreVC ()

@property (nonatomic, strong) Bucketify *bucketify;
@property (nonatomic, weak) IBOutlet UILabel *labelStatus;
@property (nonatomic, weak) IBOutlet UITextField *textFieldGenre;

@end

@implementation GenreVC

#pragma mark - Init

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
    
    DLog(@"Info: didReceiveMemoryWarning");
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

#pragma mark - Action

- (IBAction)bucketifyButton:(UIButton *)sender {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];

    NSString *inPlaylist = [userDefaults stringForKey:kInPlaylist];
    NSString *outPlaylist = [userDefaults stringForKey:kOutPlaylist];

    @try {
        [self.bucketify removeObserver:self forKeyPath:@"status"];
    }
    @catch (NSException * __unused exception) {}
    self.bucketify = [[Bucketify alloc] init];
    [self.bucketify addObserver:self
                     forKeyPath:@"status"
                        options:0
                        context:nil];
    [self.bucketify filterPlaylistName:inPlaylist byGenre:self.textFieldGenre.text toPlaylistName:outPlaylist];
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
