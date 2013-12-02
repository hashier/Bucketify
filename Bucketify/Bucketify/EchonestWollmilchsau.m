//
//  EchonestWollmilchsau.m
//  Bucketify
//
//  Created by Christopher Loessl on 29/11/13.
//  Copyright (c) 2013 Christopher Loessl. All rights reserved.
//

#import "EchonestWollmilchsau.h"
#import "common.h"
#import "ENAPI.h"
#import "EchoNestTicket.h"

@interface EchonestWollmilchsau ()

@property (strong, nonatomic) NSString *userTasteprofileID;
@property (strong, readwrite, nonatomic) NSString *status;

@end

@implementation EchonestWollmilchsau

- (id)init
{
    self = [super init];
    if (self) {
        [ENAPIRequest setApiKey:@"***REMOVED***"];
    }
    return self;
}

#pragma mark - Public

- (void)filerStarredItemsByCountry:(NSString *)country
{
    [self echoNestUserTasteprofileUseNewWithCompletionBlock:^(NSString *userTasteprofileID) {
        [self spotifyStarredPlaylistToEchoNestTasteprofileID:userTasteprofileID then:^{
            [self echoNestUserTasteprofileID:userTasteprofileID readStarredAndFilterByCountry:country then:^{
                self.status = @"All done, check your Starred_Filtered playlist";
                [self echoNestUserTasteprofileID:self.userTasteprofileID deleteWithBlock:nil];
            }];
        }];
    }];
}

#pragma mark - EchoNest

- (void)echoNestUserTasteprofileLists
{
    [ENAPIRequest GETWithEndpoint:@"catalog/list"
                    andParameters:nil
               andCompletionBlock:^(ENAPIRequest *request) {
                   DLog(@"%@", request.response[@"response"][@"catalogs"]);
               }];
}

- (void)echoNestUserTasteprofileUseNewWithCompletionBlock:(void (^)(NSString *userTasteprofileID))completionBlock
{
    [ENAPIRequest GETWithEndpoint:@"catalog/list"
                    andParameters:nil
               andCompletionBlock:^(ENAPIRequest *request) {
                   for (NSDictionary *aName in request.response[@"response"][@"catalogs"]) {
                       if ([[self lastUser] isEqualToString:aName[@"name"]]) {
                           self.userTasteprofileID = aName[@"id"];
                           DLog(@"UserTasteprofileID is: %@", self.userTasteprofileID);
                           [self echoNestUserTasteprofileID:self.userTasteprofileID deleteWithBlock:^{
                               [self echoNestUserTasteprofileUseWithCompletionBlock:completionBlock];
                           }];
                           return;
                       }
                   }
                   DLog(@"User Tasteprofile not found ):");
                   self.userTasteprofileID = nil;
                   [self echoNestUserTasteprofileUseWithCompletionBlock:completionBlock];
               }];
}

- (void)echoNestUserTasteprofileUseWithCompletionBlock:(void (^)(NSString *userTasteprofileID))completionBlock
{
    self.status = @"Setting up EchoNest profile";
    
    if (self.userTasteprofileID) {
        if (completionBlock) completionBlock(self.userTasteprofileID);
    } else {
        NSDictionary *parameters = @{@"name": [self lastUser], @"type": @"artist"};
        
        [ENAPIRequest POSTWithEndpoint:@"catalog/create"
                         andParameters:parameters
                    andCompletionBlock:^(ENAPIRequest *request) {
                        if (request.echonestStatusCode) {
                            // userTasteprofileID existed, returning existing ID
                            __block NSString *lastWord = nil;
                            NSString *aString = request.echonestStatusMessage;
                            [aString enumerateSubstringsInRange:NSMakeRange(0, [aString length])
                                                        options:NSStringEnumerationByWords | NSStringEnumerationReverse
                                                     usingBlock:^(NSString *substring, NSRange subrange, NSRange enclosingRange, BOOL *stop) {
                                                         lastWord = substring;
                                                         *stop = YES;
                                                     }];
                            DLog(@"userTasteprofileID: %@", lastWord);
                            self.userTasteprofileID = lastWord;
                            
                            if (completionBlock) completionBlock(self.userTasteprofileID);
                        } else {
                            // no userTasteprofileID existed, we just created a new one
                            NSString *catalogId = (NSString *)[request.response valueForKeyPath:@"response.id"];
                            self.userTasteprofileID = catalogId;
                            
                            if (completionBlock) completionBlock(self.userTasteprofileID);
                        }
                    }];
    }
}

- (void)echoNestUserTasteprofileID:(NSString *)userTasteprofileID deleteWithBlock:(void (^)())completionBlock
{
    DLog(@"Deleting TasteprofileID: %@", userTasteprofileID);
    
    if (!userTasteprofileID) {
        DLog(@"Error: Tasteprofile is empty");
        return;
    }
    
    NSDictionary *parameters = @{@"id": userTasteprofileID};
    
    [ENAPIRequest POSTWithEndpoint:@"catalog/delete"
                     andParameters:parameters
                andCompletionBlock:^(ENAPIRequest *request) {
                    DLog(@"%@", [NSString stringWithFormat:@"Catalog Delete Request\nhttp status code: %ld\nechonest status code: %ld\nechonest status message: %@\nerror message: %@\nid: %@\nWhole request: %@",
                                 NSIntToLong(request.httpResponseCode),
                                 NSIntToLong(request.echonestStatusCode),
                                 request.echonestStatusMessage,
                                 request.errorMessage,
                                 self.userTasteprofileID,
                                 request.response
                                 ]);
                    if (completionBlock) completionBlock();
                }];
    if ([userTasteprofileID isEqualToString:self.userTasteprofileID]) {
        self.userTasteprofileID = nil;
    }
}

- (void)echoNestUserTasteprofileID:(NSString *)userTasteprofileID updateWithData:(NSArray *)data then:(void (^)())completionBlock
{
    self.status = @"Sending information to Echonest";
    
    NSDictionary *parameters = @{@"id": userTasteprofileID, @"data_type": @"json", @"data": [ENAPI encodeArrayAsJSON:data]};
    
    [ENAPIRequest POSTWithEndpoint:@"catalog/update"
                     andParameters:parameters
                andCompletionBlock:^(ENAPIRequest *request) {
                    NSString *aTicketString = [request.response valueForKeyPath:@"response.ticket"];
                    EchoNestTicket *aTicket = [[EchoNestTicket alloc] initWithTicket:aTicketString];
                    [SPAsyncLoading waitUntilLoaded:aTicket timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedTicket, NSArray *notLoadedTicket) {
                        self.status = @"Information sent";
                        DLog(@"\nTickets finished: %@\nTickets not finished: %@", loadedTicket, notLoadedTicket);
                        if (completionBlock) completionBlock();
                    }];
                }];
}

- (void)echoNestUserTasteprofileID:(NSString *)userTasteprofileID readStarredAndFilterByCountry:(NSString *)country then:(void (^)())completionBlock
{
    // TODO: Only the first 1000 results are considered
    // results parameter can max be 1000
    // if more than 1000 -> new requests and start at 1000
    
    self.status = @"Getting information back from Echonest";
    
    NSDictionary *parameters = @{@"id": userTasteprofileID, @"bucket": @"artist_location", @"results": @"1000"};
    
    [ENAPIRequest GETWithEndpoint:@"catalog/read"
                    andParameters:parameters
               andCompletionBlock:^(ENAPIRequest *request) {
                   NSMutableSet *aSet = [[NSMutableSet alloc] init];
                   for (NSDictionary *aDict in [request.response valueForKeyPath:@"response.catalog.items"]) {
                       if ([aDict[@"artist_location"] isKindOfClass:[NSDictionary class]]) {
                           DLog(@"Current artists informations: %@", aDict);
                           if ([[aDict valueForKeyPath:@"artist_location.country"] isKindOfClass:[NSString class]]) {
                               if ([[aDict valueForKeyPath:@"artist_location.country"] isEqualToString:country]) {
                                   DLog(@"Adding artist %@ to set", aDict[@"artist_name"]);
                                   [aSet addObject:[aDict valueForKeyPath:@"request.artist_id"]];
                               } else {
                                   DLog(@"Skipping artist %@", aDict[@"artist_name"]);
                               }
                           }
                       }
                   }
                   
                   self.status = @"Matching informations";

                   [SPAsyncLoading waitUntilLoaded:[SPSession sharedSession] timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedession, NSArray *notLoadedSession) {
                       
                       DLog(@"Session loaded");
                       
                       [SPAsyncLoading waitUntilLoaded:[SPSession sharedSession].starredPlaylist timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedPlaylists, NSArray *notLoadedPlaylists) {
                           
                           DLog(@"Starred Playlist loaded: %@", [SPSession sharedSession].starredPlaylist);
                           
                           NSArray *playlistItems = [loadedPlaylists valueForKeyPath:@"@unionOfArrays.items"];
                           NSArray *tracks = [self tracksFromPlaylistItems:playlistItems];
                           
                           [SPAsyncLoading waitUntilLoaded:tracks timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedTracks, NSArray *notLoadedTracks) {
                               NSMutableArray *tracksToAddToSpotify = [[NSMutableArray alloc] init];
                               DLog(@"Tracks to check: %lu", NSUIntToLong([tracks count]));
                               for (SPTrack *aTrack in tracks) {
                                   for (SPArtist *anArtist in aTrack.artists) {
                                       if ([aSet containsObject:[self spotifyString:[anArtist.spotifyURL absoluteString]]]) {
                                           [tracksToAddToSpotify addObject:[aTrack.spotifyURL absoluteString]];
                                           break;
                                       }
                                   }
                               }
                               DLog(@"We found %lu tracks after filtering, now add them.", NSUIntToLong([tracksToAddToSpotify count]));
                               [self spotifyAddSongURLs:tracksToAddToSpotify toPlaylistName:@"Starred_Filtered" then:completionBlock];
                           }];
                       }];
                   }];
               }];
}

#pragma mark - Spotify

- (void)spotifyStarredPlaylistToEchoNestTasteprofileID:(NSString *)userTasteprofileID then:(void (^)())completionBlock
{
    self.status = @"Waiting for Spotify information";
    
    [SPAsyncLoading waitUntilLoaded:[SPSession sharedSession] timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedession, NSArray *notLoadedSession) {
        
        DLog(@"Session loaded");
        
		[SPAsyncLoading waitUntilLoaded:[SPSession sharedSession].userPlaylists timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedContainers, NSArray *notLoadedContainers) {
            
            DLog(@"User Playlists loaded");
            
            [SPAsyncLoading waitUntilLoaded:[SPSession sharedSession].starredPlaylist timeout:35.0 then:^(NSArray *loadedPlaylists, NSArray *notLoadedPlaylists) {
                
                if ([loadedPlaylists count] != 1) {
                    self.status = @"Loading your playlist timed out. Check internet connectivity";
                    return;
                }
                
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
                    
                    [self echoNestUserTasteprofileID:userTasteprofileID updateWithData:returnArray then:completionBlock];
                }];
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

- (void)spotifyAddSongURLs:(NSArray *)songs toPlaylistName:(NSString *)playlistName then:(void (^)())completionBlock
{
    // Why is this in a block and not in a function?
    // If this was a function I should make sure (again) that everything is loaded just to be sure no one
    // else calls this function and hasn't waited until meta data is loaded
    //
    // so that this can not happen -> this is not a function but a block
    //
    // The alternative would by handing over a (loaded) SPPlaylist instead of a Playlist name.
    
    self.status = @"Adding filtered songs to Spotify";
    
    void (^addSongsToPlaylist)(SPPlaylist *, NSArray *) = ^(SPPlaylist *thePlaylist, NSArray *songs) {
        DLog(@"Start to add %lu songs", NSUIntToLong([songs count]));
        for (NSString *aSong in songs) {
            DLog(@"Try to add song: %@ to %@", aSong, thePlaylist.name);
            [SPTrack trackForTrackURL:[NSURL URLWithString:aSong] inSession:[SPSession sharedSession] callback:^(SPTrack *aTrack) {
                [thePlaylist addItem:aTrack atIndex:0 callback:^(NSError *error) {
                    if (error) {
                        DLog(@"Error: Couln't add track %@", aTrack.name);
                        DLog(@"%@", error);
                    } else {
                        DLog(@"Track %@ successfully added", aTrack.name);
                    }
                }];
            }];
        }
        if (completionBlock) completionBlock();
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
    // TODO: Do I need this???
    // No functionality yet, obviously!
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
