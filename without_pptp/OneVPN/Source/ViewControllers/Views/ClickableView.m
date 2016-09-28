//
//  ClickableView.m
//  OneVPN
//
//  Created by Aleksey Dvoryanskiy on 8/18/16.
//  Copyright © 2016 OneVPN. All rights reserved.
//

#import "ClickableView.h"

@implementation ClickableView

- (void)mouseUp:(NSEvent *)theEvent {
    if (theEvent.clickCount == 1) {
        if ([self.listener respondsToSelector:@selector(onClick:)]) {
            [self.listener onClick:theEvent];
        }
    }
    
    [super mouseUp:theEvent];
}

@end
