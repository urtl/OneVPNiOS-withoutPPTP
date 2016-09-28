//
//  MessageProcessor.m
//  OneVPN
//
//  Created by Aleksey Dvoryanskiy on 8/17/16.
//  Copyright © 2016 OneVPN. All rights reserved.
//

#import "MessageProcessor.h"
#import "Xpc.pbobjc.h"
#import "VPNConnectionManager.h"

#import <syslog.h>
#import <SystemConfiguration/SystemConfiguration.h>

@interface MessageProcessor ()

- (XPCResponse *)processRequest:(XPCRequest *)request;

@end

@implementation MessageProcessor

#pragma mark - Public

- (void)processMessage:(xpc_object_t)event {
    xpc_connection_t remote = xpc_dictionary_get_remote_connection(event);
    
    size_t size = 0;
    const void *bytes = xpc_dictionary_get_data(event, "request", &size);
    syslog(LOG_NOTICE, "Size: %ld", size);
    if (size > 0) {
        NSData *data = [NSData dataWithBytes:bytes length:size];
        NSError *error = nil;
        XPCRequest *req = [XPCRequest parseFromData:data error:&error];
        
        if (error != nil) {
            syslog(LOG_NOTICE, "ERROR: %s", [[error localizedDescription] UTF8String]);
            return;
        }
        
        XPCResponse *response = [self processRequest:req];
        
        NSData *outData = [response data];
        xpc_object_t reply = xpc_dictionary_create_reply(event);
        xpc_dictionary_set_data(reply, "response", [outData bytes], [outData length]);
        xpc_connection_send_message(remote, reply);
        xpc_release(reply);
    }
}

#pragma mark - Private

- (XPCResponse *)processRequest:(XPCRequest *)request {
    switch (request.type) {
        case Type_Version: {
            VersionResponse *vres = [VersionResponse message];
            vres.majorVersion = HELPER_MAJOR_VERSION;
            vres.minorVersion = HELPER_MINOR_VERSION;
            
            XPCResponse *response = [XPCResponse message];
            response.type = Type_Version;
            response.version = vres;
            
            return response;
        }
        case Type_Pathes: {
            PathesRequest *oreq = request.pathes;
            
            syslog(LOG_NOTICE, "OpenVPN binary path: %s", [oreq.ovpnPath UTF8String]);
            syslog(LOG_NOTICE, "PPPD binary path: %s", [oreq.pppdPath UTF8String]);
            
            [VPNConnectionManager sharedManager].ovpnPath = oreq.ovpnPath;
            [VPNConnectionManager sharedManager].pppdPath = oreq.pppdPath;
            
            PathesResponse *ores = [PathesResponse message];
            ores.status = Status_Ok;
            
            XPCResponse *response = [XPCResponse message];
            response.type = Type_Pathes;
            response.pathes = ores;
            
            return response;
        }
        case Type_Status: {
            bool connected = [[VPNConnectionManager sharedManager] isConnected];
            Server *server = [VPNConnectionManager sharedManager].connectedServer;
            
            StatusResponse *sres = [StatusResponse message];
            sres.status = connected ? ServerStatus_Connected : ServerStatus_Disconnected;
            sres.server = server;
            
            XPCResponse *response = [XPCResponse message];
            response.type = Type_Status;
            response.status = sres;
            
            return response;
        }
        case Type_Connect: {
            Server *creq = request.connect;
            
            syslog(LOG_NOTICE, "Connecting to %s:%d by protocol %d", [creq.dns UTF8String], creq.port, creq.protocol);
            
            bool connected = [[VPNConnectionManager sharedManager] connectToServer:creq];
            
            ConnectResponse *cres = [ConnectResponse message];
            cres.status = connected ? Status_Ok : Status_Fail;
            cres.extStatus = [VPNConnectionManager sharedManager].extStatus;// st;
            
            XPCResponse *response = [XPCResponse message];
            response.type = Type_Connect;
            response.connect = cres;
            
            return response;
        }
        case Type_Disconnect: {
            bool disconnected = [[VPNConnectionManager sharedManager] disconnect];
            
            DisconnectResponse *dres = [DisconnectResponse message];
            dres.status = disconnected ? Status_Ok : Status_Fail;
            
            XPCResponse *response = [XPCResponse message];
            response.type = Type_Disconnect;
            response.disconnect = dres;
            
            return response;
        }
    }
}

@end
