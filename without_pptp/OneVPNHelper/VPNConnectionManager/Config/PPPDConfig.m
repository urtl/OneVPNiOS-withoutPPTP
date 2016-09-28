//
//  PPPDConfig.m
//  OneVPN
//
//  Created by Aleksey Dvoryanskiy on 9/5/16.
//  Copyright © 2016 OneVPN. All rights reserved.
//

#import "PPPDConfig.h"

NSString *kPPPDConfigFormatString = @"plugin PPTP.ppp\nnodetach\nnoauth\nrefuse-eap\nlcp-echo-failure 5\nlcp-echo-interval 60\nnovj\nipcp-accept-local\nipcp-accept-remote\nnoipdefault\nipv6cp-use-persistent\nremoteaddress %@\ndefaultroute\nusepeerdns\nrequire-mppe\nname \"%@\"\npassword \"%@\"\ndebug\n";
