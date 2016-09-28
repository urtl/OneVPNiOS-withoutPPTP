//
//  MessageProcessor.h
//  OneVPN
//
//  Created by Aleksey Dvoryanskiy on 8/17/16.
//  Copyright © 2016 OneVPN. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <xpc/xpc.h>

@interface MessageProcessor : NSObject

- (void)processMessage:(xpc_object_t)event;

@end
