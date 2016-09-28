//
//  MenuViewController.m
//  OneVPN
//
//  Created by Aleksey Dvoryanskiy on 8/18/16.
//  Copyright © 2016 OneVPN. All rights reserved.
//

#import "MenuViewController.h"
#import "ClickableView.h"
#import "ServerCellView.h"
#import "ServerInfo.h"
#import "RestService.h"
#import "NSColor+AppColors.h"

@interface MenuViewController () <ClickListener, NSTableViewDataSource, NSTableViewDelegate>

@property (weak) IBOutlet NSView *menuView;
@property (weak) IBOutlet NSPopUpButton *protocolPopup;
@property (weak) IBOutlet NSTableView *serversTable;

@property (nonatomic, strong) NSMutableArray *servers;

- (NSArray<NSString *> *)titles;
- (void)updateDropDownItems;

- (void)updateServersList;
- (VPNProtocol)protocolForString:(NSString *)protocolString;

@end

@implementation MenuViewController

#pragma mark - Public

- (void)viewDidLoad {
    self.servers = [NSMutableArray array];
    
    [self.protocolPopup removeAllItems];
    [self.protocolPopup addItemsWithTitles:[self titles]];
    
    ((ClickableView *)self.view).listener = self;
    
    [self.view setWantsLayer:true];
    [self.view.layer setBackgroundColor:[[NSColor clearColor] CGColor]];
    
    [self.menuView setWantsLayer:true];
    [self.menuView.layer setBackgroundColor:[[NSColor menuBackgroundColor] CGColor]];
    
    NSShadow *dropShadow = [[NSShadow alloc] init];
    [dropShadow setShadowColor:[NSColor blackColor]];
    [dropShadow setShadowOffset:NSMakeSize(0.0f, 0.0f)];
    [dropShadow setShadowBlurRadius:10.0];
    
    [self.menuView setShadow:dropShadow];
    
    [self updateServersList];
}

- (void)loadView {
    [super loadView];
    
    NSLog(@"loadView");
}

#pragma mark - ClickListener

- (void)onClick:(NSEvent *)event {
    if (!NSPointInRect(event.locationInWindow, self.menuView.bounds)) {
        if ([self.listener respondsToSelector:@selector(onClose)]) {
            [self.listener onClose];
        }
    }
}

#pragma mark - NSTableView data source and delegate

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.servers.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSString *identifier = [tableColumn identifier];
    if ([identifier isEqualToString:@"ServerCell"]) {
        ServerCellView *cell = [tableView makeViewWithIdentifier:@"ServerCell" owner:self];
        [cell setup];
        
        ServerInfo *info = self.servers[row];
        cell.info = info;
        
        return cell;
    }
    
    return nil;
}

#pragma mark - Actions

- (IBAction)protocolSelected:(id)sender {
    [self updateDropDownItems];
    [self updateServersList];
}

- (IBAction)reloadButtonClicked:(id)sender {
    [self updateServersList];
}

- (IBAction)cellChangeSelected:(id)sender {
    NSInteger selectedRow = [self.serversTable selectedRow];
    if (selectedRow >= 0) {
        [self.serversTable deselectAll:self];
        
        ServerInfo *selectedServer = self.servers[selectedRow];
        NSLog(@"Selected server: %@", selectedServer);
        
        if ([self.listener respondsToSelector:@selector(onServerSelected:)]) {
            [self.listener onServerSelected:selectedServer];
        }
    }
}

#pragma mark - Private

- (NSArray<NSString *> *)titles {
    static NSArray<NSString *> *itemTitles;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
//        itemTitles = @[@"PPTP", @"L2TP", @"OpenVPN TCP", @"OpenVPN UDP"];
        itemTitles = @[@"L2TP", @"OpenVPN TCP", @"OpenVPN UDP"];
    });
    
    return itemTitles;
}

- (void)updateDropDownItems {
    NSString *title = self.protocolPopup.titleOfSelectedItem;
    
    NSMutableArray *titles = [[self titles] mutableCopy];
    [titles removeObject:title];
    [titles insertObject:title atIndex:0];
    
    [self.protocolPopup removeAllItems];
    [self.protocolPopup addItemsWithTitles:titles];
    
    [self.protocolPopup selectItemWithTitle:title];
}

- (void)updateServersList {
    VPNProtocol protocol = [self protocolForString:self.protocolPopup.titleOfSelectedItem];
    [[RestService sharedService] getServersByProtocol:protocol success:^(NSArray *serverInfos) {
        [self.servers removeAllObjects];
        [self.servers addObjectsFromArray:serverInfos];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.serversTable reloadData];
        });
    } failed:^(NSError *error) {
        NSLog(@"Error while getting servers list: %@", error);
        
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"Unable to fetch server list."];
        [alert setInformativeText:@"OneVPN unable to fetch server list. Please check your internet connection."];
        [alert setAlertStyle:NSWarningAlertStyle];
        
        [alert runModal];
    }];
}

- (VPNProtocol)protocolForString:(NSString *)protocolString {
    if ([protocolString isEqualToString:@"PPTP"]) {
        return VPNPPTPProtocol;
    } else if ([protocolString isEqualToString:@"L2TP"]) {
        return VPNL2TPProtocol;
    } else if ([protocolString isEqualToString:@"OpenVPN TCP"]) {
        return VPNTCPProtocol;
    } else if ([protocolString isEqualToString:@"OpenVPN UDP"]) {
        return VPNUDPProtocol;
    }
    
//    return VPNPPTPProtocol;
    return VPNL2TPProtocol;
}

@end
