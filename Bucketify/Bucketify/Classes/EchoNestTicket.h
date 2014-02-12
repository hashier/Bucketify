//
//  EchoNestTicket.h
//  Bucketify
//
//  Created by Christopher Loessl on 29/11/13.
//  Copyright (c) 2013 Christopher Loessl. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CocoaLibSpotify.h"

@interface EchoNestTicket : NSObject <SPAsyncLoading>

@property (strong, nonatomic, readonly) NSString *ticket;
@property (nonatomic, readonly, getter=isLoaded) BOOL loaded;

- (id)initWithTicket:(NSString *)ticket;

@end
