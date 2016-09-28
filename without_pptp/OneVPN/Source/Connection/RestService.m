//
//  RestService.m
//  OneVPN
//
//  Created by Aleksey Dvoryanskiy on 8/17/16.
//  Copyright © 2016 OneVPN. All rights reserved.
//

#import "RestService.h"
#import "AFNetworking.h"

//NSString const * kServerHost = @"http://webservice.onevpn.com/newopenvpnall/";
NSString const * kServerHost = @"http://webservice.onevpn.com/openvpnall/";

NSString const * kServiceURL = @"webservice/";
NSString const * kImagesURL = @"admin/country/";

NSString const * kServiceTCPMethod = @"tcp.php";
NSString const * kServiceUDPMethod = @"udp.php";
NSString const * kServicePPTPMethod = @"pptp.php";
NSString const * kServiceL2TPMethod = @"l2tp.php";

@interface RestService ()

- (NSString *)getURLByProtocol:(VPNProtocol)protocol;
- (NSString *)getImageURLForCountry:(NSString *)country;

@end

@implementation RestService

#pragma mark - Shared

+ (instancetype)sharedService {
    static RestService *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [RestService new];
    });
    
    return instance;
}

#pragma mark - Initialization

- (instancetype)init {
    if ((self = [super init])) {
        [AFJSONRequestOperation addAcceptableContentTypes:[NSSet setWithObject:@"text/html"]];
    }
    
    return self;
}

#pragma mark - Public

- (void)getServersByProtocol:(VPNProtocol)protocol success:(void (^)(NSArray *))success failed:(void (^)(NSError *))failed {
    NSString *url = [self getURLByProtocol:protocol];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
    AFJSONRequestOperation *operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:request success:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
        NSDictionary *jsonDictionary = (NSDictionary *)JSON;
        int status = [(NSNumber *)[jsonDictionary objectForKey:@"status"] intValue];
        if (status == 0) {
            // error
            NSString *message = (NSString *)[jsonDictionary objectForKey:@"msg"];
            NSLog(@"Request status 0. Message: %@", message);
            
            success([NSArray array]);
        } else if (status == 1) {
            // success
            NSMutableArray *result = [NSMutableArray array];
            
            NSArray *servers = (NSArray *)[jsonDictionary objectForKey:@"server"];
            for (NSDictionary *dictionary in servers) {
                ServerInfo *server = [[ServerInfo alloc] initWithDictionary:dictionary];
                [result addObject:server];
            }
            
            success(result);
        }
    } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON) {
        NSLog(@"Request failed: %@", error);
        failed(error);
    }];
    
    [operation start];
}

- (void)loadCountryImage:(NSString *)country intoImageView:(NSImageView *)imageView {
    NSString *url = [self getImageURLForCountry:country];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
    AFImageRequestOperation *operation = [AFImageRequestOperation imageRequestOperationWithRequest:request success:^(NSImage *image) {
        if (image != nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [imageView setImage:image];
            });
        }
    }];
    
    [operation start];
}

#pragma mark - Private

- (NSString *)getURLByProtocol:(VPNProtocol)protocol {
    NSMutableString *result = [NSMutableString stringWithString:(NSString *)kServerHost];
    [result appendString:(NSString *)kServiceURL];
    
    switch (protocol) {
        case VPNTCPProtocol:
            [result appendString:(NSString *)kServiceTCPMethod];
            break;
        case VPNUDPProtocol:
            [result appendString:(NSString *)kServiceUDPMethod];
            break;
        case VPNPPTPProtocol:
            [result appendString:(NSString *)kServicePPTPMethod];
            break;
        case VPNL2TPProtocol:
            [result appendString:(NSString *)kServiceL2TPMethod];
            break;
    }
    
    return result;
}

- (NSString *)getImageURLForCountry:(NSString *)country {
    return [NSString stringWithFormat:@"%@%@%@.png", kServerHost, kImagesURL, country];
}

@end
