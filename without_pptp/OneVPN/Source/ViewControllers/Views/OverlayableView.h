//
//  DisablableView.h
//  OneVPN
//
//  Created by Aleksey Dvoryanskiy on 8/18/16.
//  Copyright © 2016 OneVPN. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface OverlayableView : NSView

@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) NSView *view;

@end
