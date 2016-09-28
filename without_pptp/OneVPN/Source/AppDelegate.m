//
//  AppDelegate.m
//  OneVPN
//
//  Created by Aleksey Dvoryanskiy on 8/16/16.
//  Copyright © 2016 OneVPN. All rights reserved.
//

#import <ServiceManagement/ServiceManagement.h>
#import <Security/Security.h>

#import "AppDelegate.h"
#import "MainWindowController.h"
#import "Xpc.pbobjc.h"
#import "XPCConnection.h"

#import "RestService.h"

@interface AppDelegate ()

@property (weak) IBOutlet MainWindowController *windowController;

- (BOOL)isServiceInstalled:(NSString *)label;
- (BOOL)installAndConnect:(XPCConnection *)xpc;
- (BOOL)blessHelperWithLabel:(NSString *)label error:(NSError **)error;

- (void)checkVersionWithCompletion:(void (^)())completion;
- (void)setPathesWithCompletion:(void (^)())completion;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    XPCConnection *xpc = [XPCConnection sharedConnection];
    if ([self isServiceInstalled:kXPCServiceIdentifier]) {
        if ([xpc connect]) {
            // connected, check version first
            MainWindowController *controller = self.windowController;
            [self checkVersionWithCompletion:^{
               [self setPathesWithCompletion:^{
                   dispatch_async(dispatch_get_main_queue(), ^{
                       [controller updateStatus];
                   });
               }];
            }];
        } else {
            NSLog(@"Cannot connect to XPC service");
        }
    } else {
        // helper not found, installing it
        NSLog(@"Service not found, installing it");
        if (![self installAndConnect:xpc]) {
            NSLog(@"Installation failed");
        } else {
            MainWindowController *controller = self.windowController;
            [self setPathesWithCompletion:^{
                dispatch_async(dispatch_get_main_queue(), ^{
                    [controller updateStatus];
                });
            }];
        }
    }
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

#pragma mark - Private

- (BOOL)isServiceInstalled:(NSString *)label {
    CFDictionaryRef dict = SMJobCopyDictionary(kSMDomainSystemLaunchd, (__bridge CFStringRef)label);
    return dict != nil;
}

- (BOOL)installAndConnect:(XPCConnection *)xpc {
    [xpc disconnect];
    
    NSError *error = nil;
    if (![self blessHelperWithLabel:kXPCServiceIdentifier error:&error]) {
        NSLog(@"Failed to bless helper: %@", error);
        return NO;
    }
    
    // check connection after installing
    if (![xpc connect]) {
        NSLog(@"Failed to connect after installing helper");
        return NO;
    }
    
    return YES;
}

- (BOOL)blessHelperWithLabel:(NSString *)label error:(NSError *__autoreleasing *)error {
    BOOL result = NO;
    
    AuthorizationItem authItem = { kSMRightBlessPrivilegedHelper, 0, NULL, 0 };
    AuthorizationRights authRight = { 1, &authItem };
    AuthorizationFlags flags = kAuthorizationFlagDefaults | kAuthorizationFlagInteractionAllowed | kAuthorizationFlagPreAuthorize | kAuthorizationFlagExtendRights;
    
    AuthorizationRef authRef = NULL;
    
    OSStatus status = AuthorizationCreate(&authRight, kAuthorizationEmptyEnvironment, flags, &authRef);
    if (status != errAuthorizationSuccess) {
        NSLog(@"Failed to create AuthorizationRef. Error code: %d", (int)status);
    } else {
        CFErrorRef errorRef = (__bridge CFErrorRef) *error;
        result = SMJobBless(kSMDomainSystemLaunchd, (__bridge CFStringRef)label, authRef, &errorRef);
    }
    
    return result;
}

- (void)checkVersionWithCompletion:(void (^)())completion {
    XPCRequest *request = [XPCRequest message];
    request.type = Type_Version;
    
    XPCConnection *xpc = [XPCConnection sharedConnection];
    [xpc sendRequest:request withCompletion:^(XPCResponse *response) {
        if (response.type == Type_Version) {
            VersionResponse *version = response.version;
            
            NSLog(@"Latest helper version: %d.%d", HELPER_MAJOR_VERSION, HELPER_MINOR_VERSION);
            NSLog(@"Current helper version: %d.%d", version.majorVersion, version.minorVersion);
            
            if (version.majorVersion < HELPER_MAJOR_VERSION ||
                (version.majorVersion == HELPER_MAJOR_VERSION && version.minorVersion < HELPER_MINOR_VERSION)) {
                // upgrade
                NSLog(@"Upgrading helper");
                if (![self installAndConnect:xpc]) {
                    NSLog(@"Upgrading failed");
                } else {
                    completion();
                }
            } else {
                completion();
            }
        }
    }];
}

- (void)setPathesWithCompletion:(void (^)())completion {
    PathesRequest *oreq = [PathesRequest message];
    oreq.ovpnPath = [[NSBundle mainBundle] pathForResource:@"ovpn/openvpn" ofType:nil];
    oreq.pppdPath = [[NSBundle mainBundle] pathForResource:@"pptp/pppd" ofType:nil];
    
    XPCRequest *request = [XPCRequest message];
    request.type = Type_Pathes;
    request.pathes = oreq;
    
    XPCConnection *xpc = [XPCConnection sharedConnection];
    [xpc sendRequest:request withCompletion:^(XPCResponse *response) {
        if (response.type == Type_Pathes) {
            PathesResponse *path = response.pathes;
            
            if (path.status == Status_Ok) {
                completion();
            } else {
                NSLog(@"Failed to set OpenVPN path");
            }
        }
    }];
}

@end
