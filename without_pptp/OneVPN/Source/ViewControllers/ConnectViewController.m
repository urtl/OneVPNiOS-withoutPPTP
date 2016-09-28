//
//  ConnectViewController.m
//  OneVPN
//
//  Created by Aleksey Dvoryanskiy on 8/17/16.
//  Copyright © 2016 OneVPN. All rights reserved.
//

#import "ConnectViewController.h"
#import "MenuViewController.h"
#import "XPCConnection.h"
#import "NSColor+AppColors.h"
#import "NSImage+AppImages.h"
#import "PinCoordsByCountry.h"
#import "RestService.h"

static NSString *kConnectTitle = @"CONNECT";
static NSString *kDisconnectTitle = @"DISCONNECT";

static NSString *kStatusConnected = @"Connected to";
static NSString *kStatusDisconnected = @"Disconnected";

static NSString *kLoginKey = @"login";
static NSString *kPassKey = @"password";

//static NSString *kVPNUsername = @"androiddev";
//static NSString *kVPNPassword = @"androiddev";

@interface ConnectViewController () <EventListener, NSTextFieldDelegate>

@property (nonatomic, strong) ServerInfo *currentServer;
@property (nonatomic, assign) bool connected;

@property (weak) IBOutlet MenuViewController *menuController;
@property (weak) IBOutlet NSButton *menuButton;

@property (weak) IBOutlet NSProgressIndicator *connectingProgress;
@property (weak) IBOutlet NSButton *connectButton;

@property (weak) IBOutlet NSTextField *loginField;
@property (weak) IBOutlet NSTextField *passwordField;

@property (weak) IBOutlet NSTextField *statusLabel;
@property (weak) IBOutlet NSTextField *nameLabel;

@property (weak) IBOutlet NSImageView *flagImage;
@property (weak) IBOutlet NSImageView *pinImage;
@property (weak) IBOutlet NSLayoutConstraint *pinImageLeading;
@property (weak) IBOutlet NSLayoutConstraint *pinImageBottom;

@property (weak) IBOutlet NSTextField *protocolLabel;
@property (weak) IBOutlet NSTextField *dnsLabel;
@property (weak) IBOutlet NSTextField *portField;

- (void)checkConnectButtonEnabled;
- (void)updateConnectButton:(BOOL)connected;
- (void)setViewEnabled:(BOOL)enabled;

- (void)updateServerInfo;
- (NSString *)stringForProtocol:(VPNProtocol)protocol;

- (Protocol_Enum)VPNProtocolToProtocol:(VPNProtocol)protocol;

- (void)saveLogin:(NSString *)login;
- (void)savePassword:(NSString *)password;
- (NSString *)loadLogin;
- (NSString *)loadPassword;

- (NSAlert *)errorDialogForExtStatus:(ExtStatus)st;

@end

@implementation ConnectViewController

#pragma mark - Public

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.loginField setDelegate:self];
    [self.passwordField setDelegate:self];
    
    NSString *login = [self loadLogin];
    NSString *passw = [self loadPassword];
    
    [self.loginField setStringValue:(login != nil ? login : @"")];
    [self.passwordField setStringValue:(passw != nil ? passw : @"")];
    
    self.connected = false;
    
    self.menuController.listener = self;
    self.menuButton.enabled = false;
    
    [self updateConnectButton:false];
    [self setViewEnabled:false];
    [self updateServerInfo];
    
    [self.connectingProgress startAnimation:nil];
}

- (void)updateStatus {
    NSLog(@"START GETTING STATUS");
    
    XPCRequest *request = [XPCRequest message];
    request.type = Type_Status;
    
    [[XPCConnection sharedConnection] sendRequest:request withCompletion:^(XPCResponse *response) {
        NSLog(@"END GETTING STATUS");
        
        if (response.type == Type_Status) {
            StatusResponse *sres = response.status;
            
            switch (sres.status) {
                case ServerStatus_Connected:
                    self.connected = true;
                    self.currentServer = [[ServerInfo alloc] initWithServer:sres.server];
                    
                    self.menuButton.enabled = false;
                    
                    NSLog(@"CONNECTED");
                    break;
                case ServerStatus_Disconnected:
                    self.connected = false;
                    self.menuButton.enabled = true;
                    
                    NSLog(@"DISCONNECTED");
                    break;
            }
            
            [self updateConnectButton:self.connected];
            // need to get server info
            
            [self setViewEnabled:self.connected];
            [self updateServerInfo];
        }
        
        [self.connectingProgress stopAnimation:nil];
    }];
}

#pragma mark - Actions

- (IBAction)menuButtonClicked:(id)sender {
    [self.view addSubview:self.menuController.view];
    [self setViewEnabled:false];
}

- (IBAction)connectButtonClicked:(id)sender {
    if (self.connected) {
        // disconnection
        [self.connectingProgress startAnimation:nil];
        [self setViewEnabled:false];
        
        self.menuButton.enabled = false;
        
        NSLog(@"START DISCONNECTING");
        
        XPCRequest *request = [XPCRequest message];
        request.type = Type_Disconnect;
        
        [[XPCConnection sharedConnection] sendRequest:request withCompletion:^(XPCResponse *response) {
            NSLog(@"END DISCONNECTING");
            
            if (response.type == Type_Disconnect) {
                ConnectResponse *cres = response.connect;
                if (cres.status == Status_Ok) {
                    self.connected = false;
                    NSLog(@"DISCONNECTED");
                } else if (cres.status == Status_Fail) {
                    NSLog(@"NOT DISCONNECTED");
                }
            }
            
            [self.connectingProgress stopAnimation:nil];
            [self setViewEnabled:true];
            [self updateConnectButton:self.connected];
            [self updateServerInfo];
            
            self.menuButton.enabled = true;
        }];
    } else {
        if (self.currentServer != nil) {
            [self.connectingProgress startAnimation:nil];
            [self setViewEnabled:false];
            
            self.menuButton.enabled = false;
        
            NSLog(@"START CONNECTING");
            
            Server *sreq = [self.currentServer toServer];
            sreq.login = [self loadLogin];
            sreq.password = [self loadPassword];
            
            XPCRequest *request = [XPCRequest message];
            request.type = Type_Connect;
            request.connect = sreq;
            
            [[XPCConnection sharedConnection] sendRequest:request withCompletion:^(XPCResponse *response) {
                NSLog(@"END CONNECTING");
                
                NSAlert *errorAlert = nil;
                if (response.type == Type_Connect) {
                    ConnectResponse *cres = response.connect;
                    if (cres.status == Status_Ok) {
                        self.connected = true;
                        NSLog(@"CONNECTED");
                    } else if (cres.status == Status_Fail) {
                        NSLog(@"NOT CONNECTED");
                        
                        self.menuButton.enabled = true;
                        
                        errorAlert = [self errorDialogForExtStatus:cres.extStatus];
                    }
                }
                
                [self.connectingProgress stopAnimation:nil];
                [self setViewEnabled:true];
                [self updateConnectButton:self.connected];
                [self updateServerInfo];
                
//                self.menuButton.enabled = true;
                
                if (errorAlert != nil) {
                    [errorAlert runModal];
                }
            }];
        } else {
            NSLog(@"Server not selected");
        }
    }
}

#pragma mark - MenuViewController event listener

- (void)onClose {
    [self.menuController.view removeFromSuperview];
    [self setViewEnabled:true];
}

- (void)onServerSelected:(ServerInfo *)server {
    self.currentServer = server;
    
    [self onClose];
    [self updateServerInfo];
}

#pragma mark - NSTextField delegate

- (void)controlTextDidChange:(NSNotification *)obj {
    NSTextField *field = obj.object;
    if (field == self.loginField) {
        [self saveLogin:field.stringValue];
    } else if (field == self.passwordField) {
        [self savePassword:field.stringValue];
    }
    
    [self checkConnectButtonEnabled];
}

#pragma mark - Private

- (void)checkConnectButtonEnabled {
    NSString *login = [self loadLogin];
    NSString *passw = [self loadPassword];
    
    if (login != nil && login.length > 0 && passw != nil && passw.length > 0 &&
        self.currentServer != nil) {
        self.connectButton.enabled = true;
    } else {
        self.connectButton.enabled = false;
    }
}

- (void)updateConnectButton:(BOOL)connected {
    NSImage *image = connected ? [NSImage disconnectButtonImage] : [NSImage connectButtonImage];
    [self.connectButton setImage:image];
}

- (void)setViewEnabled:(BOOL)enabled {
    self.connectButton.enabled = enabled;
    
    if (self.currentServer != nil && (self.currentServer.protocol == VPNPPTPProtocol || self.currentServer.protocol == VPNL2TPProtocol)) {
        self.portField.enabled = false;
    } else {
        self.portField.enabled = enabled;
    }
    self.loginField.enabled = enabled;
    self.passwordField.enabled = enabled;
}

- (void)updateServerInfo {
    NSString *status = self.connected ? kStatusConnected : kStatusDisconnected;
    NSString *name = (self.currentServer != nil && self.connected) ? self.currentServer.name : @"";
    
    NSString *dns = self.currentServer != nil ? self.currentServer.dns : @"";
    NSString *protocol = self.currentServer != nil ? [self stringForProtocol:self.currentServer.protocol] : @"";
    NSString *port = self.currentServer != nil ? [NSString stringWithFormat:@"%d", self.currentServer.port] : @"";
    
    [self.statusLabel setStringValue:status];
    [self.nameLabel setStringValue:name];
    
    [self.dnsLabel setStringValue:dns];
    [self.protocolLabel setStringValue:protocol];
    
    if (self.currentServer != nil && (self.currentServer.protocol == VPNPPTPProtocol || self.currentServer.protocol == VPNL2TPProtocol)) {
        [self.portField setStringValue:@""];
    } else {
        [self.portField setStringValue:port];
    }
    
    if (self.connected && self.currentServer != nil) {
        [self.flagImage setImage:nil];
        self.flagImage.hidden = false;
        
        [[RestService sharedService] loadCountryImage:self.currentServer.country intoImageView:self.flagImage];
    } else {
        self.flagImage.hidden = true;
    }
    
    if (self.connected && self.currentServer != nil) {
        CGPoint pos = [PinCoordsByCountry getPinCoordsForCountry:self.currentServer.country];
        if (pos.x > 0.0f && pos.y > 0.0f) {
            self.pinImageLeading.constant = pos.x;
            self.pinImageBottom.constant = pos.y;
            
            [self.pinImage setNeedsUpdateConstraints:true];
            
            self.pinImage.hidden = false;
        } else {
            self.pinImage.hidden = true;
        }
    } else {
        self.pinImage.hidden = true;
    }
}

- (NSString *)stringForProtocol:(VPNProtocol)protocol {
    switch (protocol) {
        case VPNPPTPProtocol:
            return @"PPTP";
        case VPNL2TPProtocol:
            return @"L2TP";
        case VPNTCPProtocol:
            return @"OpenVPN TCP";
        case VPNUDPProtocol:
            return @"OpenVPN UDP";
    }
}

- (Protocol_Enum)VPNProtocolToProtocol:(VPNProtocol)protocol {
    switch (protocol) {
        case VPNPPTPProtocol:
            return Protocol_Enum_Pptp;
        case VPNL2TPProtocol:
            return Protocol_Enum_L2Tp;
        case VPNTCPProtocol:
            return Protocol_Enum_Tcp;
        case VPNUDPProtocol:
            return Protocol_Enum_Udp;
    }
}

- (void)saveLogin:(NSString *)login {
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    [prefs setValue:login forKey:kLoginKey];
    
    [prefs synchronize];
}

- (void)savePassword:(NSString *)password {
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    [prefs setValue:password forKey:kPassKey];
    
    [prefs synchronize];
}

- (NSString *)loadLogin {
    return [[NSUserDefaults standardUserDefaults] valueForKey:kLoginKey];
}

- (NSString *)loadPassword {
    return [[NSUserDefaults standardUserDefaults] valueForKey:kPassKey];
}

- (NSAlert *)errorDialogForExtStatus:(ExtStatus)st {
    NSString *title = nil;
    NSString *message = nil;
    
    switch (st) {
        case ExtStatus_Success:
            return nil;
        case ExtStatus_AuthFailed:
            title = @"Authorization failed.";
            message = @"Please check your username/password and try again.";
            break;
        case ExtStatus_OtherFailed:
            title = @"Connection error.";
            message = @"Unable to connect to VPN server. Please try again.";
            break;
    }
    
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"OK"];
    [alert setMessageText:title];
    [alert setInformativeText:message];
    [alert setAlertStyle:NSWarningAlertStyle];
    
    return alert;
}

@end
