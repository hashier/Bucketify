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

@property (strong, nonatomic) NSString *ticket;
- (id)initWithTicket:(NSString *)ticket;

@end
