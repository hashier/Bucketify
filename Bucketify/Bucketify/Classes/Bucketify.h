//
//  Bucketify.h
//  Bucketify
//
//  Created by Christopher Loessl on 29/11/13.
//  Copyright (c) 2013 Christopher Loessl. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Bucketify : NSObject

@property (strong, readonly, nonatomic) NSString *status;

- (void)filterPlaylistName:(NSString *)playlistName byCountry:(NSString *)country toPlaylistName:(NSString *)toPlaylistName;
- (void)filterPlaylistName:(NSString *)playlistName byGenre:(NSString *)genre toPlaylistName:(NSString *)toPlaylistName;
- (void)countSongsInPlaylist:(NSString *)playlistName;
- (void)randomiseInPlaylist:(NSString *)playlistName toPlaylistName:(NSString *)toPlaylistName;

@end
