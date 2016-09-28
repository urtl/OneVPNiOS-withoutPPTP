//
//  DisablableView.m
//  OneVPN
//
//  Created by Aleksey Dvoryanskiy on 8/18/16.
//  Copyright © 2016 OneVPN. All rights reserved.
//

#import "OverlayableView.h"

@implementation OverlayableView

- (NSView *)hitTest:(NSPoint)aPoint {
    if (!self.enabled) {
        return self.view;
    }
    
    return [super hitTest:aPoint];
}

@end
