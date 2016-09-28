//
//  ServerCellView.h
//  OneVPN
//
//  Created by Aleksey Dvoryanskiy on 8/18/16.
//  Copyright © 2016 OneVPN. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ServerInfo.h"

@interface ServerCellView : NSTableCellView

@property (nonatomic, strong) ServerInfo *info;

- (void)setup;

@end
