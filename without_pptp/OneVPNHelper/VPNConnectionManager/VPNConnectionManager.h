//
//  VPNConnectionManager.h
//  OneVPN
//
//  Created by Aleksey Dvoryanskiy on 8/21/16.
//  Copyright © 2016 OneVPN. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Xpc.pbobjc.h"

@interface VPNConnectionManager : NSObject

@property (nonatomic, strong) NSString *ovpnPath;
@property (nonatomic, strong) NSString *pppdPath;

@property (nonatomic, strong, readonly) Server *connectedServer;
@property (nonatomic, assign, readonly) ExtStatus extStatus;

+ (instancetype)sharedManager;

- (bool)isConnected;

- (bool)connectToServer:(Server *)serverInfo;
- (bool)disconnect;

@end
