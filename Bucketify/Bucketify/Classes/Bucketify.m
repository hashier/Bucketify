//
//  Bucketify.m
//  Bucketify
//
//  Created by Christopher Loessl on 29/11/13.
//  Copyright (c) 2013 Christopher Loessl. All rights reserved.
//

#import "Bucketify.h"
#import "common.h"
#import "ENAPI.h"
#import "EchoNestTicket.h"
#import "config.h"

@interface Bucketify ()

@property (strong, nonatomic) NSString *userTasteProfileID;
@property (strong, readwrite, nonatomic) NSString *status;

@end

@implementation Bucketify

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

- (void)filterPlaylistName:(NSString *)playlistName byCountry:(NSString *)country toPlaylist:(NSString *)toPlaylist {
    [self echoNestUseNewUserArtistTasteProfileWithCompletionBlock:^(NSString *userTasteProfileID) {
        [self spotifyGetTracksFromPlaylistName:playlistName then:^(NSArray *tracks) {
            [self echoNestUpdateArtistUserTasteProfileID:userTasteProfileID withTracks:tracks then:^{
                [self echoNestReadUserTasteProfileID:userTasteProfileID andFilterTracks:tracks byCountry:country then:^(NSArray *filtered) {
                    [self spotifyAddSongURLs:filtered toPlaylistName:toPlaylist then:^{
                        [self echoNestDeleteUserTasteProfileID:userTasteProfileID then:^{
                            self.status = @"All done, check your filtered playlist in Spotify";
                        }];
                    }];
                }];
            }];
        }];
    }];
}

- (void)countSongsInPlaylist:(NSString *)playlistName {
    [self spotifyGetTracksFromPlaylistName:playlistName then:^(NSArray *tracks) {
        self.status = [NSString stringWithFormat:@"All done, found %lu songs", NSUIntToLong([tracks count])];
    }];
}

#pragma mark - EchoNest

- (void)echoNestUseNewUserArtistTasteProfileWithCompletionBlock:(void (^)(NSString *filtered))completionBlock {
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

- (void)echoNestDeleteUserTasteProfileID:(NSString *)userTasteProfileID then:(void (^)())completionBlock
{
    DLog(@"Deleting TasteProfileID: %@", userTasteProfileID);

    self.status = @"Cleaning up";
    
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

#pragma mark - Spotify

- (void)spotifyGetTracksFromPlaylistName:(NSString *)name then:(void (^)(NSArray *items))completionBlock {
    self.status = @"Waiting for Spotify information";

    [SPAsyncLoading waitUntilLoaded:[SPSession sharedSession] timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedSession, NSArray *notLoadedSession) {

        [SPAsyncLoading waitUntilLoaded:[SPSession sharedSession].userPlaylists timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedContainers, NSArray *notLoadedContainers) {

            DLog(@"Session loaded");

            NSMutableArray *playlists = [NSMutableArray array];
            if ([name isEqualToString:@"Starred"]) {
                [playlists addObject:[SPSession sharedSession].starredPlaylist];
            } else {
                [playlists addObjectsFromArray:[SPSession sharedSession].userPlaylists.flattenedPlaylists];
            }

            [SPAsyncLoading waitUntilLoaded:playlists timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedPlaylists, NSArray *notLoadedPlaylists) {

                DLog(@"Playlist(s) loaded    : %@", loadedPlaylists);
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
                    DLog(@"Warning: Didn't find the given playlist's name (%@) or no songs in it", name);
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
    
    void (^addSongsToPlaylist)(SPPlaylist *, NSArray *) = ^(SPPlaylist *thePlaylist, NSArray *songToAdd) {
        DLog(@"Start to add %lu songToAdd", NSUIntToLong([songToAdd count]));
        for (NSString *aSong in songToAdd) {
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

#pragma mark - Helper

- (NSString *)lastUser
{
    return [[NSUserDefaults standardUserDefaults] valueForKey:@"SpotifyUsers"][@"LastUser"];
}

- (NSString *)spotifyString:(NSString *)string
{
    return [string stringByReplacingOccurrencesOfString:@"spotify" withString:@"spotify-WW"];
}

/*
- (NSString *)unSpotifyString:(NSString *)string
{
    return [string stringByReplacingOccurrencesOfString:@"spotify-WW" withString:@"spotify"];
}
*/

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
