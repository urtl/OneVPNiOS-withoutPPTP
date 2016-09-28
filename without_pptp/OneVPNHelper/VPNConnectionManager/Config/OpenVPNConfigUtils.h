//
//  OpenVPNConfigUtils.h
//  OneVPN
//
//  Created by Aleksey Dvoryanskiy on 8/25/16.
//  Copyright © 2016 OneVPN. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Xpc.pbobjc.h"

@interface OpenVPNConfigUtils : NSObject

@property (nonatomic, strong, readonly) NSString *appSupportDir;

+ (instancetype)sharedUtils;

- (NSString *)writeServerConfigs:(Server *)server;

- (BOOL)removeConfigs;

@end
