//
//  AspectsHookTests.m
//  AspectsDemoTests
//
//  Created by Justin.wang on 2018/3/19.
//  Copyright © 2018年 PSPDFKit GmbH. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "Aspects.h"
#import "AspectsSwizz.h"

@interface UIViewController (Hook)

@end

@implementation UIViewController (Hook)

- (void)hook_viewDidAppear:(BOOL)animated {
    NSLog(@"Hook viewDidAppear");
    [self hook_viewDidAppear:animated];
}

@end


@interface AspectsHookTests : XCTestCase

@end

@implementation AspectsHookTests

- (void)testOtherAopFrameworkHookLater {
    [[UIViewController class] aspect_hookSelector:@selector(viewDidAppear:)
                                      withOptions:AspectPositionBefore
                                       usingBlock:^(id invoke) {
                                           NSLog(@"Aspects viewDidAppear");
                                       } error:NULL];
    
    [AspectsSwizz swizzingInstanceMethodByClass:[UIViewController class]
                                 originSelector:@selector(viewDidAppear:)
                               swizzingSelector:@selector(hook_viewDidAppear:)];
    UIViewController *vc = [[UIViewController alloc] init];
    @try {
        [vc viewDidAppear:YES];
        XCTAssertTrue(NO, @"viewDidAppear should throw a exception");
    } @catch (NSException *e) {
        XCTAssertTrue(YES, @"should catch a exception");
    }
    
    [AspectManager shareManager].messagePrefixArray= @[@"hook_"];
    @try {
        [vc viewDidAppear:YES];
    } @catch (NSException *e) {
        XCTAssertTrue(NO, @"should not throw a exception");
    }
}


@end
