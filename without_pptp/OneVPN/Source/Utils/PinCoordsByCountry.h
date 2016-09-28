//
//  PinCoordsByCountry.h
//  OneVPN
//
//  Created by Aleksey Dvoryanskiy on 9/4/16.
//  Copyright © 2016 OneVPN. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PinCoordsByCountry : NSObject

+ (CGPoint)getPinCoordsForCountry:(NSString *)country;

@end
