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
#import "config.h"

@interface EchonestWollmilchsau ()

@property (strong, nonatomic) NSString *userTasteProfileID;
@property (strong, readwrite, nonatomic) NSString *status;
@property (strong, readwrite, nonatomic) NSArray *tracks;

@end

@implementation EchonestWollmilchsau

#pragma mark - Init

- (id)init
{
    self = [super init];
    if (self) {
        if ([kEchoNestAPIKey isEqualToString:@""]) {
            UIAlertView *alert =[[UIAlertView alloc ] initWithTitle:@"Key missing"
                                                            message:@"Echonest Key missing; Terminating"
                                                           delegate:self
                                                  cancelButtonTitle:@"Ok"
                                                  otherButtonTitles:nil];
            [alert show];
        } else {
            [ENAPIRequest setApiKey:kEchoNestAPIKey];
        }
    }
    return self;
}

#pragma mark - Public

- (void)filerStarredItemsByCountry:(NSString *)country
{
    [self echoNestUserTasteProfileUseNewWithCompletionBlock:^(NSString *userTasteProfileID) {
        [self spotifyStarredPlaylistToEchoNestTasteProfileID:userTasteProfileID then:^{
            [self echoNestUserTasteProfileID:userTasteProfileID readStarredAndFilterByCountry:country then:^{
                self.status = @"All done, check your Starred_Filtered playlist in Spotify";
                [self echoNestDeleteUserTasteProfileID:userTasteProfileID then:nil];
            }];
        }];
    }];
}

- (void)filerPlaylistName:(NSString *)playlistName byCountry:(NSString *)country toPlaylist:(NSString *)toPlaylist {
    [self echoNestUseNewUserTasteProfileWithCompletionBlock:^(NSString *userTasteProfileID) {
        [self spotifyGetTracksFromPlaylistName:playlistName then:^(NSArray *tracks) {
            [self echoNestUpdateArtistUserTasteProfileID:userTasteProfileID withTracks:tracks then:^{
                [self echoNestReadUserTasteProfileID:userTasteProfileID andFilterTracks:tracks byCountry:country then:^(NSArray *filtered) {
                    [self spotifyAddSongURLs:filtered toPlaylistName:toPlaylist then:^{
                        [self echoNestDeleteUserTasteProfileID:userTasteProfileID then:nil];
                        self.status = @"All done, check your filtered playlist in Spotify";
                    }];
                }];
            }];
        }];
    }];
}

#pragma mark - Refactoring

- (void)echoNestUseNewUserTasteProfileWithCompletionBlock:(void (^)(NSString *filtered))completionBlock {
    if (self.userTasteProfileID) {
        DLog(@"UserTasteProfileID is: %@, going to delete it", self.userTasteProfileID);
        [self echoNestDeleteUserTasteProfileID:self.userTasteProfileID then:^{
            [self echoNestUseArtistUserTasteProfileWithCompletionBlock:completionBlock];
        }];
    } else {
        [ENAPIRequest GETWithEndpoint:@"catalog/list"
                        andParameters:nil
                   andCompletionBlock:^(ENAPIRequest *request) {
                       for (NSDictionary *aName in request.response[@"response"][@"catalogs"]) {
                           if ([[self lastUser] isEqualToString:aName[@"name"]]) {
                               self.userTasteProfileID = aName[@"id"];
                               DLog(@"UserTasteProfileID is: %@, going to delete it", self.userTasteProfileID);
                               [self echoNestDeleteUserTasteProfileID:self.userTasteProfileID then:^{
                                   [self echoNestUseArtistUserTasteProfileWithCompletionBlock:completionBlock];
                               }];
                               return;
                           }
                       }
                       DLog(@"Warning: This should never happen, it's okay, but not good");
                       DLog(@"User TasteProfile not found, don't have to delete it");
                       self.userTasteProfileID = nil;
                       [self echoNestUseArtistUserTasteProfileWithCompletionBlock:completionBlock];
                   }];
    }
}

- (void)echoNestUseArtistUserTasteProfileWithCompletionBlock:(void (^)(NSString *userTasteProfileID))completionBlock {
    self.status = @"Setting up EchoNest profile";

    if (self.userTasteProfileID) {
        if (completionBlock) completionBlock(self.userTasteProfileID);
    } else {
        NSDictionary *parameters = @{@"name": [self lastUser], @"type": @"artist"};

        [ENAPIRequest POSTWithEndpoint:@"catalog/create"
                         andParameters:parameters
                    andCompletionBlock:^(ENAPIRequest *request) {
                        if (request.echonestStatusCode) {
                            // userTasteProfileID existed, returning existing ID
                            __block NSString *lastWord = nil;
                            NSString *aString = request.echonestStatusMessage;
                            [aString enumerateSubstringsInRange:NSMakeRange(0, [aString length])
                                                        options:NSStringEnumerationByWords | NSStringEnumerationReverse
                                                     usingBlock:^(NSString *substring, NSRange subrange, NSRange enclosingRange, BOOL *stop) {
                                                         lastWord = substring;
                                                         *stop = YES;
                                                     }];
                            DLog(@"userTasteProfileID: %@, existed and going to be reused", lastWord);
                            self.userTasteProfileID = lastWord;

                            if (completionBlock) completionBlock(self.userTasteProfileID);
                        } else {
                            // no userTasteProfileID existed, we just created a new one
                            self.userTasteProfileID = (NSString *)[request.response valueForKeyPath:@"response.id"];
                            DLog(@"new userTasteProfileID: %@ created", self.userTasteProfileID);

                            if (completionBlock) completionBlock(self.userTasteProfileID);
                        }
                    }];
    }
}

- (void)spotifyGetTracksFromPlaylistName:(NSString *)name then:(void (^)(NSArray *items))completionBlock {
    self.status = @"Waiting for Spotify information";

    [SPAsyncLoading waitUntilLoaded:[SPSession sharedSession] timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedession, NSArray *notLoadedSession) {

        [SPAsyncLoading waitUntilLoaded:[SPSession sharedSession].userPlaylists timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedContainers, NSArray *notLoadedContainers) {

            DLog(@"Session loaded");

            NSMutableArray *playlists = [NSMutableArray array];
            if ([name isEqualToString:@"Starred"]) {
                [playlists addObject:[SPSession sharedSession].starredPlaylist];
            } else {
                [playlists addObjectsFromArray:[SPSession sharedSession].userPlaylists.flattenedPlaylists];
            }

            [SPAsyncLoading waitUntilLoaded:playlists timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedPlaylists, NSArray *notLoadedPlaylists) {

                DLog(@"Playlist(s) not loaded: %@", notLoadedPlaylists);

                NSArray *tracks;

                // if only one playlist loaded, check if it's the starred one
                // starred one does _not_ have a name, therefore check url
                if ([loadedPlaylists count] == 1) {
                    SPPlaylist *aPlaylist = [loadedPlaylists firstObject];
                    if ([[aPlaylist.spotifyURL absoluteString] rangeOfString:@"starred" options:NSCaseInsensitiveSearch].location != NSNotFound) {
                        tracks = [self tracksFromPlaylistItems:aPlaylist.items];
                    }
                }
                // iterate through all loaded playlists and check the name
                for (SPPlaylist *aPlaylist in loadedPlaylists) {
                    DLog(@"Looking at name: %@ url: %@", aPlaylist.name, aPlaylist.spotifyURL);
                    if ([aPlaylist.name isEqualToString:name]) {
                        tracks = [self tracksFromPlaylistItems:aPlaylist.items];
                        break;
                    }
                }

                if ([tracks count] == 0) {
                    DLog(@"Warning: Didn't find the given playlist's name or no songs in it");
                    self.status = @"Didn't find the given playlist or no songs in it";
                    return;
                }

                [SPAsyncLoading waitUntilLoaded:tracks timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedTracks, NSArray *notLoadedTracks) {

                    DLog(@"%@ of %@ tracks loaded.", [NSNumber numberWithInteger:loadedTracks.count], [NSNumber numberWithInteger:loadedTracks.count + notLoadedTracks.count]);

                    if (completionBlock) completionBlock(loadedTracks);
                }];
            }];
        }];
    }];
}

- (void)echoNestUpdateArtistUserTasteProfileID:(NSString *)id withTracks:(NSArray *)tracks then:(void (^)())completionBlock {
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

    // TODO: Maybe split up the data in multiple requests?
    DLog(@"Sending information to Echonest");
    self.status = @"Sending information to Echonest";

    NSDictionary *parameters = @{@"id": id, @"data_type": @"json", @"data": [ENAPI encodeArrayAsJSON:returnArray]};

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

- (void)echoNestReadUserTasteProfileID:(NSString *)id andFilterTracks:(NSArray *)tracks byCountry:(NSString *)country then:(void (^)(NSArray *filtered))completionBlock {
    // TODO: Only the first 1000 results are considered
    // results parameter can max be 1000
    // if more than 1000 -> new requests and start at 1000

    self.status = @"Getting information back from Echonest";

    NSDictionary *parameters = @{@"id": id, @"bucket": @"artist_location", @"results": @"1000"};

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
                   if (completionBlock) completionBlock(tracksToAddToSpotify);
               }];
}

#pragma mark - EchoNest

- (void)echoNestDumpUserTasteProfileLists
{
    [ENAPIRequest GETWithEndpoint:@"catalog/list"
                    andParameters:nil
               andCompletionBlock:^(ENAPIRequest *request) {
                   DLog(@"%@", request.response[@"response"][@"catalogs"]);
               }];
}

- (void)echoNestUserTasteProfileUseNewWithCompletionBlock:(void (^)(NSString *userTasteProfileID))completionBlock
{
    [ENAPIRequest GETWithEndpoint:@"catalog/list"
                    andParameters:nil
               andCompletionBlock:^(ENAPIRequest *request) {
                   for (NSDictionary *aName in request.response[@"response"][@"catalogs"]) {
                       if ([[self lastUser] isEqualToString:aName[@"name"]]) {
                           self.userTasteProfileID = aName[@"id"];
                           DLog(@"UserTasteProfileID is: %@, going to delete it", self.userTasteProfileID);
                           [self echoNestDeleteUserTasteProfileID:self.userTasteProfileID then:^{
                               [self echoNestUserTasteProfileUseWithCompletionBlock:completionBlock];
                           }];
                           return;
                       }
                   }
                   DLog(@"User TasteProfile not found, don't have to delete it");
                   self.userTasteProfileID = nil;
                   [self echoNestUserTasteProfileUseWithCompletionBlock:completionBlock];
               }];
}

- (void)echoNestUserTasteProfileUseWithCompletionBlock:(void (^)(NSString *userTasteProfileID))completionBlock
{
    self.status = @"Setting up EchoNest profile";
    
    if (self.userTasteProfileID) {
        if (completionBlock) completionBlock(self.userTasteProfileID);
    } else {
        NSDictionary *parameters = @{@"name": [self lastUser], @"type": @"artist"};
        
        [ENAPIRequest POSTWithEndpoint:@"catalog/create"
                         andParameters:parameters
                    andCompletionBlock:^(ENAPIRequest *request) {
                        if (request.echonestStatusCode) {
                            // userTasteProfileID existed, returning existing ID
                            __block NSString *lastWord = nil;
                            NSString *aString = request.echonestStatusMessage;
                            [aString enumerateSubstringsInRange:NSMakeRange(0, [aString length])
                                                        options:NSStringEnumerationByWords | NSStringEnumerationReverse
                                                     usingBlock:^(NSString *substring, NSRange subrange, NSRange enclosingRange, BOOL *stop) {
                                                         lastWord = substring;
                                                         *stop = YES;
                                                     }];
                            DLog(@"userTasteProfileID: %@, existed and going to be reused", lastWord);
                            self.userTasteProfileID = lastWord;
                            
                            if (completionBlock) completionBlock(self.userTasteProfileID);
                        } else {
                            // no userTasteProfileID existed, we just created a new one
                            self.userTasteProfileID = (NSString *)[request.response valueForKeyPath:@"response.id"];
                            DLog(@"new userTasteProfileID: %@ created", self.userTasteProfileID);

                            if (completionBlock) completionBlock(self.userTasteProfileID);
                        }
                    }];
    }
}

- (void)echoNestDeleteUserTasteProfileID:(NSString *)userTasteProfileID then:(void (^)())completionBlock
{
    DLog(@"Deleting TasteProfileID: %@", userTasteProfileID);
    
    if (!userTasteProfileID) {
        DLog(@"Error: TasteProfile is empty");
        return;
    }
    
    NSDictionary *parameters = @{@"id": userTasteProfileID};
    
    [ENAPIRequest POSTWithEndpoint:@"catalog/delete"
                     andParameters:parameters
                andCompletionBlock:^(ENAPIRequest *request) {
                    DLog(@"%@", [NSString stringWithFormat:@"Catalog Delete Request\nhttp status code: %ld\nechonest status code: %ld\nechonest status message: %@\nerror message: %@\nid: %@\nWhole request: %@",
                                 NSIntToLong(request.httpResponseCode),
                                 NSIntToLong(request.echonestStatusCode),
                                 request.echonestStatusMessage,
                                 request.errorMessage,
                                 self.userTasteProfileID,   // pointer into heap
                                                            // so this will be null!
                                                            //
                                                            // stacks are captured/saved/remembered for blocks, but not
                                                            // pointers into heap
                                                            // well the pointer address is,
                                                            // but not what's saved there
                                 request.response
                                 ]);
                    DLog(@"Clean up (userTasteProfileID: %@ deleted) done", userTasteProfileID);
                    if (completionBlock) completionBlock();
                }];
    if ([userTasteProfileID isEqualToString:self.userTasteProfileID]) {
        self.userTasteProfileID = nil;
    }
}

- (void)echoNestUserTasteProfileID:(NSString *)userTasteProfileID updateWithData:(NSArray *)data then:(void (^)())completionBlock
{
    // TODO: Maybe split up the data in multiple requests?
    
    DLog(@"Sending information to Echonest");
    self.status = @"Sending information to Echonest";
    
    NSDictionary *parameters = @{@"id": userTasteProfileID, @"data_type": @"json", @"data": [ENAPI encodeArrayAsJSON:data]};
    
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

- (void)echoNestUserTasteProfileID:(NSString *)userTasteProfileID readStarredAndFilterByCountry:(NSString *)country then:(void (^)())completionBlock
{
    // TODO: Only the first 1000 results are considered
    // results parameter can max be 1000
    // if more than 1000 -> new requests and start at 1000
    
    self.status = @"Getting information back from Echonest";
    
    NSDictionary *parameters = @{@"id": userTasteProfileID, @"bucket": @"artist_location", @"results": @"1000"};
    
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

- (void)spotifyStarredPlaylistToEchoNestTasteProfileID:(NSString *)userTasteProfileID then:(void (^)())completionBlock
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
                            //TODO: Make method for stripping chars
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

                    [self echoNestUserTasteProfileID:userTasteProfileID updateWithData:returnArray then:completionBlock];
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
    // ???: Do I need this???
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
