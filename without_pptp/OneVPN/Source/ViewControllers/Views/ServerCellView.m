//
//  ServerCellView.m
//  OneVPN
//
//  Created by Aleksey Dvoryanskiy on 8/18/16.
//  Copyright © 2016 OneVPN. All rights reserved.
//

#import "ServerCellView.h"
#import "RestService.h"

@interface ServerCellView()

@property (weak) IBOutlet NSImageView *icon;
@property (weak) IBOutlet NSTextField *label;

@end

@implementation ServerCellView

#pragma mark - Properties

- (void)setInfo:(ServerInfo *)info {
    _info = info;
    
    [self.label setStringValue:info.name];
    [[RestService sharedService] loadCountryImage:info.country intoImageView:self.icon];
}

#pragma mark - Public

- (void)setup {
    [self.icon setWantsLayer:true];
    
    self.icon.layer.cornerRadius = 12.0f;
    self.icon.layer.masksToBounds = true;
}

@end
