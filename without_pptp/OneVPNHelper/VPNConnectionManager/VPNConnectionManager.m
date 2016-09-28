//
//  VPNConnectionManager.m
//  OneVPN
//
//  Created by Aleksey Dvoryanskiy on 8/21/16.
//  Copyright © 2016 OneVPN. All rights reserved.
//

#import "VPNConnectionManager.h"
#import "OpenVPNConfigUtils.h"
#import "PPPDConfigUtils.h"
#import "ClientThread.h"

#import <SystemConfiguration/SystemConfiguration.h>
#import <Security/SecKeychain.h>
#import <syslog.h>

static NSString * kVPNName = @"OneVPN";
static NSString * kVendorName = @"OneVPN";

static NSString * kL2TPPresharedKey = @"123456789";

static const char * kTrustedAppPaths[] = {
    "/usr/libexec/nehelper",
    "/usr/libexec/nesessionmanager",
    "/usr/libexec/neagent",
    "/usr/libexec/configd",
    "/usr/sbin/racoon",
    "/usr/sbin/pppd",
    "/System/Library/CoreServices/SystemUIServer.app",
    "/System/Library/Frameworks/SystemConfiguration.framework/Versions/A/Helpers/SCHelper",
    "/System/Library/PreferencePanes/Network.prefPane/Contents/XPCServices/com.apple.preference.network.remoteservice.xpc"
};

typedef enum {
    kStatusConnected,
    kStatusDisconnected
} ConnectionStatus;

typedef struct {
    ConnectionStatus status;
    CFDictionaryRef extendedStatus;
} CallbackInfo;

void network_connection_callback(SCNetworkConnectionRef	connection, SCNetworkConnectionStatus status, void *info) {
    CallbackInfo *cinfo = (CallbackInfo *) info;
    
    if (cinfo->extendedStatus != NULL) {
        CFRelease(cinfo->extendedStatus);
        cinfo->extendedStatus = NULL;
    }
    
    cinfo->extendedStatus = SCNetworkConnectionCopyExtendedStatus(connection);
    if (cinfo->extendedStatus == NULL) {
        syslog(LOG_NOTICE, "Failed to copy extended status: %d", SCError());
    }
    
    switch (status) {
        case kSCNetworkConnectionDisconnected:
            syslog(LOG_NOTICE, "Disconnected");
            cinfo->status = kStatusDisconnected;
            
            CFRunLoopStop(CFRunLoopGetCurrent());
            break;
        case kSCNetworkConnectionDisconnecting:
            syslog(LOG_NOTICE, "Disconnecting");
            break;
        case kSCNetworkConnectionConnected:
            syslog(LOG_NOTICE, "Connected");
            cinfo->status = kStatusConnected;
            
            CFRunLoopStop(CFRunLoopGetCurrent());
            break;
        case kSCNetworkConnectionConnecting:
            syslog(LOG_NOTICE, "Connecting");
            break;
        case kSCNetworkConnectionInvalid:
            syslog(LOG_NOTICE, "Connection invalid");
            cinfo->status = kStatusDisconnected;
            
            CFRunLoopStop(CFRunLoopGetCurrent());
            break;
    }
}

@interface VPNConnectionManager ()

@property (nonatomic, strong) Server *connectedServer;
@property (nonatomic, assign) ExtStatus extStatus;

@property (nonatomic, strong) ClientThread *clientThread;

- (NSArray *)trustedApps;
- (bool)createItem:(NSString*)label withService:(NSString*)service account:(NSString*)account description:(NSString*)description andPassword:(NSString*)password;

- (bool)connectToPPPServer:(Server *)serverInfo;
- (bool)connectToPPTPServer:(Server *)serverInfo;
- (bool)connectToOpenVPNServer:(Server *)serverInfo;

- (SCNetworkServiceRef)findService;

- (CFDictionaryRef)pptpConfigForServiceID:(CFStringRef)serviceId andServerInfo:(Server *)info;
- (CFDictionaryRef)l2tpConfigForServiceID:(CFStringRef)serviceId andServerInfo:(Server *)info;
- (CFDictionaryRef)l2tpIPSecConfigForServiceID:(CFStringRef)serviceId andServerInfo:(Server *)info;

@end

@implementation VPNConnectionManager

#pragma mark - Shared

+ (instancetype)sharedManager {
    static VPNConnectionManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [VPNConnectionManager new];
    });
    
    return instance;
}

#pragma mark - Public

- (bool)isConnected {
    return self.connectedServer != nil && self.clientThread != nil;
}

- (bool)connectToServer:(Server *)serverInfo {
    switch (serverInfo.protocol) {
        case Protocol_Enum_Pptp:
            return [self connectToPPTPServer:serverInfo];
        case Protocol_Enum_L2Tp:
            return [self connectToPPPServer:serverInfo];
        case Protocol_Enum_Tcp:
        case Protocol_Enum_Udp:
            return [self connectToOpenVPNServer:serverInfo];
    }
}

- (bool)disconnect {
    if ([self isConnected]) {
        [self.clientThread cancel];
        [self.clientThread join];
        
        bool success = self.clientThread.success;
        self.clientThread = nil;
        
        return success;
    }
    
    return true;
}

#pragma mark - Private

- (bool)connectToPPPServer:(Server *)serverInfo {
    CFMutableDictionaryRef ipv4Config = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    
    int one = 1;
    CFDictionarySetValue(ipv4Config, kSCPropNetIPv4ConfigMethod, kSCValNetIPv4ConfigMethodPPP);
    CFDictionarySetValue(ipv4Config, kSCPropNetOverridePrimary, CFNumberCreate(NULL, kCFNumberIntType, &one));
    
    // Authority
    AuthorizationFlags rootFlags = kAuthorizationFlagDefaults | kAuthorizationFlagExtendRights | kAuthorizationFlagInteractionAllowed | kAuthorizationFlagPreAuthorize;
    AuthorizationRef auth;
    OSStatus authErr = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, rootFlags, &auth);
    
    SCPreferencesRef prefs;
    if (authErr == noErr) {
        syslog(LOG_NOTICE, "No Auth error");
        
        prefs = SCPreferencesCreateWithAuthorization(NULL, (__bridge CFStringRef) kVendorName, NULL, auth);
    } else {
        syslog(LOG_NOTICE, "Auth error: %d", authErr);
        
        prefs = SCPreferencesCreate(NULL, (__bridge CFStringRef) kVendorName, NULL);
    }
    
    if (prefs == NULL) {
        syslog(LOG_NOTICE, "Could not create preferences: %d", SCError());
        return false;
    }
    
    SCNetworkSetRef networkSet = SCNetworkSetCopyCurrent(prefs);
    if (networkSet == NULL) {
        syslog(LOG_NOTICE, "Failed to copy current set: %d", SCError());
        return false;
    }
    
    CFArrayRef services = SCNetworkSetCopyServices(networkSet);
    CFIndex size = CFArrayGetCount(services);
    for (int i = 0; i < size; i++) {
        SCNetworkServiceRef existingService = (SCNetworkServiceRef) CFArrayGetValueAtIndex(services, i);
        
        NSString *serviceName = (__bridge NSString *)SCNetworkServiceGetName(existingService);
        NSString *serviceID = (__bridge NSString *)SCNetworkServiceGetServiceID(existingService);
        
        if ([kVPNName isEqualToString:serviceName]) {
            if (SCNetworkServiceRemove(existingService)) {
                syslog(LOG_NOTICE, "Removed existing service: %s", [serviceID UTF8String]);
            } else {
                syslog(LOG_NOTICE, "Failed to remove existing service: %d", SCError());
                return false;
            }
        }
    }
    
    if (!SCPreferencesCommitChanges(prefs)) {
        syslog(LOG_NOTICE, "Failed to commit preferences changes: %d", SCError());
        return false;
    }
    
    if (!SCPreferencesApplyChanges(prefs)) {
        syslog(LOG_NOTICE, "Failed to apply preferences changes: %d", SCError());
        return false;
    }
    
    SCPreferencesSynchronize(prefs);
    
    if (!SCPreferencesLock(prefs, true)) {
        syslog(LOG_NOTICE, "Failed to call SCPreferencesLock: %d", SCError());
        return false;
    }
    
    // refresh network set
    networkSet = SCNetworkSetCopyCurrent(prefs);
    if (networkSet == NULL) {
        syslog(LOG_NOTICE, "Failed to copy current network set: %d", SCError());
        return false;
    }
    
    SCNetworkInterfaceRef bottomInterface = NULL;
    if (serverInfo.protocol == Protocol_Enum_Pptp) {
        bottomInterface = SCNetworkInterfaceCreateWithInterface(kSCNetworkInterfaceIPv4, kSCNetworkInterfaceTypePPTP);
    } else if (serverInfo.protocol == Protocol_Enum_L2Tp) {
        bottomInterface = SCNetworkInterfaceCreateWithInterface(kSCNetworkInterfaceIPv4, kSCNetworkInterfaceTypeL2TP);
    }
    
    if (bottomInterface == NULL) {
        syslog(LOG_NOTICE, "Failed to create bottom interface: %d", SCError());
        return false;
    }
    
    SCNetworkInterfaceRef topInterface = SCNetworkInterfaceCreateWithInterface(bottomInterface, kSCNetworkInterfaceTypePPP);
    if (topInterface == NULL) {
        syslog(LOG_NOTICE, "Failed to create top interface: %d", SCError());
        return false;
    }
    
    SCNetworkServiceRef service = SCNetworkServiceCreate(prefs, topInterface);
    if (service == NULL) {
        syslog(LOG_NOTICE, "Failed to create service: %d", SCError());
        return false;
    }
    
    SCNetworkServiceSetName(service, (__bridge CFStringRef) kVPNName);
    
    CFStringRef serviceId = SCNetworkServiceGetServiceID(service);
    
    CFRelease(topInterface);
    topInterface = NULL;
    
    CFRelease(bottomInterface);
    bottomInterface = NULL;
    
    topInterface = SCNetworkServiceGetInterface(service);
    if (topInterface == NULL) {
        syslog(LOG_NOTICE, "Failed to get top interface: %d", SCError());
        return false;
    }
    
    if (!SCNetworkServiceEstablishDefaultConfiguration(service)) {
        syslog(LOG_NOTICE, "Failed to establish default configuration: %d", SCError());
        return false;
    }
    
    CFDictionaryRef config = NULL;
    if (serverInfo.protocol == Protocol_Enum_Pptp) {
        config = [self pptpConfigForServiceID:serviceId andServerInfo:serverInfo];
    } else if (serverInfo.protocol == Protocol_Enum_L2Tp) {
        config = [self l2tpConfigForServiceID:serviceId andServerInfo:serverInfo];
    }
    
    if (!SCNetworkInterfaceSetConfiguration(topInterface, config)) {
        syslog(LOG_NOTICE, "Failed to set configuration: %d", SCError());
        return false;
    }
    
    if (serverInfo.protocol == Protocol_Enum_L2Tp) {
        CFDictionaryRef ipSecConfig = [self l2tpIPSecConfigForServiceID:serviceId andServerInfo:serverInfo];
        if (!SCNetworkInterfaceSetExtendedConfiguration(topInterface, kSCEntNetIPSec, ipSecConfig)) {
            syslog(LOG_NOTICE, "Failed to set extended L2TP configuration: %d", SCError());
            return false;
        }
    }
    
    if (!SCNetworkServiceEstablishDefaultConfiguration(service)) {
        syslog(LOG_NOTICE, "Failed to establish default configuration: %d", SCError());
        return false;
    }
//
//    // refresh network set
//    networkSet = SCNetworkSetCopyCurrent(prefs);
//    if (networkSet == NULL) {
//        syslog(LOG_NOTICE, "Failed to copy current network set: %d", SCError());
//        return false;
//    }
//    
    if (!SCNetworkSetAddService(networkSet, service)) {
        syslog(LOG_NOTICE, "Failed to add service: %d", SCError());
        return false;
    }
    
    SCNetworkProtocolRef protocol = SCNetworkServiceCopyProtocol(service, kSCNetworkProtocolTypeIPv4);
    if (protocol == NULL) {
        syslog(LOG_NOTICE, "Failed to copy IPv4 protocol: %d", SCError());
        return false;
    }
    
    if (!SCNetworkProtocolSetConfiguration(protocol, ipv4Config)) {
        syslog(LOG_NOTICE, "Failed to set IPv4 protocol configuration: %d", SCError());
        return false;
    }

//    if (!SCNetworkSetAddService(networkSet, service)) {
//        syslog(LOG_NOTICE, "Failed to add service: %d", SCError());
//        return false;
//    }
//
    if (![self createItem:kVPNName withService:(__bridge NSString *) serviceId account:serverInfo.login description:@"VPN Password" andPassword:serverInfo.password]) {
        syslog(LOG_NOTICE, "Failed to create keychain item");
        return false;
    }
    
    if (serverInfo.protocol == Protocol_Enum_L2Tp) {
        NSString *serviceName = [NSString stringWithFormat:@"%s.SS", CFStringGetCStringPtr(serviceId, kCFStringEncodingUTF8)];
        if (![self createItem:kVPNName withService:serviceName account:@"" description:@"VPN Shared Secret" andPassword:kL2TPPresharedKey]) {
            syslog(LOG_NOTICE, "Failed to create keychain item");
            return false;
        }
    }
    
    if (!SCPreferencesCommitChanges(prefs)) {
        syslog(LOG_NOTICE, "Failed to commit preferences changes: %d", SCError());
        return false;
    }
    
    if (!SCPreferencesApplyChanges(prefs)) {
        syslog(LOG_NOTICE, "Failed to apply preferences changes: %d", SCError());
        return false;
    }
    
    if (!SCPreferencesUnlock(prefs)) {
        syslog(LOG_NOTICE, "Failed to unlock preferences: %d", SCError());
        return false;
    }
//
//    service = [self findService];
//    serviceId = SCNetworkServiceGetServiceID(service);
//
    if (!SCNetworkServiceGetEnabled(service)) {
        if (!SCNetworkServiceSetEnabled(service, true)) {
            syslog(LOG_NOTICE, "Failed to enable service: %d", SCError());
            return false;
        }
    }
    
    topInterface = SCNetworkServiceGetInterface(service);
    if (topInterface == NULL) {
        syslog(LOG_NOTICE, "Failed to get interface: %d", SCError());
        return false;
    }
    
    if (serverInfo.protocol == Protocol_Enum_Pptp) {
        config = [self pptpConfigForServiceID:serviceId andServerInfo:serverInfo];
    } else if (serverInfo.protocol == Protocol_Enum_L2Tp) {
        config = [self l2tpConfigForServiceID:serviceId andServerInfo:serverInfo];
    }

    if (!SCNetworkInterfaceSetConfiguration(topInterface, config)) {
        syslog(LOG_NOTICE, "Failed to set interface configuration: %d", SCError());
        return false;
    }
    
    if (serverInfo.protocol == Protocol_Enum_L2Tp) {
        if (!SCNetworkInterfaceSetExtendedConfiguration(topInterface, kSCEntNetIPSec, [self l2tpIPSecConfigForServiceID:serviceId andServerInfo:serverInfo])) {
            syslog(LOG_NOTICE, "Failed to set interface extended configuration: %d", SCError());
            return false;
        }
    }
    
    if (!SCNetworkServiceEstablishDefaultConfiguration(service)) {
        syslog(LOG_NOTICE, "Failed to establish default configuration: %d", SCError());
        return false;
    }

    protocol = SCNetworkServiceCopyProtocol(service, kSCNetworkProtocolTypeIPv4);
    if (protocol == NULL) {
        syslog(LOG_NOTICE, "Failed to copy IPv4 protocol: %d", SCError());
        return false;
    }
    
    if (!SCNetworkProtocolSetConfiguration(protocol, ipv4Config)) {
        syslog(LOG_NOTICE, "Failed to configure IPv4 protocol: %d", SCError());
        return false;
    }
    
    if (!SCPreferencesCommitChanges(prefs)) {
        syslog(LOG_NOTICE, "Failed to commit preferences changes: %d", SCError());
        return false;
    }
    
    if (!SCPreferencesApplyChanges(prefs)) {
        syslog(LOG_NOTICE, "Failed to apply preferences changes: %d", SCError());
        return false;
    }
    
    
    SCNetworkConnectionContext context;
    __block CallbackInfo *cinfo = (CallbackInfo *) malloc(sizeof(CallbackInfo));
    cinfo->status = kStatusDisconnected;
    cinfo->extendedStatus = NULL;
    
    context.version = 0;
    context.info = (void *) cinfo;
    context.retain = NULL;
    context.release = NULL;
    context.copyDescription = NULL;
    
    SCNetworkConnectionRef connection = SCNetworkConnectionCreateWithServiceID(NULL, serviceId, network_connection_callback, &context);
    if (connection == NULL) {
        syslog(LOG_NOTICE, "Failed to create connection by id: %d", SCError());
        return false;
    }
    
    self.clientThread = [[ClientThread alloc] initWithBlock:^bool(NSThread *thread) {
        syslog(LOG_NOTICE, "VPN connection openned, waiting");
        
        while (!thread.cancelled) {
            usleep(500);
        }
        
        syslog(LOG_NOTICE, "Thread cancelled, disconnecting");
        
        if (!SCNetworkConnectionScheduleWithRunLoop(connection, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode)) {
            syslog(LOG_NOTICE, "Failed to schedule connection: %d", SCError());
            return false;
        }
                
        switch (SCNetworkConnectionGetStatus(connection)) {
            case kSCNetworkConnectionDisconnected:
                syslog(LOG_NOTICE, "Status disconnected");
                break;
            case kSCNetworkConnectionConnecting:
                syslog(LOG_NOTICE, "Status connecting");
                break;
            case kSCNetworkConnectionDisconnecting:
                syslog(LOG_NOTICE, "Status disconnecting");
                break;
            case kSCNetworkConnectionConnected:
                syslog(LOG_NOTICE, "Status already connected");
                break;
            case kSCNetworkConnectionInvalid:
                syslog(LOG_NOTICE, "Status invalid. It's NOT OK");
                break;
            default:
                syslog(LOG_NOTICE, "Status unexpected");
                break;
        }
        
        syslog(LOG_NOTICE, "Disconnecting...");
        if (!SCNetworkConnectionStop(connection, false)) {
            syslog(LOG_NOTICE, "Failed to stop connection: %d", SCError());
            return false;
        }
        
        CFRunLoopRun();
        
        NSString *status = @"Unknown";
        switch (cinfo->status) {
            case kStatusConnected:
                status = @"Connected";
                syslog(LOG_NOTICE, "Status connected, it's very weird");
                return false;
            case kStatusDisconnected:
                status = @"Disconnected";
                self.connectedServer = nil;
                break;
        }
        
        free(cinfo);
        cinfo = NULL;
        
        syslog(LOG_NOTICE, "Connection stopped with status: %s", [status UTF8String]);
        
        // Disconnected
        return true;
    } beforeStartBlock:^bool{
        if (!SCNetworkConnectionScheduleWithRunLoop(connection, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode)) {
            syslog(LOG_NOTICE, "Failed to schedule connection: %d", SCError());
            return false;
        }
        
        switch (SCNetworkConnectionGetStatus(connection)) {
            case kSCNetworkConnectionDisconnected:
                syslog(LOG_NOTICE, "Status disconnected. It's OK");
                break;
            case kSCNetworkConnectionConnecting:
                syslog(LOG_NOTICE, "Status connecting");
                break;
            case kSCNetworkConnectionDisconnecting:
                syslog(LOG_NOTICE, "Status disconnecting");
                break;
            case kSCNetworkConnectionConnected:
                syslog(LOG_NOTICE, "Status already connected");
                break;
            case kSCNetworkConnectionInvalid:
                syslog(LOG_NOTICE, "Status invalid. It's NOT OK");
                break;
            default:
                syslog(LOG_NOTICE, "Status unexpected");
                break;
        }
        
        CFDictionaryRef config = nil;
        if (serverInfo.protocol == Protocol_Enum_Pptp) {
            config = [self pptpConfigForServiceID:serviceId andServerInfo:serverInfo];
        } else if (serverInfo.protocol == Protocol_Enum_L2Tp) {
            config = [self l2tpConfigForServiceID:serviceId andServerInfo:serverInfo];
        }
        
        syslog(LOG_NOTICE, "Connecting...");
        if (!SCNetworkConnectionStart(connection, config, false)) {
            syslog(LOG_NOTICE, "Failed to start connection: %d", SCError());
            return false;
        }
        
        CFRunLoopRun();
        
        return cinfo->status == kStatusConnected;
    }];
    
    [self.clientThread start];
    
    NSString *status = @"Unknown";
    switch (cinfo->status) {
        case kStatusConnected:
            status = @"Connected";
            self.connectedServer = serverInfo;
            break;
        case kStatusDisconnected:
            status = @"Disconnected";
            self.connectedServer = nil;
            break;
    }
    
    syslog(LOG_NOTICE, "Connection established with status: %s", [status UTF8String]);
    
    NSDictionary *extStatus = (__bridge NSDictionary *) cinfo->extendedStatus;
    syslog(LOG_NOTICE, "Extended status: %s", [extStatus.description UTF8String]);
    
    ExtStatus st = ExtStatus_Success;
    if (extStatus != nil) {
        NSDictionary *ppp = [extStatus objectForKey:(__bridge NSString *)kSCEntNetPPP];
        if (ppp != nil) {
            NSNumber *cause = [ppp objectForKey:(__bridge NSString *)kSCPropNetPPPLastCause];
            if (cause != nil) {
                int code = [cause intValue];
                if (code == 19 || (serverInfo.protocol == Protocol_Enum_L2Tp && code == 0)) {
                    // auth error
                    st = ExtStatus_AuthFailed;
                } else {
                    st = ExtStatus_OtherFailed;
                }
            }
        }
    }
    
    self.extStatus = st;
    
    return (self.connectedServer != nil);
}

- (bool)connectToPPTPServer:(Server *)serverInfo {
    NSString *cfgPath = [[PPPDConfigUtils sharedUtils] writeConfig:serverInfo];
    
    /*
     sudo /Users/advoryanskiy/Library/Developer/Xcode/DerivedData/OneVPN-cxwuaskihjaqapdfhhszzqapppzy/Build/Products/Debug/OneVPN.app/Contents/Resources/pptp/pppd file /var/root/Library/Application\ Support/OneVPN/ppp_cfg
    */
    
    NSString *pppdFolder = [self.pppdPath stringByDeletingLastPathComponent];
    syslog(LOG_NOTICE, "PPPD folder: %s", [pppdFolder UTF8String]);
    
    NSArray *args = @[@"file", cfgPath];
    
    __block NSTask *task = nil;// = [NSTask new];
    
    __block bool isConnected = false;
    self.clientThread = [[ClientThread alloc] initWithBlock:^bool(NSThread *thread) {
        syslog(LOG_NOTICE, "PPPD connection openned, waiting");
        
        while (!thread.cancelled) {
            usleep(500);
        }
        
        syslog(LOG_NOTICE, "Thread cancelled, disconnecting");
        
        if (task != nil) {
            syslog(LOG_NOTICE, "Finishing... Task not null");
            [task terminate];
            [task waitUntilExit];
        } else {
            syslog(LOG_NOTICE, "Task is null. That's very weird");
        }
        
        self.connectedServer = nil;
        
        return true;
    } beforeStartBlock:^bool{
        task = [NSTask new];
        
        [task setLaunchPath:self.pppdPath];
        [task setCurrentDirectoryPath:pppdFolder];
        [task setArguments:args];
        
        NSPipe *pipe = [NSPipe pipe];
        [task setStandardOutput:pipe];
        //    [task setStandardError:pipe];
        [task setStandardInput:[NSPipe pipe]];
        
        NSMutableString *output = [NSMutableString string];
        [[task.standardOutput fileHandleForReading] setReadabilityHandler:^(NSFileHandle * _Nonnull file) {
            NSData *data = [file availableData];
            NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            
            [output appendString:str];
            
            syslog(LOG_NOTICE, "Output: %s", [str UTF8String]);
        }];
        
        [task launch];
        
        bool connected = false;
        while (!connected) {
            if ([output containsString:@"pptp_wait_input: Address added"]) {
                connected = true;
                
                self.connectedServer = serverInfo;
            }
            
            if (![task isRunning]) {
                connected = false;
                break;
            }
            
            usleep(500);
        }
        
        isConnected = connected;
        
        syslog(LOG_NOTICE, "pppd command output:\n%s", [output UTF8String]);
        ExtStatus st = ExtStatus_Success;
        if (!connected) {
            if ([output containsString:@"authentication failed"]) {
                st = ExtStatus_AuthFailed;
            } else {
                st = ExtStatus_OtherFailed;
            }
        }
        
        self.extStatus = st;
        
        return connected;
    }];
    
    int retries = 0;
    while (!isConnected) {
        if (retries == 5) {
            break;
        }
        
        [self.clientThread start];
        
        if (!isConnected) {
            syslog(LOG_NOTICE, "Connection failed. Stop task and try again");
            
            [task terminate];
            [task waitUntilExit];
            
            syslog(LOG_NOTICE, "Task stopped");
            
            task = nil;
        
            sleep(10);
        } else {
            break;
        }
        
        retries++;
    }
    
    return isConnected;
}

- (bool)connectToOpenVPNServer:(Server *)serverInfo {
    NSString *cfgPath = [[OpenVPNConfigUtils sharedUtils] writeServerConfigs:serverInfo];
    /*
     sudo /Users/advoryanskiy/Library/Developer/Xcode/DerivedData/OneVPN-cxwuaskihjaqapdfhhszzqapppzy/Build/Products/Debug/OneVPN.app/Contents/Resources/ovpn/openvpn --config /var/root/Library/Application\ Support/OneVPN/cfg --cd /var/root/Library/Application\ Support/OneVPN/ --up /Users/advoryanskiy/Library/Developer/Xcode/DerivedData/OneVPN-cxwuaskihjaqapdfhhszzqapppzy/Build/Products/Debug/OneVPN.app/Contents/Resources/ovpn/client.up.sh -d -f -m -w -ptADGNWradsgnw --down /Users/advoryanskiy/Library/Developer/Xcode/DerivedData/OneVPN-cxwuaskihjaqapdfhhszzqapppzy/Build/Products/Debug/OneVPN.app/Contents/Resources/ovpn/client.down.sh -d -f -m -w -ptADGNWradsgnw
     */
    
    NSString *ovpnFolder = [self.ovpnPath stringByDeletingLastPathComponent];
    syslog(LOG_NOTICE, "OpenVPN folder: %s", [ovpnFolder UTF8String]);
    
    NSString *upCommand = [NSString stringWithFormat:@"%@ -d -f -m -w -ptADGNWradsgnw", [ovpnFolder stringByAppendingPathComponent:@"client.up.sh"]];
    NSString *downCommand = [NSString stringWithFormat:@"%@ -d -f -m -w -ptADGNWradsgnw", [ovpnFolder stringByAppendingPathComponent:@"client.down.sh"]];
    
    NSArray *args = @[@"--config", cfgPath, @"--cd", [OpenVPNConfigUtils sharedUtils].appSupportDir,
                      @"--up", upCommand,
                      @"--down", downCommand];
    
    NSTask *task = [NSTask new];
    
    [task setLaunchPath:self.ovpnPath];
    [task setCurrentDirectoryPath:ovpnFolder];
    [task setArguments:args];
    
    NSPipe *pipe = [NSPipe pipe];
    [task setStandardOutput:pipe];
    [task setStandardInput:[NSPipe pipe]];
    
    __block bool isConnected = false;
    self.clientThread = [[ClientThread alloc] initWithBlock:^bool(NSThread *thread) {
        syslog(LOG_NOTICE, "VPN connection openned, waiting");
        
        while (!thread.cancelled) {
            usleep(500);
        }
        
        syslog(LOG_NOTICE, "Thread cancelled, disconnecting");
        
        [task terminate];
        [task waitUntilExit];
        
        self.connectedServer = nil;
        
        return true;
    } beforeStartBlock:^bool{
        NSMutableString *output = [NSMutableString string];
        [[task.standardOutput fileHandleForReading] setReadabilityHandler:^(NSFileHandle * _Nonnull file) {
            NSData *data = [file availableData];
            NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            
            [output appendString:str];
            
            syslog(LOG_NOTICE, "Output: %s", [str UTF8String]);
        }];
        
        [task launch];
        
        bool connected = false;
        while (!connected) {
            if ([output containsString:@"Initialization Sequence Completed"]) {
                connected = true;
                
                self.connectedServer = serverInfo;
            }
            
            if (![task isRunning]) {
                connected = false;
                break;
            }
            
            usleep(500);
        }
        
        isConnected = connected;
        
        syslog(LOG_NOTICE, "openvpn command output:\n%s", [output UTF8String]);
        ExtStatus st = ExtStatus_Success;
        if (!connected) {
            if ([output containsString:@"AUTH_FAILED"] || [output containsString:@"auth-failure"]) {
                st = ExtStatus_AuthFailed;
            } else {
                st = ExtStatus_OtherFailed;
            }
        }
        
        self.extStatus = st;
        
        return connected;
    }];
    
    [self.clientThread start];
    
    return isConnected;
}

- (bool)createItem:(NSString *)label withService:(NSString *)service account:(NSString *)account description:(NSString *)description andPassword:(NSString *)password {
    const char *labelUTF8 = [label UTF8String];
    const char *serviceUTF8 = [service UTF8String];
    const char *accountUTF8 = [account UTF8String];
    const char *descriptionUTF8 = [description UTF8String];
    const char *passwordUTF8 = [password UTF8String];
    
    SecKeychainRef keychain = NULL;
    
    OSStatus status = SecKeychainCopyDomainDefault(kSecPreferencesDomainSystem, &keychain);
    if (status != errSecSuccess) {
        syslog(LOG_NOTICE, "Could not obtain System Keychain: %d", status);
        return false;
    }
    
    status = SecKeychainUnlock(keychain, 0, NULL, FALSE);
    if (status != errSecSuccess) {
        syslog(LOG_NOTICE, "Could not unlock System Keychain: %d", status);
        return false;
    }
    
    SecAccessRef access = nil;
    status = SecAccessCreate((__bridge CFStringRef) kVPNName, (__bridge CFArrayRef) self.trustedApps, &access);
    if(status != noErr) {
        syslog(LOG_NOTICE, "Could not access System Keychain: %d", status);
        return false;
    }
    
    CFMutableDictionaryRef query = CFDictionaryCreateMutable(NULL, 3, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFDictionaryAddValue(query, kSecReturnAttributes, kCFBooleanTrue);
    CFDictionaryAddValue(query, kSecMatchLimit, kSecMatchLimitAll);
    CFDictionaryAddValue(query, kSecClass, kSecClassGenericPassword);
    
    // get search results
    CFArrayRef result = nil;
    status = SecItemCopyMatching(query, (CFTypeRef*)&result);
    if (status != errSecSuccess) {
        syslog(LOG_NOTICE, "Failed to copy matching: %d", status);
        return false;
    }
    
    NSString *oldServiceId = nil;
    NSString *oldAccountId = nil;
    for (int i = 0; i < CFArrayGetCount(result); i++) {
        CFDictionaryRef dict = CFArrayGetValueAtIndex(result, i);
        
        NSDictionary *d = (__bridge NSDictionary *) dict;
        NSString *lbl = [d valueForKey:(__bridge NSString *) kSecAttrLabel];
        NSString *dsc = [d valueForKey:(__bridge NSString *) kSecAttrDescription];
        
        if (lbl != nil && dsc != nil) {
            if ([lbl isEqualToString:label] && [dsc isEqualToString:description]) {
                oldServiceId = [d valueForKey:(__bridge NSString *) kSecAttrService];
                oldAccountId = [d valueForKey:(__bridge NSString *) kSecAttrAccount];
                
                if (oldAccountId == nil) {
                    oldAccountId = @"";
                }
                
                break;
            }
        }
    }
    
    SecKeychainItemRef item = NULL;
    if (oldServiceId != nil && oldAccountId != nil) {
        const char *oldSrv = [oldServiceId UTF8String];
        const char *oldAcc = [oldAccountId UTF8String];
        
        status = SecKeychainFindGenericPassword(keychain, (int)strlen(oldSrv), oldSrv, (int)strlen(oldAcc), oldAcc, NULL, NULL, &item);
        if (status != noErr) {
            if (status == errSecItemNotFound) {
                syslog(LOG_NOTICE, "Not found item. Creating new");
            } else {
                syslog(LOG_NOTICE, "Find keychain item failed: %d", status);
                return false;
            }
        }
    }
    
    SecKeychainAttribute attrs[] = {
        {kSecLabelItemAttr, (int)strlen(labelUTF8), (char *)labelUTF8},
        {kSecAccountItemAttr, (int)strlen(accountUTF8), (char *)accountUTF8},
        {kSecServiceItemAttr, (int)strlen(serviceUTF8), (char *)serviceUTF8},
        {kSecDescriptionItemAttr, (int)strlen(descriptionUTF8), (char *)descriptionUTF8},
    };
    
    SecKeychainAttributeList attributes = {sizeof(attrs) / sizeof(attrs[0]), attrs};
    
    if (item != NULL) {
        status = SecKeychainItemModifyAttributesAndData(item, &attributes, (int)strlen(passwordUTF8), passwordUTF8);
        
        if(status != noErr) {
            syslog(LOG_NOTICE, "Modifying Keychain item failed: %d", status);
            return false;
        }
    } else {
        status = SecKeychainItemCreateFromContent(kSecGenericPasswordItemClass, &attributes, (int)strlen(passwordUTF8), passwordUTF8, keychain, access, &item);
        
        if(status != noErr) {
            syslog(LOG_NOTICE, "Creating Keychain item failed: %d", status);
            return false;
        }
    }
    
    return true;
}

- (NSArray *)trustedApps {
    NSMutableArray *apps = [NSMutableArray array];
    SecTrustedApplicationRef app;
    OSStatus err;
    
    for (int i = 0; i < (sizeof(kTrustedAppPaths) / sizeof(*kTrustedAppPaths)); i++) {
        err = SecTrustedApplicationCreateFromPath(kTrustedAppPaths[i], &app);
        if (err != errSecSuccess) {
            syslog(LOG_NOTICE, "SecTrustedApplicationCreateFromPath failed: %d", err);
        }
        
        [apps addObject:(__bridge id)app];
    }
    
    return apps;
}

- (SCNetworkServiceRef)findService {
    AuthorizationFlags rootFlags = kAuthorizationFlagDefaults | kAuthorizationFlagExtendRights | kAuthorizationFlagInteractionAllowed | kAuthorizationFlagPreAuthorize;
    AuthorizationRef auth;
    OSStatus authErr = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, rootFlags, &auth);
    
    SCPreferencesRef prefs;
    if (authErr == noErr) {
        syslog(LOG_NOTICE, "No Auth error");
        
        prefs = SCPreferencesCreateWithAuthorization(NULL, (__bridge CFStringRef) kVendorName, NULL, auth);
    } else {
        syslog(LOG_NOTICE, "Auth error: %d", authErr);
        
        prefs = SCPreferencesCreate(NULL, (__bridge CFStringRef) kVendorName, NULL);
    }
    
    if (prefs == NULL) {
        syslog(LOG_NOTICE, "Could not create preferences: %d", SCError());
        return false;
    }
    
    CFArrayRef servicesArray = SCNetworkServiceCopyAll(prefs);
    if (servicesArray == NULL) {
        syslog(LOG_NOTICE, "No network services");
        return false;
    }
    
    bool serviceFound = false;
    SCNetworkServiceRef service = nil;
    for (int i = 0; i < CFArrayGetCount(servicesArray); i++) {
        service = (SCNetworkServiceRef) CFArrayGetValueAtIndex(servicesArray, i);
        CFStringRef serviceName = SCNetworkServiceGetName(service);
        if (CFStringCompare(serviceName, (__bridge CFStringRef) kVPNName, 0) == kCFCompareEqualTo) {
            serviceFound = true;
            
            break;
        }
    }
    
    return serviceFound ? service : nil;
}

- (CFDictionaryRef)pptpConfigForServiceID:(CFStringRef)serviceId andServerInfo:(Server *)info {
    CFMutableDictionaryRef config = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    
    int one = 1;
    CFDictionarySetValue(config, kSCPropNetPPPAuthName, (__bridge CFStringRef) info.login);
    CFDictionarySetValue(config, kSCPropNetPPPAuthPassword, serviceId);
    CFDictionarySetValue(config, kSCPropNetPPPAuthPasswordEncryption, kSCValNetPPPAuthPasswordEncryptionKeychain);
    CFDictionarySetValue(config, kSCPropNetPPPAuthProtocol, kSCValNetPPPAuthProtocolPAP);
    CFDictionarySetValue(config, kSCPropNetPPPACSPEnabled, CFNumberCreate(NULL, kCFNumberIntType, &one));
    CFDictionarySetValue(config, kSCPropNetPPPCCPEnabled, CFNumberCreate(NULL, kCFNumberIntType, &one));
    CFDictionarySetValue(config, kSCPropNetPPPCCPMPPE128Enabled, CFNumberCreate(NULL, kCFNumberIntType, &one));
    CFDictionarySetValue(config, kSCPropNetPPPCCPMPPE40Enabled, CFNumberCreate(NULL, kCFNumberIntType, &one));
    CFDictionarySetValue(config, kSCPropNetPPPCommRemoteAddress, (__bridge CFStringRef) info.dns);
    
    return config;
}

- (CFDictionaryRef)l2tpConfigForServiceID:(CFStringRef)serviceID andServerInfo:(Server *)info {
    CFStringRef keysPPP[] = {
        kSCPropNetPPPAuthName,
        kSCPropNetPPPAuthPassword,
        kSCPropNetPPPAuthPasswordEncryption,
        kSCPropNetPPPCommRemoteAddress
    };
    CFStringRef valsPPP[] = {
        (__bridge CFStringRef) info.login,
        serviceID,
        kSCValNetPPPAuthPasswordEncryptionKeychain,
        (__bridge CFStringRef) info.dns
    };
    
    return CFDictionaryCreate(NULL, (const void **) &keysPPP, (const void **) &valsPPP, 4, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
}

- (CFDictionaryRef)l2tpIPSecConfigForServiceID:(CFStringRef)serviceId andServerInfo:(Server *)info {
    CFStringRef keys[] = {
        kSCPropNetIPSecAuthenticationMethod,
        kSCPropNetIPSecSharedSecretEncryption,
        kSCPropNetIPSecSharedSecret
    };
    CFStringRef vals[] = {
        kSCValNetIPSecAuthenticationMethodSharedSecret,
        kSCValNetIPSecSharedSecretEncryptionKeychain,
        (__bridge CFStringRef) [NSString stringWithFormat:@"%s.SS", CFStringGetCStringPtr(serviceId, kCFStringEncodingUTF8)]
    };
    
    return CFDictionaryCreate(NULL, (const void **) &keys, (const void **) &vals, 3, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
}

@end
