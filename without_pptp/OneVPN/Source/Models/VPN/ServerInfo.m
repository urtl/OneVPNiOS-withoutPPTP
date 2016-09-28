//
//  ServerInfo.m
//  OneVPN
//
//  Created by Aleksey Dvoryanskiy on 8/17/16.
//  Copyright © 2016 OneVPN. All rights reserved.
//

#import "ServerInfo.h"

@implementation ServerInfo

#pragma mark - Public

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    if ((self = [self init])) {
        _serverId = [(NSNumber *)[dictionary objectForKey:@"id"] intValue];
        _country = (NSString *)[dictionary objectForKey:@"country"];
        _name = (NSString *)[dictionary objectForKey:@"name"];
        _dns = (NSString *)[dictionary objectForKey:@"dns"];
        _port = [(NSNumber *)[dictionary objectForKey:@"port"] intValue];
        
        NSString *protocol = (NSString *)[dictionary objectForKey:@"protocol"];
        if ([protocol isEqualToString:@"tcp"]) {
            _protocol = VPNTCPProtocol;
        } else if ([protocol isEqualToString:@"udp"]) {
            _protocol = VPNUDPProtocol;
        } else if ([protocol isEqualToString:@"pptp"]) {
            _protocol = VPNPPTPProtocol;
        } else if ([protocol isEqualToString:@"l2tp"]) {
            _protocol = VPNL2TPProtocol;
        }
    }
    
    return self;
}

- (instancetype)initWithServer:(Server *)server {
    if ((self = [super init])) {
        _serverId = server.id_p;
        _country = server.country;
        _name = server.name;
        _dns = server.dns;
        _port = server.port;
        
        switch (server.protocol) {
            case Protocol_Enum_Pptp:
                _protocol = VPNPPTPProtocol;
                break;
            case Protocol_Enum_L2Tp:
                _protocol = VPNL2TPProtocol;
                break;
            case Protocol_Enum_Tcp:
                _protocol = VPNTCPProtocol;
                break;
            case Protocol_Enum_Udp:
                _protocol = VPNUDPProtocol;
                break;
        }
    }
    
    return self;
}

- (Server *)toServer {
    Server *result = [Server message];
    result.id_p = self.serverId;
    result.country = self.country;
    result.name = self.name;
    result.dns = self.dns;
    result.port = self.port;
    
    switch (self.protocol) {
        case VPNTCPProtocol:
            result.protocol = Protocol_Enum_Tcp;
            break;
        case VPNUDPProtocol:
            result.protocol = Protocol_Enum_Udp;
            break;
        case VPNPPTPProtocol:
            result.protocol = Protocol_Enum_Pptp;
            break;
        case VPNL2TPProtocol:
            result.protocol = Protocol_Enum_L2Tp;
            break;
    }
    
    return result;
}

- (NSString *)description {
    NSString *protocol = nil;
    switch (_protocol) {
        case VPNTCPProtocol:
            protocol = @"TCP";
            break;
        case VPNUDPProtocol:
            protocol = @"UDP";
            break;
        case VPNPPTPProtocol:
            protocol = @"PPTP";
            break;
        case VPNL2TPProtocol:
            protocol = @"L2TP";
            break;
    }
    
    return [NSString stringWithFormat:@"{id=%d, country=%@, name=%@, dns=%@, port=%d, procotol=%@}",
            _serverId, _country, _name, _dns, _port, protocol];
}

@end
