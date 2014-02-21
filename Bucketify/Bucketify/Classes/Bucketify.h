//
//  Bucketify.h
//  Bucketify
//
//  Created by Christopher Loessl on 29/11/13.
//  Copyright (c) 2013 Christopher Loessl. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CocoaLibSpotify.h"

@interface Bucketify : NSObject

@property (strong, readonly, nonatomic) NSString *status;

- (void)filterPlaylistName:(NSString *)playlistName byCountry:(NSString *)country toPlaylist:(NSString *)toPlaylist;
- (void)countSongsInPlaylist:(NSString *)playlistName;

@end
