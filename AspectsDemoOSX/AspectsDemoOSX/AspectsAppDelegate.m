//
//  AspectsAppDelegate.m
//  AspectsDemoOSX
//
//  Created by Ash Furrow on 2014-05-05.
//  Copyright (c) 2014 PSPDFKit GmbH. All rights reserved.
//

#import "AspectsAppDelegate.h"
#import "Aspects.h"

@implementation AspectsAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Ignore hooks when we are testing.
    if (!NSClassFromString(@"XCTestCase")) {
        [self.window aspect_hookSelector:@selector(displayIfNeeded) withOptions:0 usingBlock:^(id instance, NSArray *arguments) {
            NSLog(@"Window is displayed!");
        } error:NULL];
    }
}

@end
