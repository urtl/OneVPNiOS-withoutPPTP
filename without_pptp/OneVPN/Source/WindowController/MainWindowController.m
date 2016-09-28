//
//  MainWindowController.m
//  OneVPN
//
//  Created by Aleksey Dvoryanskiy on 8/16/16.
//  Copyright © 2016 OneVPN. All rights reserved.
//

#import "MainWindowController.h"
#import "ConnectViewController.h"

@interface MainWindowController ()

@property (weak) IBOutlet NSView *targetView;

@property (nonatomic, strong) ConnectViewController *viewController;

@end

@implementation MainWindowController

#pragma mark - Public

- (void)awakeFromNib {
    self.viewController = [[ConnectViewController alloc] initWithNibName:@"ConnectViewController" bundle:[NSBundle mainBundle]];
    [self.targetView addSubview:self.viewController.view];
}

- (void)updateStatus {
    [self.viewController updateStatus];
}

@end
