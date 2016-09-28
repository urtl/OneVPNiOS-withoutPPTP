//
//  PinCoordsByCountry.m
//  OneVPN
//
//  Created by Aleksey Dvoryanskiy on 9/4/16.
//  Copyright © 2016 OneVPN. All rights reserved.
//

#import "PinCoordsByCountry.h"

@implementation PinCoordsByCountry

+ (CGPoint)getPinCoordsForCountry:(NSString *)country {
    if ([country isEqualToString:@"australia"]) {
        return CGPointMake(486.0f, 259.0f);
    } else if ([country isEqualToString:@"brazil"]) {
        return CGPointMake(240.0f, 275.0f);
    } else if ([country isEqualToString:@"canada"]) {
        return CGPointMake(187.0f, 374.0f);
    } else if ([country isEqualToString:@"czech_republic"]) {
        return CGPointMake(326.0f, 359.0f);
    } else if ([country isEqualToString:@"france"]) {
        return CGPointMake(310.0f, 353.0f);
    } else if ([country isEqualToString:@"germany"]) {
        return CGPointMake(321.0f, 361.0f);
    } else if ([country isEqualToString:@"hong_kong"]) {
        return CGPointMake(462.0f, 322.0f);
    } else if ([country isEqualToString:@"italy"]) {
        return CGPointMake(325.0f, 347.0f);
    } else if ([country isEqualToString:@"netherlands"]) {
        return CGPointMake(315.0f, 363.0f);
    } else if ([country isEqualToString:@"new_zealand"]) {
        return CGPointMake(535.0f, 229.0f);
    } else if ([country isEqualToString:@"norway"]) {
        return CGPointMake(316.0f, 378.0f);
    } else if ([country isEqualToString:@"singapore"]) {
        return CGPointMake(448.0f, 295.0f);
    } else if ([country isEqualToString:@"spain"]) {
        return CGPointMake(303.0f, 346.0f);
    } else if ([country isEqualToString:@"sweden"]) {
        return CGPointMake(328.0f, 378.0f);
    } else if ([country isEqualToString:@"switzerland"]) {
        return CGPointMake(318.0f, 355.0f);
    } else if ([country isEqualToString:@"turkey"]) {
        return CGPointMake(353.0f, 342.0f);
    } else if ([country isEqualToString:@"united_kingdom"]) {
        return CGPointMake(304.0f, 369.0f);
    } else if ([country isEqualToString:@"usa"]) {
        return CGPointMake(184.0f, 344.0f);
    }
    
    return CGPointZero;
}

@end
