//
//  MenuViewController.h
//  OneVPN
//
//  Created by Aleksey Dvoryanskiy on 8/18/16.
//  Copyright © 2016 OneVPN. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "ServerInfo.h"

@protocol EventListener

@optional
- (void)onClose;
- (void)onServerSelected:(ServerInfo *)server;

@end

@interface MenuViewController : NSViewController

@property (nonatomic, assign) NSObject<EventListener> *listener;

@end
