//
//  RestService.h
//  OneVPN
//
//  Created by Aleksey Dvoryanskiy on 8/17/16.
//  Copyright © 2016 OneVPN. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ServerInfo.h"

extern NSString *kServerHost;

extern NSString *kServiceURL;
extern NSString *kImagesURL;

extern NSString *kServiceTCPMethod;
extern NSString *kServiceUDPMethod;
extern NSString *kServicePPTPMethod;
extern NSString *kServiceL2TPMethod;

@interface RestService : NSObject

+ (instancetype)sharedService;

- (void)getServersByProtocol:(VPNProtocol)protocol success:(void (^)(NSArray *servers))success failed:(void (^)(NSError *error))failed;
- (void)loadCountryImage:(NSString *)country intoImageView:(NSImageView *)imageView;

@end
