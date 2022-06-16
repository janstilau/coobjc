//
//  AppDelegate.m
//  coobjcBaseExample
//
//  Copyright © 2018 Alibaba Group Holding Limited All rights reserved.
//

#import "AppDelegate.h"
#import "KMStoryBoardUtilities.h"
#import "KMDiscoverListViewController.h"
#import "DataService.h"

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    [DataService sharedInstance];
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    UINavigationController* navigationController = (UINavigationController*)[KMStoryBoardUtilities viewControllerForStoryboardName:@"KMDiscoverStoryboard" class:[KMDiscoverListViewController class]];
    
    [self.window setRootViewController:navigationController];
    
    [self setupNavigationTitleLabelStyle];
    [self setupStatusBarStyle];
    
    // Override point for customization after application launch.
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    return YES;
}

#pragma mark -
#pragma mark App Style Setup Methods

- (void)setupNavigationTitleLabelStyle
{
    NSMutableDictionary *titleBarAttributes = [NSMutableDictionary dictionaryWithDictionary: [[UINavigationBar appearance] titleTextAttributes]];
    [titleBarAttributes setValue:[UIFont fontWithName:@"GillSans-Light" size:20] forKey:NSFontAttributeName];
    [titleBarAttributes setValue:[UIColor whiteColor] forKey:NSForegroundColorAttributeName];
    [[UINavigationBar appearance] setTitleTextAttributes:titleBarAttributes];
    [[UINavigationBar appearance] setTintColor:[UIColor whiteColor]];
}

- (void)setupStatusBarStyle
{
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];
}

@end
