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
#import "ENAPI.h"

#include "appkey.c"

@interface ViewController ()

@property (strong, nonatomic) NSString *userTasteprofile;
@property (strong, nonatomic) NSString *userTicket;
@property (strong, nonatomic) NSSet *echoNestArtists;

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
    
    [self echoNestUserTasteprofile];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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
    
    [self echoNestUserTasteprofileReadAndFilterByCountry:@"Sweden"];
//    [self spotifyAddSongs:@[@"spotify:track:2b86QdcYHnO4YRXqfqlmGH", @"spotify:track:3KT0wY2cGC8kDJMGDLx751", @"spotify:track:7gNx6OZkE7z6KHKeKlZ9nO"] toPlaylist:@"Starred_Filtered"];
//    [self echoNestUserTasteprofileRead];
//    NSString *play = @"test88";
//    [self spotifyCreatePlaylist:play];
//    [self spotifyAddSong:@"spotify:track:1STjJ4su0G65hlXryuEh30" toPlaylist:play];
//    [self spotifyAddSong:@"spotify:track:6iqEd2PFZanx8qcynhfE9d" toPlaylist:play];
//    [self spotifyDumpItemsFromStarredPlaylist];
//    [self echoNestCreateUserTasteprofile];
//    [self buildArrayItemsFromStarredPlaylist];
//    [self dumpItemsFromStarredPlaylist];
}


#pragma mark - EchoNest

// TODO: /status function

- (void)echoNestUserTasteprofile
{
    [ENAPIRequest GETWithEndpoint:@"catalog/list"
                    andParameters:nil
               andCompletionBlock:^(ENAPIRequest *request) {
                   for (NSDictionary *aName in request.response[@"response"][@"catalogs"]) {
//                       DLog(@"%@", request.response);
                       if ([[self lastUser] isEqualToString:aName[@"name"]]) {
                           self.userTasteprofile = aName[@"id"];
                           DLog(@"UserTasteprofile is: %@", self.userTasteprofile);
                           return;
                       }
                   }
                   DLog(@"User Tasteprofile not found ):");
                   self.userTasteprofile = nil;
                   [self echoNestUserTasteprofileCreate];
               }];
}

- (void)echoNestUserTasteprofileWithCompletionBlock:(void (^)(NSString *userTasteprofile))completionBlock
{
    /* use with:
    [self echoNestUserTasteprofileWithCompletionBlock:^(NSString *userTasteprofile) {
        DLog(@"%@", userTasteprofile);
    }];
     */
    
    if(!completionBlock)
        return; // Avoid crashs
    
    if (self.userTasteprofile) {
        completionBlock(self.userTasteprofile);
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

- (void)echoNestUserTasteprofileReadAndFilterByCountry:(NSString *)country
{
    // TODO: Only the first 1000 results are considered
    // results parameter can max be 1000
    // if more than 1000 -> new requests and start at 1000
    
    NSDictionary *parameters = @{@"id": self.userTasteprofile, @"bucket": @"artist_location", @"results": @"1000"};
    
    [ENAPIRequest GETWithEndpoint:@"catalog/read"
                    andParameters:parameters
               andCompletionBlock:^(ENAPIRequest *request) {
                   NSMutableSet *aSet = [[NSMutableSet alloc] init];
                   for (NSDictionary *aDict in [request.response valueForKeyPath:@"response.catalog.items"]) {
                       if ([aDict[@"artist_location"] isKindOfClass:[NSDictionary class]]) {
                           if ([[aDict valueForKeyPath:@"artist_location.country"] isEqualToString:country]) {
                               DLog(@"Adding artist %@ to set", aDict[@"artist_name"]);
                               [aSet addObject:aDict];
                           } else {
                               DLog(@"Skipping artist %@", aDict[@"artist_name"]);
                           }
                       }
                   }
                   self.echoNestArtists = aSet;
               }];
}

- (void)echoNestUserTasteprofileLists
{
    [ENAPIRequest GETWithEndpoint:@"catalog/list"
                    andParameters:nil
               andCompletionBlock:^(ENAPIRequest *request) {
                   DLog(@"%@", request.response[@"response"][@"catalogs"]);
               }];
}

- (void)echoNestUserTasteprofileCreate
{
    NSDictionary *parameters = @{@"name": [self lastUser], @"type": @"artist"};
    
    [ENAPIRequest POSTWithEndpoint:@"catalog/create"
                     andParameters:parameters
                andCompletionBlock:^(ENAPIRequest *request) {
                    DLog(@"%@", [NSString stringWithFormat:@"Catalog Create Request\nhttp status code: %ld\nechonest status code: %ld\nechonest status message: %@\nerror message: %@\nid: %@\n",
                                 NSIntToLong(request.httpResponseCode),
                                 NSIntToLong(request.echonestStatusCode),
                                 request.echonestStatusMessage,
                                 request.errorMessage,
                                 (NSString  *)[request.response valueForKeyPath:@"response.id"]
                                 ]);
                    if (request.echonestStatusCode) {
                        // userTasteprofile existed, returning existing ID
                        __block NSString *lastWord = nil;
                        NSString *aString = request.echonestStatusMessage;
                        
                        [aString enumerateSubstringsInRange:NSMakeRange(0, [aString length])
                                                    options:NSStringEnumerationByWords | NSStringEnumerationReverse
                                                 usingBlock:^(NSString *substring, NSRange subrange, NSRange enclosingRange, BOOL *stop) {
                                                     lastWord = substring;
                                                     *stop = YES;
                                                 }];
                        
                        DLog(@"userTasteprofile: %@", lastWord);
                        
                        self.userTasteprofile = lastWord;
                    } else {
                        // no userTasteprofile existed, we just created a new one
                        NSString *catalogId = (NSString *)[request.response valueForKeyPath:@"response.id"];
                        self.userTasteprofile = catalogId;
                    }
                }];
}

- (void)echoNestUserTasteprofileDelete
{
    if (!self.userTasteprofile) return;
    
    NSDictionary *parameters = @{@"id": self.userTasteprofile};
    
    [ENAPIRequest POSTWithEndpoint:@"catalog/delete"
                     andParameters:parameters
                andCompletionBlock:^(ENAPIRequest *request) {
         DLog(@"%@", [NSString stringWithFormat:@"Catalog Delete Request\nhttp status code: %ld\nechonest status code: %ld\nechonest status message: %@\nerror message: %@\nid: %@\n",
                      NSIntToLong(request.httpResponseCode),
                      NSIntToLong(request.echonestStatusCode),
                      request.echonestStatusMessage,
                      request.errorMessage,
                      self.userTasteprofile
                      ]);
     }];
    self.userTasteprofile = nil;
}

- (void)echoNestUserTasteprofileUpdateWithData:(NSArray *)data
{
    [self echoNestUserTasteprofileWithCompletionBlock:^(NSString *userTasteprofile) {
        NSDictionary *parameters = @{@"id": userTasteprofile, @"data_type": @"json", @"data": [ENAPI encodeArrayAsJSON:data]};
        
        [ENAPIRequest POSTWithEndpoint:@"catalog/update"
                         andParameters:parameters
                    andCompletionBlock:^(ENAPIRequest *request) {
                        DLog(@"Reqeust.response:\n%@", request.response);
                        self.userTicket = (NSString *)[request.response valueForKeyPath:@"response.ticket"];
                    }];
    }];
}

#pragma mark - Spotify

- (void)spotifyBuildArrayOfItemsFromStarredPlaylist
{
    [SPAsyncLoading waitUntilLoaded:[SPSession sharedSession] timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedession, NSArray *notLoadedSession) {
        
        DLog(@"Session loaded");
        
        [SPAsyncLoading waitUntilLoaded:[SPSession sharedSession].starredPlaylist timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedPlaylists, NSArray *notLoadedPlaylists) {
            
            DLog(@"Starred Playlist loaded: %@", [SPSession sharedSession].starredPlaylist);
            
            NSArray *playlistItems = [loadedPlaylists valueForKeyPath:@"@unionOfArrays.items"];
            NSArray *tracks = [self tracksFromPlaylistItems:playlistItems];
            
            [SPAsyncLoading waitUntilLoaded:tracks timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedTracks, NSArray *notLoadedTracks) {
                
                DLog(@"%@ of %@ tracks loaded.", [NSNumber numberWithInteger:loadedTracks.count], [NSNumber numberWithInteger:loadedTracks.count + notLoadedTracks.count]);

                NSMutableArray *allArtists = [[NSMutableArray alloc] init];
                SPTrack *anTrack;
                SPArtist *aArtist;
                NSString *aURL;
                int i = 0;
                int j = 0;
                for (anTrack in tracks) {
                    i++;
                    if (!anTrack.artists) {
                        DLog(@"Error: Track is nil");
                        continue;
                    }
                    for (aArtist in anTrack.artists) {
                        aURL = [self spotifyString:[aArtist.spotifyURL absoluteString]];
                        [allArtists addObject:@{@"item": @{@"item_id": [aURL stringByReplacingOccurrencesOfString:@":" withString:@""], @"artist_id": aURL}}];
                    }
                    j++;
                }
                
                //        DLog(@"%@", allSongs);
                DLog(@"Total items processed      : %d", i);
                DLog(@"Total that were nil        : %d", i - j);
                DLog(@"Total number of artists    : %lu", NSUIntToLong([allArtists count]));
                NSArray *returnArray = [NSArray arrayWithArray:[[NSSet setWithArray:allArtists] allObjects]];
                DLog(@"Duplicates removed         : %lu", NSUIntToLong([returnArray count]));
                
                [self echoNestUserTasteprofileUpdateWithData:returnArray];
            }];
        }];
    }];
}

- (void)spotifyDumpItemsFromStarredPlaylist
{
    [SPAsyncLoading waitUntilLoaded:[SPSession sharedSession] timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedession, NSArray *notLoadedSession) {
        
        [SPAsyncLoading waitUntilLoaded:[SPSession sharedSession].starredPlaylist timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedItems, NSArray *notLoadedItems) {
            
            DLog(@"starredPlaylist: %@", [SPSession sharedSession].starredPlaylist);
            
            NSArray *tracks = [self tracksFromPlaylistItems:[SPSession sharedSession].starredPlaylist.items];
            
            [SPAsyncLoading waitUntilLoaded:tracks timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedTracks, NSArray *notLoadedTracks) {
                for (SPTrack *aTrack in tracks) {
                    DLog(@"%@ - %@", [aTrack.artists description], aTrack.name);
                }
            }];
        }];
    }];
}

- (void)spotifyCreatePlaylist:(NSString *)playlistName
{
    [SPAsyncLoading waitUntilLoaded:[SPSession sharedSession] timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedession, NSArray *notLoadedSession) {
        
        SPPlaylistContainer *container = [SPSession sharedSession].userPlaylists;
        
        [SPAsyncLoading waitUntilLoaded:container timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedContainers, NSArray *notLoadedContainers) {
            [container createPlaylistWithName:playlistName callback:^(SPPlaylist *createdPlaylist) {
                DLog(@"Playlist: %@ created", playlistName);
            }];
        }];
    }];
}

- (void)spotifyAddSongs:(NSArray *)songs toPlaylist:(NSString *)playlistName
{
    void (^addSongsToPlaylist)(SPPlaylist *, NSArray *) = ^(SPPlaylist *thePlaylist, NSArray *songs) {
        for (NSString *aSong in songs) {
            DLog(@"Try to add song: %@ to %@", aSong, thePlaylist.name);
            [SPTrack trackForTrackURL:[NSURL URLWithString:aSong] inSession:[SPSession sharedSession] callback:^(SPTrack *aTrack) {
                [thePlaylist addItem:aTrack atIndex:0 callback:^(NSError *error) {
                    if (error) {
                        DLog(@"Couln't add track %@", aTrack.name);
                        DLog(@"%@", error);
                    } else {
                        DLog(@"Track %@ successfully added", aTrack.name);
                    }
                }];
            }];
        }
    };
    
    [SPAsyncLoading waitUntilLoaded:[SPSession sharedSession] timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedession, NSArray *notLoadedSession) {
        SPPlaylistContainer *container = [SPSession sharedSession].userPlaylists;
        [SPAsyncLoading waitUntilLoaded:container timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedContainers, NSArray *notLoadedContainers) {
            
            NSMutableArray *playlists = [NSMutableArray array];
			[playlists addObject:[SPSession sharedSession].starredPlaylist];
			[playlists addObject:[SPSession sharedSession].inboxPlaylist];
			[playlists addObjectsFromArray:[SPSession sharedSession].userPlaylists.flattenedPlaylists];
            
			[SPAsyncLoading waitUntilLoaded:playlists timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedPlaylists, NSArray *notLoadedPlaylists) {
                SPPlaylist *addItemsToThisPlaylist;
                for (SPPlaylist *aPlaylist in loadedPlaylists) {
                    if ([aPlaylist.name isEqualToString:playlistName]) {
                        DLog(@"Found playlist with name %@", playlistName);
                        addItemsToThisPlaylist = aPlaylist;
                        addSongsToPlaylist(addItemsToThisPlaylist, songs);
                        break;
                    }
                }
                // no playlist found so we create a new one and add songs to it
                if (!addItemsToThisPlaylist) {
                    [container createPlaylistWithName:playlistName callback:^(SPPlaylist *createdPlaylist) {
                        [SPAsyncLoading waitUntilLoaded:createdPlaylist timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedPlaylist, NSArray *notLoadedPlaylist) {
                            DLog(@"Playlist %@ created (%@)", playlistName, createdPlaylist.name);
                            addSongsToPlaylist(createdPlaylist, songs);
                        }];
                    }];
                }
            }];
        }];
    }];
}

- (void)spotifyIterateOverAllTracksIn:(SPPlaylist *)playlist withCompletionBlock:(void (^)(SPTrack *item))completionBlock
{
    [SPAsyncLoading waitUntilLoaded:playlist timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedPlaylist, NSArray *notLoadedPlaylist) {
        
    }];
    // iterate over all items in e.g. starred playlist
    // check if aItem is in the list of e.g. swedish artists
}

#pragma mark - Helper

- (NSString *)lastUser
{
    return [[NSUserDefaults standardUserDefaults] valueForKey:@"SpotifyUsers"][@"LastUser"];
}

- (NSString *)spotifyString:(NSString *)string
{
    return [string stringByReplacingOccurrencesOfString:@"spotify" withString:@"spotify-WW"];
}

- (NSString *)unSpotifyString:(NSString *)string
{
    return [string stringByReplacingOccurrencesOfString:@"spotify-WW" withString:@"spotify"];
}

-(NSArray *)tracksFromPlaylistItems:(NSArray *)items
{
    NSMutableArray *tracks = [NSMutableArray arrayWithCapacity:items.count];
    
    for (SPPlaylistItem *anItem in items) {
        if (anItem.itemClass == [SPTrack class]) {
            [tracks addObject:anItem.item];
        }
    }
    
    return [NSArray arrayWithArray:tracks];
}

@end
