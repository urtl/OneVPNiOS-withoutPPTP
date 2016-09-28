//
//  main.m
//  OneVPNHelper
//
//  Created by Aleksey Dvoryanskiy on 8/16/16.
//  Copyright © 2016 OneVPN. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <syslog.h>
#import <xpc/xpc.h>

#import "Xpc.pbobjc.h"
#import "MessageProcessor.h"

static MessageProcessor *processor;

static void __xpc_peer_event_handler(xpc_connection_t connection, xpc_object_t event) {
    syslog(LOG_NOTICE, "Received event in helper");
    
    xpc_type_t type = xpc_get_type(event);
    
    if (type == XPC_TYPE_ERROR) {
        if (event == XPC_ERROR_CONNECTION_INVALID) {
            syslog(LOG_NOTICE, "Invalid XPC connection");
            // tear down all associated resources
        } else if (event == XPC_ERROR_TERMINATION_IMMINENT) {
            syslog(LOG_NOTICE, "XPC connection terminated");
            // tear down all associated resources
        }
    } else {
        @autoreleasepool {
            [processor processMessage:event];
        }
    }
}

static void __xpc_connection_handler(xpc_connection_t connection)  {
    syslog(LOG_NOTICE, "Configuring message event handler for helper.");
    
    xpc_connection_set_event_handler(connection, ^(xpc_object_t event) {
        __xpc_peer_event_handler(connection, event);
    });
    
    xpc_connection_resume(connection);
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        processor = [MessageProcessor new];
        
        xpc_connection_t service = xpc_connection_create_mach_service("com.onevpn.OneVPNHelper",
                                                                      dispatch_get_main_queue(),
                                                                      XPC_CONNECTION_MACH_SERVICE_LISTENER);
        
        if (!service) {
            syslog(LOG_NOTICE, "Failed to create service");
            exit(EXIT_FAILURE);
        }
        
        syslog(LOG_NOTICE, "Configuring connection event handler for helper");
        xpc_connection_set_event_handler(service, ^(xpc_object_t connection) {
            __xpc_connection_handler(connection);
        });
        
        xpc_connection_resume(service);
        
        dispatch_main();
        
        xpc_release(service);
        
        return EXIT_SUCCESS;
    }
}
