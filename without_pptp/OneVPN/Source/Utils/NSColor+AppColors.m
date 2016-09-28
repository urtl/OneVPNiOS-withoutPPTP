//
//  NSColor+AppColors.m
//  OneVPN
//
//  Created by Aleksey Dvoryanskiy on 8/18/16.
//  Copyright © 2016 OneVPN. All rights reserved.
//

#import "NSColor+AppColors.h"

@implementation NSColor (AppColors)

+ (NSColor *)connectButtonColor {
    return [NSColor colorWithRed:(126.0f / 256.0f) green:(201.0f / 256.0f) blue:(61.0f / 256.0f) alpha:1.0f];
}

+ (NSColor *)disconnectButtonColor {
    return [NSColor redColor];
}

+ (NSColor *)connectButtonTitleColor {
    return [NSColor whiteColor];
}

+ (NSColor *)disconnectButtonTitleColor {
    return [NSColor whiteColor];
}

+ (NSColor *)menuBackgroundColor {
    return [NSColor colorWithRed:(221.0f / 256.0f) green:(221.0f / 256.0f) blue:(221.0f / 256.0f) alpha:1.0f];
}

+ (NSColor *)shadingColor {
    return [NSColor colorWithWhite:0.0f alpha:0.1f];
}

@end
