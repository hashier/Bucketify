//
//  ViewController.m
//  Bucketify
//
//  Created by Christopher Loessl on 02/11/13.
//  Copyright (c) 2013 Christopher Loessl. All rights reserved.
//

// song -> NSString that is a spotify:track:...
// track -> SPTrack

#import "ViewController.h"
#import "common.h"
#import "EchonestWollmilchsau.h"
#import "EchoNestTicket.h"

#include "appkey.c"

@interface ViewController ()

@property (strong, nonatomic) EchonestWollmilchsau *filterStarredItems;
@property (weak, nonatomic) IBOutlet UILabel *statusLabel;
@property (weak, nonatomic) IBOutlet UITextField *countryTextField;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    // spotify
    NSError *error = nil;
    [SPSession initializeSharedSessionWithApplicationKey:[NSData dataWithBytes:&g_appkey length:g_appkey_size]
                                               userAgent:@"org.loessl.Bucketify-iOS"
                                           loadingPolicy:SPAsyncLoadingManual
                                                   error:&error];
    
    if (error != nil) {
        DLog(@"Error: CocoaLibSpotify init failed: %@", error);
        abort();
    }
    
    // make sure that self.viewController is attached or placed in window hierarchy
    [self performSelector:@selector(login) withObject:nil afterDelay:0.0];
    
    [[SPSession sharedSession] setDelegate:self];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
    
    DLog(@"Info: didReceiveMemoryWarning");
}

#pragma mark - Spotify login

-(void)login
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *storedCredentials = [defaults valueForKey:@"SpotifyUsers"];
    
    if (storedCredentials == nil) {
        // make sure that self.viewController is attached or placed in window hierarchy
        [self performSelector:@selector(showLogin) withObject:nil afterDelay:0.0];
    } else {
        NSString *lastUser = [storedCredentials objectForKey:@"LastUser"];
        [[SPSession sharedSession] attemptLoginWithUserName:lastUser existingCredential:[storedCredentials objectForKey:lastUser]];
    }
}

-(void)showLogin
{
    SPLoginViewController *controller = [SPLoginViewController loginControllerForSession:[SPSession sharedSession]];
    controller.allowsCancel = NO;
    
    if (controller) {
        if (controller == self.presentedViewController) return;
        [self presentViewController:controller animated:NO completion:nil];
    } else {
        DLog(@"Login window can't be shown");
    }
}

#pragma mark - SPSessionDelegate Methods

- (void)session:(SPSession *)aSession didGenerateLoginCredentials:(NSString *)credential forUserName:(NSString *)userName
{
    DLog(@"storing credentials");
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *storedCredentials = [[defaults valueForKey:@"SpotifyUsers"] mutableCopy];
    
    if (storedCredentials == nil)
        storedCredentials = [NSMutableDictionary dictionary];
    
    [storedCredentials setValue:credential forKey:userName];
    [storedCredentials setValue:userName forKey:@"LastUser"];
    [defaults setValue:storedCredentials forKey:@"SpotifyUsers"];
    [defaults synchronize];
}

-(UIViewController *)viewControllerToPresentLoginViewForSession:(SPSession *)aSession
{
    return self;
}

-(void)sessionDidLoginSuccessfully:(SPSession *)aSession
{
    DLog(@"Invoked by SPSession after a successful login.");
}

-(void)session:(SPSession *)aSession didFailToLoginWithError:(NSError *)error
{
    DLog(@"Error: Invoked by SPSession after a failed login: %@", error);
}

-(void)sessionDidLogOut:(SPSession *)aSession
{
    [self performSelector:@selector(showLogin) withObject:nil afterDelay:0.0];
}

-(void)session:(SPSession *)aSession didEncounterNetworkError:(NSError *)error
{
    DLog(@"Error: Network error: %@", error);
}

-(void)session:(SPSession *)aSession didLogMessage:(NSString *)aMessage
{
//    DLog(@"Log-worthy: %@", aMessage);
}

-(void)sessionDidChangeMetadata:(SPSession *)aSession
{
//    DLog(@"Called when metadata has been updated.");
}

-(void)session:(SPSession *)aSession recievedMessageForUser:(NSString *)aMessage
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Message from Spotify"
                                                    message:aMessage
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];
}

#pragma mark - SPLoginViewControllerDelegate Methods

- (void)loginViewController:(SPLoginViewController *)controller didCompleteSuccessfully:(BOOL)didLogin
{
    DLog(@"Called when the login/signup process has completed. From SPLoginViewController");
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
    [self.filterStarredItems removeObserver:self forKeyPath:@"status"];
}

@end
