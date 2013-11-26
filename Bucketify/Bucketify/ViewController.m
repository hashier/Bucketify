//
//  ViewController.m
//  Bucketify
//
//  Created by Christopher Loessl on 02/11/13.
//  Copyright (c) 2013 Christopher Loessl. All rights reserved.
//

#import "ViewController.h"
#import "common.h"
#import "ENAPI.h"

#include "appkey.c"

@interface ViewController ()

@property (strong, nonatomic) NSString *userList;

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
        DLog(@"CocoaLibSpotify init failed: %@", error);
        abort();
    }
    
    // make sure that self.viewController is attached or placed in window hierarchy
    [self performSelector:@selector(login) withObject:nil afterDelay:0.0];
    
    // echo nest
    [[SPSession sharedSession] setDelegate:self];
    
    [ENAPIRequest setApiKey:@"***REMOVED***"];
    
    [self echoNestUserList];
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
    [self buildArrayItemsFromStarredPlaylist];
//    [self buildArrayItemsFromStarredPlaylist];
//    [self dumpItemsFromStarredPlaylist];
}


#pragma mark - EchoNest

- (NSString *)lastUser
{
    return [[NSUserDefaults standardUserDefaults] valueForKey:@"SpotifyUsers"][@"LastUser"];
}

- (void)echoNestUserList
{
    [ENAPIRequest GETWithEndpoint:@"catalog/list"
                    andParameters:nil
               andCompletionBlock:^(ENAPIRequest *request) {
                   for (NSDictionary *aName in request.response[@"response"][@"catalogs"]) {
                       DLog(@"%@", request.response);
                       if ([[self lastUser] isEqualToString:aName[@"name"]]) {
                           self.userList = aName[@"id"];
                           DLog(@"UserList is: %@", self.userList);
                           return;
                       }
                   }
                   DLog(@"UserList not found ):");
                   self.userList = nil;
               }];
}

- (void)echoNestUserListwithCompletionBlock:(void (^)(NSString *userList))completionBlock
{
    /* use with:
    [self echoNestUserListwithCompletionBlock:^(NSString *userList) {
        DLog(@"%@", userList);
    }];
     */
    
    if(!completionBlock)
        return; // Avoid crashs
    
    if (self.userList) {
        completionBlock(self.userList);
    } else {
        [ENAPIRequest GETWithEndpoint:@"catalog/list"
                        andParameters:nil
                   andCompletionBlock:^(ENAPIRequest *request) {
                       for (NSDictionary *aName in request.response[@"response"][@"catalogs"]) {
                           NSString *lastUser = [self lastUser];
                           if ([lastUser isEqualToString:aName[@"name"]]) {
                               completionBlock(aName[@"id"]);
                           }
                       }
                   }];
    }
}

- (void)echoNestLists
{
    [ENAPIRequest GETWithEndpoint:@"catalog/list"
                    andParameters:nil
               andCompletionBlock:^(ENAPIRequest *request) {
                   DLog(@"%@", request.response[@"response"][@"catalogs"]);
               }];
}

- (void)echoNestCreateUserList
{
    NSDictionary *parameters = @{@"name": [self lastUser], @"type": @"artist"};
    
    [ENAPIRequest POSTWithEndpoint:@"catalog/create"
                     andParameters:parameters
                andCompletionBlock:^(ENAPIRequest *request) {
                    // TODO: Check if catalog already exist
                    /*
                    {
                        "response": {
                            "status": {
                                "code": 5,
                                "message": "A catalog with this name is already owned by this API Key: CAVXBQN1429442B82E",
                                "version": "4.2"
                            }
                        }
                    }
                     */
                    NSString *catalogId = (NSString *)[request.response valueForKeyPath:@"response.id"];
                    self.userList = catalogId;
                    
                    DLog(@"%@", [NSString stringWithFormat:@"Catalog Create Request\nhttp status code: %ld\nechonest status code: %ld\nechonest status message: %@\nerror message: %@\nid: %@\n",
                                  NSIntToLong(request.httpResponseCode),
                                  NSIntToLong(request.echonestStatusCode),
                                  request.echonestStatusMessage,
                                  request.errorMessage,
                                  catalogId
                                  ]);
                }];
}

- (void)echoNestDelete:(NSString *)catalogId
{
    NSDictionary *parameters = @{@"id": catalogId};
    
    [ENAPIRequest POSTWithEndpoint:@"catalog/delete"
                     andParameters:parameters
                andCompletionBlock:
     ^(ENAPIRequest *request) {
         DLog(@"%@", [NSString stringWithFormat:@"Catalog Delete Request\nhttp status code: %ld\nechonest status code: %ld\nechonest status message: %@\nerror message: %@\nid: %@\n",
                       NSIntToLong(request.httpResponseCode),
                       NSIntToLong(request.echonestStatusCode),
                       request.echonestStatusMessage,
                       request.errorMessage,
                       catalogId
                       ]);
     }];
    self.userList = nil;
}

- (void)echoNestUpdateWithData:(NSArray *)data
{
//    NSDictionary *parameters = @{@"id": self.userList, @"data_type": @"json", @"data": @[@{@"item": @{@"artist_id": @"spotify-WW:artist:4XkhEirR2JZT4fncyOxxtf"}}]};

    NSArray *test = @[@{@"item": @{@"artist_id": @"spotify-WW:artist:4XkhEirR2JZT4fncyOxxtf"}}];
//    DLog(@"%@", test);
    NSString *string;
    string = @"[{\"item\":{\"artist_id\":\"spotify-WW:artist:4XkhEirR2JZT4fncyOxxtf\"}}]";
    string = [ENAPI encodeArrayAsJSON:test];

    NSDictionary *parameters = @{@"id": self.userList, @"data_type": @"json", @"data": [ENAPI encodeArrayAsJSON:data]};
    
    [ENAPIRequest POSTWithEndpoint:@"catalog/update"
                     andParameters:parameters
                andCompletionBlock:^(ENAPIRequest *request) {
                    DLog(@"Reqeust.response:\n%@", request.response);
                }];
}

#pragma mark - Spotify

- (void)buildArrayItemsFromStarredPlaylist
{
    [SPAsyncLoading waitUntilLoaded:[SPSession sharedSession].starredPlaylist timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedItems, NSArray *notLoadedItems) {
        
        DLog(@"%@", [SPSession sharedSession].starredPlaylist);
 
        // TODO: fix the capacity
        NSMutableArray *allSongs = [[NSMutableArray alloc] init];
        SPTrack *aTrack;
        SPPlaylistItem *aItem;
        SPArtist *aArtist;
        int i = 1;
        for (aItem in [SPSession sharedSession].starredPlaylist.items) {
            aTrack = ((SPTrack *)aItem.item);
            
            if (!aTrack.artists) {
                DLog(@"Error: Track is nil");
                continue;
            }
            
            // stupid stupid echonest stuff....
            if (1) {
                // only the first artist
                aArtist = [aTrack.artists firstObject];
                [allSongs addObject:@{@"item": @{@"artist_id": [self spotifyString:[aArtist.spotifyURL absoluteString]]}}];
            } else {
                // all artists
                for (aArtist in aTrack.artists) {
                    [allSongs addObject:@{@"item": @{@"artist_id": [self spotifyString:[aArtist.spotifyURL absoluteString]]}}];
                }
            }
            
            if (i % 10 == 0) {
                DLog(@"Sending: %d", i);
                
                //DLog(@"%@", allSongs);
                DLog(@"Count 1: %lu", NSUIntToLong([allSongs count]));
                NSArray *returnArray = [NSArray arrayWithArray:[[NSSet setWithArray:allSongs] allObjects]];
                DLog(@"Count 2: %lu", NSUIntToLong([returnArray count]));
                
                [self echoNestUpdateWithData:returnArray];
                allSongs = [[NSMutableArray alloc] init];
            }
            i++;
        }
        DLog(@"Sending: %d", i);
        
        //DLog(@"%@", allSongs);
        DLog(@"Count 1: %lu", NSUIntToLong([allSongs count]));
        NSArray *returnArray = [NSArray arrayWithArray:[[NSSet setWithArray:allSongs] allObjects]];
        DLog(@"Count 2: %lu", NSUIntToLong([returnArray count]));
        
        [self echoNestUpdateWithData:returnArray];
        allSongs = [[NSMutableArray alloc] init];
    }];
}

- (void)dumpItemsFromStarredPlaylist
{
    [SPAsyncLoading waitUntilLoaded:[SPSession sharedSession].starredPlaylist timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedItems, NSArray *notLoadedItems) {
        
        DLog(@"starredPlaylist: %@", [SPSession sharedSession].starredPlaylist);
        
        for (SPPlaylistItem *aItem in [SPSession sharedSession].starredPlaylist.items) {
            DLog(@"%@ - %@", ((SPArtist *)[((SPTrack *)aItem.item).artists firstObject]).name, ((SPTrack *)aItem.item).name);
        }
    }];
}

- (void)createPlaylistAndAddItemDUMMY
{
    SPPlaylistContainer *container = [SPSession sharedSession].userPlaylists;
    
    [SPAsyncLoading waitUntilLoaded:container timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedContainers, NSArray *notLoadedContainers) {
        DLog(@"%@", loadedContainers);
        [container createPlaylistWithName:@"TEST2" callback:^(SPPlaylist *createdPlaylist) {
            [SPAsyncLoading waitUntilLoaded:createdPlaylist timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedPlaylist, NSArray *notLoadedPlaylist) {
                DLog(@"buh");
                [SPTrack trackForTrackURL:[NSURL URLWithString:@"spotify:track:1zHlj4dQ8ZAtrayhuDDmkY"] inSession:[SPSession sharedSession] callback:^(SPTrack *track) {
                    [[loadedPlaylist firstObject] addItem:track atIndex:0 callback:^(NSError *error) {
                        DLog(@"Well done");
                    }];
                }];
            }];
        }];
    }];
}

#pragma mark - helper

- (NSString *)spotifyString:(NSString *)string
{
    return [string stringByReplacingOccurrencesOfString:@"spotify" withString:@"spotify-WW"];
}

- (NSString *)unSpotifyString:(NSString *)string
{
    return [string stringByReplacingOccurrencesOfString:@"spotify-WW" withString:@"spotify"];
}

@end
