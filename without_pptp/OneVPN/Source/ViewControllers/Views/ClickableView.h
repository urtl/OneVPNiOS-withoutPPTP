//
//  ClickableView.h
//  OneVPN
//
//  Created by Aleksey Dvoryanskiy on 8/18/16.
//  Copyright © 2016 OneVPN. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol ClickListener

@optional
- (void)onClick:(NSEvent *)event;

@end

@interface ClickableView : NSView

@property (nonatomic, assign) NSObject<ClickListener> *listener;

@end
