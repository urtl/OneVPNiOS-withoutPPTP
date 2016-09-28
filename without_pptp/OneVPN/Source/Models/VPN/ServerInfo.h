//
//  ServerInfo.h
//  OneVPN
//
//  Created by Aleksey Dvoryanskiy on 8/17/16.
//  Copyright © 2016 OneVPN. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Xpc.pbobjc.h"

typedef enum {
    VPNTCPProtocol,
    VPNUDPProtocol,
    VPNPPTPProtocol,
    VPNL2TPProtocol
} VPNProtocol;

@interface ServerInfo : NSObject

@property (nonatomic, assign, readonly) int serverId;
@property (nonatomic, strong, readonly) NSString *country;
@property (nonatomic, strong, readonly) NSString *name;
@property (nonatomic, strong, readonly) NSString *dns;
@property (nonatomic, assign, readonly) int port;
@property (nonatomic, assign, readonly) VPNProtocol protocol;

- (instancetype)initWithDictionary:(NSDictionary *)dictionary;
- (instancetype)initWithServer:(Server *)server;

- (Server *)toServer;

@end
