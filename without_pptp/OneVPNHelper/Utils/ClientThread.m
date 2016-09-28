//
//  ClientThread.m
//  OneVPN
//
//  Created by Aleksey Dvoryanskiy on 8/25/16.
//  Copyright © 2016 OneVPN. All rights reserved.
//

#import "ClientThread.h"

static NSInteger kStartCondition = 0;
static NSInteger kStopCondition = 1;

@interface ClientThread ()

@property (nonatomic, assign) bool success;

@property (nonatomic, strong) NSConditionLock *lock;

@property (nonatomic, strong) ThreadBlock block;
@property (nonatomic, strong) BeforeStartBlock beforeStartBlock;

- (void)backgroundSelector;

@end

@implementation ClientThread

#pragma mark - Initialization

- (instancetype)initWithBlock:(ThreadBlock)block beforeStartBlock:(BeforeStartBlock)beforeStartBlock {
    if ((self = [super initWithTarget:self selector:@selector(backgroundSelector) object:nil])) {
        self.block = block;
        self.beforeStartBlock = beforeStartBlock;
    }
    
    return self;
}

#pragma mark - Public

- (void)join {
    [self.lock lockWhenCondition:kStopCondition];
    [self.lock unlockWithCondition:kStopCondition];
}

#pragma mark - Overrides

- (void)start {
    bool start = true;
    if (self.beforeStartBlock != nil) {
        start = self.beforeStartBlock();
    }
    
    self.lock = [[NSConditionLock alloc] initWithCondition:kStartCondition];
    
    if (start) {
        [super start];
    }
}

#pragma mark - Private

- (void)backgroundSelector {
    [self.lock lock];
    
    @autoreleasepool {
        if (self.block != nil) {
            self.success = self.block(self);
        }
    }
    
    [self.lock unlockWithCondition:kStopCondition];
}

@end
