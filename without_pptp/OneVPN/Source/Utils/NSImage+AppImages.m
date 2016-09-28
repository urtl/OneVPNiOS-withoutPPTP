//
//  NSImage+AppImages.m
//  OneVPN
//
//  Created by Aleksey Dvoryanskiy on 8/18/16.
//  Copyright © 2016 OneVPN. All rights reserved.
//

#import "NSImage+AppImages.h"

@implementation NSImage (AppImages)

+ (NSImage *)connectButtonImage {
    return [NSImage imageNamed:@"connect_button"];
}

+ (NSImage *)disconnectButtonImage {
    return [NSImage imageNamed:@"disconnect_button"];
}

@end
