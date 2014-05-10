//
//  AspectsDemoTests.m
//  AspectsDemoTests
//
//  Created by Peter Steinberger on 03/05/14.
//  Copyright (c) 2014 PSPDFKit GmbH. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <objc/runtime.h>
#import "Aspects.h"

@interface TestClass : NSObject
@property (nonatomic, copy) NSString *string;
@property (nonatomic, assign) BOOL kvoTestCalled;
- (void)testCall;
- (void)testCallAndExecuteBlock:(dispatch_block_t)block;
- (double)callReturnsDouble;
- (long long)callReturnsLongLong;
@end

@implementation TestClass

- (void)testCall {
    NSLog(@"Original call");
}

- (void)testCallAndExecuteBlock:(dispatch_block_t)block {
    block();
}

- (CGRect)testThatReturnsAStruct {
    return CGRectMake(100, 100, 100, 100);
}

- (double)callReturnsDouble {
    return 1.5;
}

- (long long)callReturnsLongLong {
    return 99;
}

@end

@interface TestWithCustomForwardInvocation : NSObject
@property (nonatomic, assign) BOOL forwardInvocationCalled;
- (void)test;
@end

@implementation TestWithCustomForwardInvocation

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    if (aSelector == NSSelectorFromString(@"non_existing_selector")) {
        return [NSMethodSignature signatureWithObjCTypes:"v@:"];
    }
    return [super methodSignatureForSelector:aSelector];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
    NSLog(@"Custom!!!");
    self.forwardInvocationCalled = YES;
    if (anInvocation.selector != NSSelectorFromString(@"non_existing_selector")) {
        [super forwardInvocation:anInvocation];
    }
}

- (void)test {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

@end

@interface AspectsTests : XCTestCase @end

@implementation AspectsTests

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Generic Hook Tests

- (void)testCALayerExploding {
    __block BOOL called = NO;
    id globalAspect = [CALayer aspect_hookSelector:@selector(name) withOptions:AspectPositionAfter usingBlock:^(id instance, NSArray *arguments) {
        NSLog(@"Hello from %@", instance);
        called = YES;
    } error:NULL];

    // We had some branches where this blew up already.
    CALayer *test = [CALayer new];
    XCTAssertNotNil(test);
    [test name];
    XCTAssertTrue(called, @"Flag needs to be called.");

    XCTAssertTrue([globalAspect remove]);
}

- (void)testInsteadHook {
    // Test object replacement for UILabel.
    UILabel *testLabel = [UILabel new];
    testLabel.text = @"Default text";
    XCTAssertEqualObjects(testLabel.text, @"Default text", @"Must match");
    id aspect = [testLabel aspect_hookSelector:@selector(text) withOptions:AspectPositionInstead usingBlock:^(id instance, NSArray *arguments) {
        NSInvocation *invocation = arguments.lastObject;
        NSString *customText = @"Custom Text";
        [invocation setReturnValue:&customText];
    } error:NULL];
    XCTAssertEqualObjects(testLabel.text, @"Custom Text", @"Must match");

    // Test second object, and ensure that this doesn't change the override of the first object.
    UILabel *testLabel2 = [UILabel new];
    testLabel2.text = @"Default text2";
    XCTAssertEqualObjects(testLabel2.text, @"Default text2", @"Must match");
    id aspect2 = [testLabel2 aspect_hookSelector:@selector(text) withOptions:AspectPositionInstead usingBlock:^(id instance, NSArray *arguments) {
        NSInvocation *invocation = arguments.lastObject;
        NSString *customText = @"Custom Text2";
        [invocation setReturnValue:&customText];
    } error:NULL];
    XCTAssertEqualObjects(testLabel2.text, @"Custom Text2", @"Must match");

    // Globally override.
    id globalAspect = [UILabel aspect_hookSelector:@selector(text) withOptions:AspectPositionInstead usingBlock:^(id instance, NSArray *arguments) {
        NSInvocation *invocation = arguments.lastObject;
        NSString *customText = @"Global";
        [invocation setReturnValue:&customText];
    } error:NULL];
    XCTAssertEqualObjects(testLabel2.text, @"Custom Text2", @"Must match");

    UILabel *testLabel3 = [UILabel new];
    XCTAssertEqualObjects(testLabel3.text, @"Global", @"Must match");
    testLabel3.text = @"Test";
    XCTAssertEqualObjects(testLabel3.text, @"Global", @"Must match");
    XCTAssertTrue([globalAspect remove], @"Must work");
    XCTAssertEqualObjects(testLabel3.text, @"Test", @"Must match");

    // Test that removing an aspect returns the original.
    XCTAssertEqualObjects(testLabel.text, @"Default text", @"Must match"); // Note: since the global aspect is removed, it removes aspects on instances with the same selector name
    XCTAssertTrue([aspect remove], @"Must return YES");
    XCTAssertEqualObjects(testLabel.text, @"Default text", @"Must match");
    XCTAssertFalse([aspect remove], @"Must return NO");

    XCTAssertTrue([aspect2 remove], @"Must be able to deregister");
}

- (void)testAspectsCalledPerObject {
    TestClass *testClass = [TestClass new];

    __block BOOL called = NO;
    id aspect = [testClass aspect_hookSelector:@selector(testCall) withOptions:AspectPositionAfter usingBlock:^(id instance, NSArray *arguments) {
        called = YES;
    } error:NULL];
    [testClass testCall];
    XCTAssertTrue(called, @"Flag must have been set.");

    TestClass *testClass2 = [TestClass new];
    called = NO;
    [testClass2 testCall];
    XCTAssertFalse(called, @"Flag must have been NOT set.");

    XCTAssertTrue([aspect remove], @"Must be able to deregister");
}

- (void)testExecutionOrderAndMultipleRegistation {
    __block BOOL called_before = NO;
    __block BOOL called_after  = NO;
    __block BOOL called_after2 = NO;
    id aspect_before = [TestClass aspect_hookSelector:@selector(testCallAndExecuteBlock:) withOptions:AspectPositionBefore usingBlock:^(id instance, NSArray *arguments) {
        called_before = YES;
    } error:NULL];
    id aspect_after = [TestClass aspect_hookSelector:@selector(testCallAndExecuteBlock:) withOptions:AspectPositionAfter usingBlock:^(id instance, NSArray *arguments) {
        called_after2 = YES;
    } error:NULL];
    id aspect_after2 = [TestClass aspect_hookSelector:@selector(testCallAndExecuteBlock:) withOptions:AspectPositionAfter usingBlock:^(id instance, NSArray *arguments) {
        called_after = YES;
    } error:NULL];
    TestClass *testClass = [TestClass new];
    [testClass testCallAndExecuteBlock:^{
        XCTAssertTrue(called_before, @"Flag must have been set.");
        XCTAssertFalse(called_after, @"Flag must have not been set.");
        XCTAssertFalse(called_after2, @"Flag must have not been set.");
    }];

    XCTAssertTrue(called_before, @"Flag must have been set.");
    XCTAssertTrue(called_after, @"Flag must have been set.");
    XCTAssertTrue(called_after2, @"Flag must have been set.");

    XCTAssertTrue([aspect_after remove], @"Must be able to deregister");
    XCTAssertTrue([aspect_before remove], @"Must be able to deregister");
    XCTAssertTrue([aspect_after2 remove], @"Must be able to deregister");
    XCTAssertFalse([aspect_after remove], @"Must not be able to deregister twice");
    XCTAssertFalse([aspect_before remove], @"Must not be able to deregister twice");
    XCTAssertFalse([aspect_after2 remove], @"Must not be able to deregister twice");
}

- (void)testExample {
    TestClass *testClass = [TestClass new];
    TestClass *testClass2 = [TestClass new];

    __block BOOL testCallCalled = NO;
    id aspectToken = [testClass aspect_hookSelector:@selector(testCall) withOptions:AspectPositionAfter usingBlock:^(id instance, NSArray *arguments) {
        testCallCalled = YES;
    } error:NULL];

    [testClass2 testCallAndExecuteBlock:^{
        [testClass testCall];
    }];
    XCTAssertTrue(testCallCalled, @"Calling testCallAndExecuteBlock must call testCall");
    XCTAssertTrue([aspectToken remove], @"Must be able to deregister");
}

- (void)testStructReturn {
    TestClass *testClass = [TestClass new];
    CGRect rect = [testClass testThatReturnsAStruct];
    id aspect = [testClass aspect_hookSelector:@selector(testThatReturnsAStruct) withOptions:AspectPositionAfter usingBlock:^(id instance, NSArray *arguments) {
    } error:NULL];

    CGRect rectHooked = [testClass testThatReturnsAStruct];
    XCTAssertTrue(CGRectEqualToRect(rect, rectHooked), @"Must be equal");
    XCTAssertTrue([aspect remove], @"Must be able to deregister");
}

- (void)testDoubleReturn {
    TestClass *testClass = [TestClass new];
    double d1 = [testClass callReturnsDouble];
    __block BOOL testCallCalled = NO;
    id aspect = [testClass aspect_hookSelector:@selector(callReturnsDouble) withOptions:AspectPositionAfter usingBlock:^(id instance, NSArray *arguments) {
        testCallCalled = YES;
    } error:NULL];
    double d2 = [testClass callReturnsDouble];

    XCTAssertEqual(d1, d2, @"Must be equal");
    XCTAssertTrue(testCallCalled, @"Must call hook");
    XCTAssertTrue([aspect remove], @"Must be able to deregister");
}

- (void)testLongLongReturn {
    TestClass *testClass = [TestClass new];
    long long d1 = [testClass callReturnsLongLong];
    __block BOOL testCallCalled = NO;
    id aspect = [testClass aspect_hookSelector:@selector(callReturnsLongLong) withOptions:AspectPositionAfter usingBlock:^(id instance, NSArray *arguments) {
        testCallCalled = YES;
    } error:NULL];
    long long d2 = [testClass callReturnsLongLong];

    XCTAssertEqual(d1, d2, @"Must be equal");
    XCTAssertTrue(testCallCalled, @"Must call hook");
    XCTAssertTrue([aspect remove], @"Must be able to deregister");
}

- (void)testHookReleaseIsNotAllowed {
    TestClass *testClass = [TestClass new];

    __block BOOL testCallCalled = NO;
    id aspectToken = [testClass aspect_hookSelector:NSSelectorFromString(@"release") withOptions:AspectPositionAfter usingBlock:^(id instance, NSArray *arguments) {
        testCallCalled = YES;
    } error:NULL];
    XCTAssertNil(aspectToken, @"Token must be nil");

    [testClass testCall];
    XCTAssertFalse(testCallCalled, @"Release should not be hookable");
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Test dealloc hooking

// Hooking for deallic is delicate, but should work for AspectPositionBefore and AspectPositionAfter.
- (void)testDeallocHooking {
    TestClass *testClass = [TestClass new];

    __block BOOL testCallCalled = NO;
    __block id aspectToken = [testClass aspect_hookSelector:NSSelectorFromString(@"dealloc") withOptions:AspectPositionBefore usingBlock:^(id object, NSArray *arguments) {
        testCallCalled = YES;
        NSLog(@"called from dealloc");
    } error:NULL];
    XCTAssertNotNil(aspectToken, @"Must return a token.");

    testClass = nil;
    XCTAssertTrue(testCallCalled, @"Dealloc-hook must work.");
}

// Replacing dealloc should not work.
- (void)testDeallocReplacing {
    TestClass *testClass = [TestClass new];

    NSError *error;
    __block BOOL deallocCalled = NO;
    id aspectToken = [testClass aspect_hookSelector:NSSelectorFromString(@"dealloc") withOptions:AspectPositionInstead usingBlock:^(id object, NSArray *arguments) {
        deallocCalled = YES;
        NSLog(@"called from dealloc");
    } error:&error];
    XCTAssertNil(aspectToken, @"Must NOT return a token.");
    XCTAssertEqual(error.code, AspectsErrorSelectorDeallocPosition, @"Error must be correct");

    testClass = nil;
    XCTAssertFalse(deallocCalled, @"Dealloc-hook must not work.");
}

- (void)testInvalidSelectorHooking {
    TestClass *testClass = [TestClass new];
    NSError *error;
    __block id aspectToken = [testClass aspect_hookSelector:NSSelectorFromString(@"fakeSelector") withOptions:AspectPositionBefore usingBlock:^(id object, NSArray *arguments) {
    } error:&error];
    XCTAssertNil(aspectToken, @"Must return nil token.");
    XCTAssertEqual(error.code, AspectsErrorDoesNotRespondToSelector, @"Error code must match");
}

- (void)testInvalidGlobalSelectorHooking {
    NSError *error;
    __block id aspectToken = [TestClass aspect_hookSelector:NSSelectorFromString(@"fakeSelector2") withOptions:AspectPositionBefore usingBlock:^(id object, NSArray *arguments) {
    } error:&error];
    XCTAssertNil(aspectToken, @"Must return nil token.");
    XCTAssertEqual(error.code, AspectsErrorDoesNotRespondToSelector, @"Error code must match");
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Test Deregistration

- (void)testInstanceTokenDeregistration {
    TestClass *testClass = [TestClass new];

    __block BOOL testCallCalled = NO;
    id aspectToken = [testClass aspect_hookSelector:@selector(testCall) withOptions:AspectPositionInstead usingBlock:^(__unsafe_unretained id object, NSArray *arguments) {
        testCallCalled = YES;
    } error:NULL];
    XCTAssertNotNil(aspectToken, @"Must return a token.");

    [testClass testCall];
    XCTAssertTrue(testCallCalled, @"Hook must work.");

    XCTAssertNotEqualObjects(testClass.class, object_getClass(testClass), @"Object must have a custom subclass.");

    XCTAssertTrue([aspectToken remove], @"Deregistration must work");
    XCTAssertEqualObjects(testClass.class, object_getClass(testClass), @"Object must not have a custom subclass.");

    testCallCalled = NO;
    [testClass testCall];
    XCTAssertFalse(testCallCalled, @"Hook must no longer work.");

    XCTAssertFalse([aspectToken remove], @"Deregistration must not work twice");
}

- (void)testGlobalTokenDeregistration {
    __block BOOL testCallCalled = NO;
    id token = [TestClass aspect_hookSelector:@selector(testCall) withOptions:AspectPositionInstead usingBlock:^(__unsafe_unretained id object, NSArray *arguments) {
        testCallCalled = YES;
    } error:NULL];
    XCTAssertNotNil(token, @"Must return a token.");

    TestClass *testClass = [TestClass new];
    [testClass testCall];
    XCTAssertTrue(testCallCalled, @"Hook must work.");

    XCTAssertTrue([token remove], @"Deregistration must work");

    // Test that forwardInvocation (again) points to NSObject and thus is correctly restored.
    {
        Method forwardInvocationMethod = class_getInstanceMethod(testClass.class, @selector(forwardInvocation:));
        Method objectMethod = class_getInstanceMethod(NSObject.class, @selector(forwardInvocation:));
        XCTAssertEqual(method_getImplementation(forwardInvocationMethod), method_getImplementation(objectMethod), @"Implementations must be equal");
    }

    testCallCalled = NO;
    [testClass testCall];
    XCTAssertFalse(testCallCalled, @"Hook must no longer work.");

    XCTAssertFalse([token remove], @"Deregistration must not work twice");
}

- (void)testSimpleDeregistration {
    __block BOOL called = NO;
    id aspectToken = [TestClass aspect_hookSelector:@selector(testCall) withOptions:AspectPositionAfter usingBlock:^(id instance, NSArray *arguments) {
        called = YES;
    } error:NULL];
    TestClass *testClass = [TestClass new];
    [testClass testCall];
    XCTAssertTrue(called, @"Flag must have been set.");

    called = NO;
    XCTAssertTrue([aspectToken remove], @"Must allow deregistration");
    [testClass testCall];
    XCTAssertFalse(called, @"Flag must have been NOT set.");
}

- (void)testAutoDeregistration {
    TestClass *testClass = [TestClass new];

    __block BOOL testCallCalled = NO;
    id aspectToken = [testClass aspect_hookSelector:@selector(testCall) withOptions:AspectPositionAfter|AspectOptionAutomaticRemoval usingBlock:^(id instance, NSArray *arguments) {
        testCallCalled = YES;
    } error:NULL];

    [testClass testCall];
    XCTAssertTrue(testCallCalled, @"Must be set to YES");

    testCallCalled = NO;
    [testClass testCall];
    XCTAssertFalse(testCallCalled, @"Must be set to NO");

    XCTAssertFalse([aspectToken remove], @"Must not able to deregister again");
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Test KVO

- (void)testKVOCoexistance {
    TestClass *testClass = [TestClass new];

    __block BOOL hookCalled = NO;
    id aspectToken = [testClass aspect_hookSelector:@selector(setString:) withOptions:AspectPositionAfter usingBlock:^(id instance, NSArray *arguments) {
        NSLog(@"Aspect hook!");
        hookCalled = YES;
    } error:NULL];
    [testClass addObserver:self forKeyPath:NSStringFromSelector(@selector(string)) options:0 context:_cmd];

    XCTAssertFalse(testClass.kvoTestCalled, @"KVO must be not set");
    testClass.string = @"test";
    XCTAssertTrue(hookCalled, @"Hook must be called");
    XCTAssertTrue(testClass.kvoTestCalled, @"KVO must work");
    [testClass removeObserver:self forKeyPath:NSStringFromSelector(@selector(string)) context:_cmd];
    hookCalled = NO;
    testClass.kvoTestCalled = NO;
    testClass.string = @"test2";
    XCTAssertTrue(hookCalled, @"Hook must be called");
    XCTAssertFalse(testClass.kvoTestCalled, @"KVO must no longer work");

    XCTAssertTrue([aspectToken remove], @"Must be able to deregister");
}

// TODO: Pre-registeded KVO is currently not working.
//- (void)testKVOCoexistanceWithPreregisteredKVO {
//    TestClass *testClass = [TestClass new];
//    XCTAssertFalse(testClass.kvoTestCalled, @"KVO must be not set");
//    [testClass addObserver:self forKeyPath:NSStringFromSelector(@selector(string)) options:0 context:_cmd];
//    testClass.string = @"test";
//    XCTAssertTrue(testClass.kvoTestCalled, @"KVO must work");
//
//    __block BOOL hookCalled = NO;
//    [testClass aspect_hookSelector:@selector(setString:) withOptions:AspectPositionAfter usingBlock:^(id instance, NSArray *arguments) {
//        NSLog(@"Aspect hook!");
//        hookCalled = YES;
//    }];
//
//    XCTAssertFalse(testClass.kvoTestCalled, @"KVO must be not set");
//    testClass.string = @"test";
//    XCTAssertTrue(hookCalled, @"Hook must be called");
//    XCTAssertTrue(testClass.kvoTestCalled, @"KVO must work");
//    [testClass removeObserver:self forKeyPath:NSStringFromSelector(@selector(string)) context:_cmd];
//    hookCalled = NO;
//    testClass.kvoTestCalled = NO;
//    testClass.string = @"test2";
//    XCTAssertTrue(hookCalled, @"Hook must be called");
//    XCTAssertFalse(testClass.kvoTestCalled, @"KVO must no longer work");
//}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    NSLog(@"KVO!");
    ((TestClass *)object).kvoTestCalled = YES;
}

@end

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Test that a custom forwardInvocation: is being called.

@interface AspectsForwardInvocationTests : XCTestCase @end
@implementation AspectsForwardInvocationTests

- (void)testEnsureForwardInvocationIsCalled {
    TestWithCustomForwardInvocation *testClass = [TestWithCustomForwardInvocation new];
    XCTAssertFalse(testClass.forwardInvocationCalled, @"Must have not called custom forwardInvocation:");
    id aspectToken = [TestWithCustomForwardInvocation aspect_hookSelector:@selector(test) withOptions:AspectPositionInstead usingBlock:^(id instance, NSArray *arguments) {
        NSLog(@"Aspect hook called");
    } error:NULL];
    [testClass test];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [testClass performSelector:NSSelectorFromString(@"non_existing_selector")];
#pragma clang diagnostic pop
    XCTAssertTrue(testClass.forwardInvocationCalled, @"Must have called custom forwardInvocation:");

    XCTAssertTrue([aspectToken remove], @"Must be able to deregister");
}

@end

