//
//  XPCConnection.m
//  OneVPN
//
//  Created by Aleksey Dvoryanskiy on 8/17/16.
//  Copyright © 2016 OneVPN. All rights reserved.
//

#import "XPCConnection.h"
#import <xpc/xpc.h>

NSString const *kXPCServiceIdentifier = @"com.onevpn.OneVPNHelper";

@interface XPCConnection () {
    xpc_connection_t connection;
}

@property (nonatomic, assign) BOOL isConnected;

@end

@implementation XPCConnection

#pragma mark - Shared instance

+ (instancetype)sharedConnection {
    static XPCConnection *shared;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [XPCConnection new];
    });
    
    return shared;
}

#pragma mark - Public

- (BOOL)connect {
    if (!self.isConnected) {
        connection = xpc_connection_create_mach_service([kXPCServiceIdentifier UTF8String], NULL, XPC_CONNECTION_MACH_SERVICE_PRIVILEGED);
        
        if (!connection) {
            NSLog(@"Failed to create XPC connection");
            return false;
        }
        
        xpc_connection_set_event_handler(connection, ^(xpc_object_t event) {
            xpc_type_t type = xpc_get_type(event);
            
            if (type == XPC_TYPE_ERROR) {
                if (event == XPC_ERROR_CONNECTION_INTERRUPTED) {
                    NSLog(@"XPC connection interupted");
                } else if (event == XPC_ERROR_CONNECTION_INVALID) {
                    NSLog(@"XPC connection invalid, releasing");
                    
                    xpc_release(connection);
                } else {
                    NSLog(@"Unexpected XPC connection error");
                }
            } else {
                NSLog(@"Unexpected XPC connection event");
            }
        });
        
        xpc_connection_resume(connection);
        
        self.isConnected = true;
    }
    
    return self.isConnected;
}

- (BOOL)disconnect {
    if (self.isConnected) {
        xpc_connection_cancel(connection);
        
        self.isConnected = false;
    }
    
    return true;
}

- (void)sendRequest:(XPCRequest *)request withCompletion:(void (^)(XPCResponse *response))completion {
    NSData *data = [request data];
    
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_data(message, "request", [data bytes], [data length]);
    
    xpc_connection_send_message_with_reply(connection, message, dispatch_get_main_queue(), ^(xpc_object_t event) {
        size_t size = 0;
        const void *bytes = xpc_dictionary_get_data(event, "response", &size);
        NSData *receivedData = [NSData dataWithBytes:bytes length:size];
        
        NSError *error = nil;
        XPCResponse *res = [XPCResponse parseFromData:receivedData error:&error];
        if (error == nil) {
            completion(res);
        } else {
            NSLog(@"Error: %@", error);
        }
    });
}

@end
