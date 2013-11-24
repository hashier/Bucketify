//
//  ViewController.m
//  Bucketify
//
//  Created by Christopher Loessl on 02/11/13.
//  Copyright (c) 2013 Christopher Loessl. All rights reserved.
//

#import "ViewController.h"
#import "common.h"

#include "appkey.c"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    NSError *error = nil;
    [SPSession initializeSharedSessionWithApplicationKey:[NSData dataWithBytes:&g_appkey length:g_appkey_size]
                                               userAgent:@"org.loessl.Bucketify-iOS"
                                           loadingPolicy:SPAsyncLoadingManual
                                                   error:&error];
    
    if (error != nil) {
        NSLog(@"CocoaLibSpotify init failed: %@", error);
        abort();
    }
    
    [[SPSession sharedSession] setDelegate:self];
    
    // make sure that self.viewController is attached or placed in window hierarchy
    [self performSelector:@selector(login) withObject:nil afterDelay:0.0];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - login

-(void)login
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *storedCredentials = [defaults valueForKey:@"SpotifyUsers"];
    
    if (storedCredentials == nil) {
        // make sure that self.viewController is attached or placed in window hierarchy
        [self performSelector:@selector(showLogin) withObject:nil afterDelay:0.0];
    } else {
        NSString *lastUser = [storedCredentials objectForKey:@"LastUser"] ;
        [[SPSession sharedSession] attemptLoginWithUserName:lastUser existingCredential:[storedCredentials objectForKey:lastUser]];
    }
}

-(void)showLogin
{
    SPLoginViewController *controller = [SPLoginViewController loginControllerForSession:[SPSession sharedSession]];
    controller.allowsCancel = NO;
    
    if (controller) {
        [self presentViewController:controller animated:NO completion:nil];
    } else {
        NSLog(@"Login window can't be shown");
    }
}

#pragma mark - SPSessionDelegate Methods

- (void)session:(SPSession *)aSession didGenerateLoginCredentials:(NSString *)credential forUserName:(NSString *)userName
{
    NSLog(@"storing credentials");
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
    DLog(@"Invoked by SPSession after a failed login: %@", error);
}

-(void)sessionDidLogOut:(SPSession *)aSession
{
    [self performSelector:@selector(showLogin) withObject:nil afterDelay:0.0];
}

-(void)session:(SPSession *)aSession didEncounterNetworkError:(NSError *)error
{
    DLog(@"Network error: %@", error);
}

-(void)session:(SPSession *)aSession didLogMessage:(NSString *)aMessage
{
    DLog(@"Log-worthy: %@", aMessage);
}

-(void)sessionDidChangeMetadata:(SPSession *)aSession
{
    DLog(@"Called when metadata has been updated.");
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
    [self getItemsFromStarredPlaylist];
}

- (void)getItemsFromStarredPlaylist
{
    [SPAsyncLoading waitUntilLoaded:[SPSession sharedSession].starredPlaylist timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedession, NSArray *notLoadedSession) {
        
        NSLog(@"%@", [SPSession sharedSession].starredPlaylist);
        
        for (SPPlaylistItem *aItem in [SPSession sharedSession].starredPlaylist.items) {
            NSLog(@"%@", ((SPTrack *)aItem.item).name);

            NSLog(@"%@", ((SPArtist *)[((SPTrack *)aItem.item).artists firstObject]).name);
        }
    }];
    
    SPPlaylistContainer *container = [SPSession sharedSession].userPlaylists;
    
    [SPAsyncLoading waitUntilLoaded:container timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedContainers, NSArray *notLoadedContainers) {
        NSLog(@"%@", loadedContainers);
        [container createPlaylistWithName:@"TEST2" callback:^(SPPlaylist *createdPlaylist) {
            [SPAsyncLoading waitUntilLoaded:createdPlaylist timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedPlaylist, NSArray *notLoadedPlaylist) {
                NSLog(@"buh");
                [SPTrack trackForTrackURL:[NSURL URLWithString:@"spotify:track:1zHlj4dQ8ZAtrayhuDDmkY"] inSession:[SPSession sharedSession] callback:^(SPTrack *track) {
                    [[loadedPlaylist firstObject] addItem:track atIndex:0 callback:^(NSError *error) {
                        NSLog(@"Well done");
                    }];
                }];
            }];
        }];
    }];
}

@end
