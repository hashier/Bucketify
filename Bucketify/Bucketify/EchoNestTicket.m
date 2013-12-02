//
//  EchoNestTicket.m
//  Bucketify
//
//  Created by Christopher Loessl on 29/11/13.
//  Copyright (c) 2013 Christopher Loessl. All rights reserved.
//

#import "EchoNestTicket.h"
#import "ENAPI.h"
#import "common.h"

@interface EchoNestTicket ()

@property (nonatomic, readwrite, getter=isLoaded) BOOL loaded;
@property (strong, nonatomic) NSString *userTicket;
@property (weak, nonatomic) NSTimer *timer;

@end

@implementation EchoNestTicket

#define updateTicketInterval 2.5

- (id)initWithTicket:(NSString *)ticket
{
    self = [super init];
    if (self) {
        self.userTicket = ticket;
        
        self.timer = [NSTimer scheduledTimerWithTimeInterval:updateTicketInterval
                                             target:self
                                           selector:@selector(updateTicket:)
                                           userInfo:nil
                                            repeats:YES];
    }
    return self;
}

- (void)updateTicket:(NSTimer *)timer
{
    NSDictionary *parameters = @{@"ticket": self.userTicket};
    
    NSLog(@"Update ticket request");
    [ENAPIRequest GETWithEndpoint:@"catalog/status"
                    andParameters:parameters
               andCompletionBlock:^(ENAPIRequest *request) {
                   DLog(@"Ticket status: %@", request.response);
                   if ([request.response[@"response"][@"percent_complete"] integerValue] == 100) {
                       DLog(@"Ticket 100%%");
                       self.loaded = YES;
                       [self.timer invalidate];
                       self.timer = nil;
                   }
               }];
}

@end
