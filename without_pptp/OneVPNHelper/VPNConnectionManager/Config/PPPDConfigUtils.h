//
//  PPPDConfigUtils.h
//  OneVPN
//
//  Created by Aleksey Dvoryanskiy on 9/5/16.
//  Copyright © 2016 OneVPN. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Xpc.pbobjc.h"

@interface PPPDConfigUtils : NSObject

+ (instancetype)sharedUtils;

- (NSString *)writeConfig:(Server *)server;

- (BOOL)removeConfig;

@end
