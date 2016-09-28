//
//  ClientThread.h
//  OneVPN
//
//  Created by Aleksey Dvoryanskiy on 8/25/16.
//  Copyright © 2016 OneVPN. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef bool (^ThreadBlock)(NSThread *thread);
typedef bool (^BeforeStartBlock)();

@interface ClientThread : NSThread

@property (nonatomic, assign, readonly) bool success;

- (instancetype)initWithBlock:(ThreadBlock)block beforeStartBlock:(BeforeStartBlock)beforeStartBlock;

- (void)join;

@end
