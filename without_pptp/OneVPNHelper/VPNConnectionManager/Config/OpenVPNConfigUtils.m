//
//  OpenVPNConfigUtils.m
//  OneVPN
//
//  Created by Aleksey Dvoryanskiy on 8/25/16.
//  Copyright © 2016 OneVPN. All rights reserved.
//

#import "OpenVPNConfigUtils.h"
#import "OpenVPNConfig.h"

#import <syslog.h>

static NSString * kAppName = @"OneVPN";
static NSString * kConfigFilename = @"cfg";
static NSString * kUPFilename = @"up";

@interface OpenVPNConfigUtils ()

@property (nonatomic, strong) NSString *appSupportDir;

@end

@implementation OpenVPNConfigUtils

#pragma mark - Shared

+ (instancetype)sharedUtils {
    static OpenVPNConfigUtils *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [OpenVPNConfigUtils new];
    });
    
    return instance;
}

#pragma mark - Initialization

- (instancetype)init {
    if ((self = [super init])) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
        NSString *supportDir = [paths firstObject];
        self.appSupportDir = [NSString stringWithFormat:@"%@/%@", supportDir, kAppName];
        
        NSError * error = nil;
        [[NSFileManager defaultManager] createDirectoryAtPath:self.appSupportDir withIntermediateDirectories:YES attributes:nil error:&error];
        if (error != nil) {
            syslog(LOG_NOTICE, "Failed to create '%s' dir: %s", [self.appSupportDir UTF8String], [error.localizedDescription UTF8String]);
            self.appSupportDir = nil;
        } else {
            syslog(LOG_NOTICE, "App support directory: %s", [self.appSupportDir UTF8String]);
        }
    }
    
    return self;
}

#pragma mark - Public

- (NSString *)writeServerConfigs:(Server *)server {
    NSString *protocol = @"";
    if (server.protocol == Protocol_Enum_Tcp) {
        protocol = @"tcp";
    } else if (server.protocol == Protocol_Enum_Udp) {
        protocol = @"udp";
    }
    
    NSString *configContent = [NSString stringWithFormat:kOpenVPNConfigFormatString, server.dns, server.port, protocol];
    NSString *configPath = [NSString stringWithFormat:@"%@/%@", self.appSupportDir, kConfigFilename];
    
    NSError *error = nil;
    if (![configContent writeToFile:configPath atomically:true encoding:NSUTF8StringEncoding error:&error]) {
        NSString *errorStr = error != nil ? error.localizedDescription : @"";
        syslog(LOG_NOTICE, "Failed to write '%s' config file: %s", [configPath UTF8String], [errorStr UTF8String]);
        
        return nil;
    }
    
    NSString *upContent = [NSString stringWithFormat:kOpenVPNUserPassFormatString, server.login, server.password];
    NSString *upPath = [NSString stringWithFormat:@"%@/%@", self.appSupportDir, kUPFilename];
    
    error = nil;
    if (![upContent writeToFile:upPath atomically:true encoding:NSUTF8StringEncoding error:&error]) {
        NSString *errorStr = error != nil ? error.localizedDescription : @"";
        syslog(LOG_NOTICE, "Failed to write '%s' config file: %s", [upPath UTF8String], [errorStr UTF8String]);
        
        return nil;
    }
    
    
    return configPath;
}

- (BOOL)removeConfigs {
    NSString *configPath = [NSString stringWithFormat:@"%@/%@", self.appSupportDir, kConfigFilename];
    NSString *upPath = [NSString stringWithFormat:@"%@/%@", self.appSupportDir, kUPFilename];
    
    NSError *error = nil;
    BOOL configRemoveResult = [[NSFileManager defaultManager] removeItemAtPath:configPath error:&error];
    if (!configRemoveResult) {
        NSString *errorStr = error != nil ? error.localizedDescription : @"";
        syslog(LOG_NOTICE, "Failed to remove '%s' config file: %s", [configPath UTF8String], [errorStr UTF8String]);
    }
    
    error = nil;
    BOOL upRemoveResult = [[NSFileManager defaultManager] removeItemAtPath:upPath error:&error];
    if (!upRemoveResult) {
        NSString *errorStr = error != nil ? error.localizedDescription : @"";
        syslog(LOG_NOTICE, "Failed to remove '%s' config file: %s", [upPath UTF8String], [errorStr UTF8String]);
    }
    
    return configRemoveResult && upRemoveResult;
}

@end
