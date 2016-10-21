//
//  AspectsAppDelegate.m
//  AspectsDemo
//
//  Created by Peter Steinberger on 03/05/14.
//  Copyright (c) 2014 PSPDFKit GmbH. All rights reserved.
//

#import "AspectsAppDelegate.h"
#import "AspectsViewController.h"
#import "Aspects.h"
#import <objc/runtime.h>

@implementation AspectsAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    AspectsViewController *aspectsController = [AspectsViewController new];
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor whiteColor];
    self.window.rootViewController = [[UINavigationController alloc] initWithRootViewController:aspectsController];
    [self.window makeKeyAndVisible];

    // Ignore hooks when we are testing.
    if (!NSClassFromString(@"XCTestCase")) {
        [aspectsController aspect_hookSelector:@selector(buttonPressed:) withOptions:0 usingBlock:^(id info, id sender) {
            NSLog(@"Button was pressed by: %@", sender);
        } error:NULL];

        [aspectsController aspect_hookSelector:@selector(viewWillLayoutSubviews) withOptions:0 usingBlock:^{
            NSLog(@"Controller is layouting!");
        } error:NULL];
    }
    
    [AspectsViewController aspect_hookSelector:@selector(testInstanceMethod) withOptions:AspectPositionAfter usingBlock:^(id info) {
        NSLog(@"after InstanceMethod");
    } error:NULL];
    [aspectsController testInstanceMethod];

    Class Meta = objc_getMetaClass("AspectsViewController");
    [Meta aspect_hookSelector:@selector(testClassMethod) withOptions:AspectPositionAfter usingBlock:^(id info) {
        NSLog(@"after ClassMethod");
    } error:NULL];
    [AspectsViewController testClassMethod];
    
    return YES;
}

@end
