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

@implementation AspectsAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  [AspectsViewController aspect_hookSelector:@selector(viewDidLoad) withOptions:AspectPositionBefore usingBlock:^ {
    NSLog(@"viewDidLoad before");
  }error:nil];
  [AspectsViewController aspect_hookSelector:@selector(viewWillAppear:) withOptions:AspectPositionAfter usingBlock:^(id<AspectInfo> aspectInfo,BOOL animated) {
    NSLog(@"viewWillAppear After");
  }error:nil];
  [AspectsViewController aspect_hookSelector:@selector(viewDidAppear:) withOptions:AspectPositionInstead usingBlock:^(id<AspectInfo> aspectInfo,BOOL animated) {
    NSLog(@"viewDidAppear Instead");
  }error:nil];
    return YES;
}

@end
