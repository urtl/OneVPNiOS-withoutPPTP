//
//  PPPDConfigUtils.m
//  OneVPN
//
//  Created by Aleksey Dvoryanskiy on 9/5/16.
//  Copyright © 2016 OneVPN. All rights reserved.
//

#import "PPPDConfigUtils.h"
#import "PPPDConfig.h"

#import "OpenVPNConfigUtils.h"

#import <syslog.h>

static NSString * kConfigFilename = @"ppp_cfg";

@implementation PPPDConfigUtils

#pragma mark - Shared

+ (instancetype)sharedUtils {
    static PPPDConfigUtils *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [PPPDConfigUtils new];
    });
    
    return instance;
}

#pragma mark - Public

- (NSString *)writeConfig:(Server *)server {
    NSString *configContent = [NSString stringWithFormat:kPPPDConfigFormatString, server.dns, server.login, server.password];
    NSString *configPath = [NSString stringWithFormat:@"%@/%@", [OpenVPNConfigUtils sharedUtils].appSupportDir, kConfigFilename];
    
    NSError *error = nil;
    if (![configContent writeToFile:configPath atomically:true encoding:NSUTF8StringEncoding error:&error]) {
        NSString *errorStr = error != nil ? error.localizedDescription : @"";
        syslog(LOG_NOTICE, "Failed to write '%s' config file: %s", [configPath UTF8String], [errorStr UTF8String]);
        
        return nil;
    }
    
    return configPath;
}

- (BOOL)removeConfig {
    NSString *configPath = [NSString stringWithFormat:@"%@/%@", [OpenVPNConfigUtils sharedUtils].appSupportDir, kConfigFilename];
    
    NSError *error = nil;
    BOOL res = [[NSFileManager defaultManager] removeItemAtPath:configPath error:&error];
    if (!res) {
        NSString *errorStr = error != nil ? error.localizedDescription : @"";
        syslog(LOG_NOTICE, "Failed to remove '%s' config file: %s", [configPath UTF8String], [errorStr UTF8String]);
    }
    
    return res;
}

@end
