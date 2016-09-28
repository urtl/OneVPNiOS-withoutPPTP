//
//  XPCConnection.h
//  OneVPN
//
//  Created by Aleksey Dvoryanskiy on 8/17/16.
//  Copyright © 2016 OneVPN. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Xpc.pbobjc.h"

extern NSString *kXPCServiceIdentifier;

@interface XPCConnection : NSObject

@property (nonatomic, assign, readonly) BOOL isConnected;

+ (instancetype)sharedConnection;

- (BOOL)connect;
- (BOOL)disconnect;

- (void)sendRequest:(XPCRequest *)request withCompletion:(void (^)(XPCResponse *response))completion;

@end
