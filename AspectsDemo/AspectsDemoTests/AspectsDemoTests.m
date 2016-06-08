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
    if (block) block();
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
#pragma mark - Test Block Signature

- (void)testMatchingBlockSignature {
    TestClass *testClass = [TestClass new];

    __block BOOL called = NO;
    id aspect = [testClass aspect_hookSelector:@selector(testCall) withOptions:AspectPositionAfter usingBlock:^(id<AspectInfo> info) {
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

- (void)testMatchingBlockSignature2 {
    TestClass *testClass = [TestClass new];

    __block BOOL called = NO;
    id<AspectToken> aspect = [testClass aspect_hookSelector:@selector(testCallAndExecuteBlock:) withOptions:AspectPositionAfter usingBlock:^{
        called = YES;
    } error:NULL];
    [testClass testCallAndExecuteBlock:NULL];
    XCTAssertTrue(called, @"Flag must have been set.");

    TestClass *testClass2 = [TestClass new];
    called = NO;
    [testClass2 testCall];
    XCTAssertFalse(called, @"Flag must have been NOT set.");

    XCTAssertTrue([aspect remove], @"Must be able to deregister");
}

- (void)testTooLargeBlockSignature {
    TestClass *testClass = [TestClass new];

    NSError *error = nil;
    __block BOOL called = NO;
    id<AspectToken> aspect = [testClass aspect_hookSelector:@selector(testCallAndExecuteBlock:) withOptions:AspectPositionAfter usingBlock:^(id<AspectInfo> info, id test, id foo, id bar) {
        called = YES;
    } error:&error];
    [testClass testCallAndExecuteBlock:NULL];
    XCTAssertNil(aspect);
    XCTAssertTrue(error.code == AspectErrorIncompatibleBlockSignature);
    XCTAssertFalse(called, @"Flag must have not been set.");

    TestClass *testClass2 = [TestClass new];
    called = NO;
    [testClass2 testCall];
    XCTAssertFalse(called, @"Flag must have been NOT set.");
}

- (void)testMismatchingSignature {
    TestClass *testClass = [TestClass new];

    NSError *error = nil;
    __block BOOL called = NO;
    id<AspectToken> aspect = [testClass aspect_hookSelector:@selector(testCallAndExecuteBlock:) withOptions:AspectPositionAfter usingBlock:^(NSUInteger foobar) {
        called = YES;
    } error:&error];
    [testClass testCallAndExecuteBlock:NULL];
    XCTAssertNil(aspect);
    XCTAssertTrue(error.code == AspectErrorIncompatibleBlockSignature);
    XCTAssertFalse(called, @"Flag must have not been set.");

    TestClass *testClass2 = [TestClass new];
    called = NO;
    [testClass2 testCall];
    XCTAssertFalse(called, @"Flag must have been NOT set.");
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Generic Hook Tests

- (void)testCALayerExploding {
    __block BOOL called = NO;
    id globalAspect = [CALayer aspect_hookSelector:@selector(name) withOptions:AspectPositionAfter usingBlock:^(id<AspectInfo> info) {
        NSLog(@"Hello from %@", info.instance);
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
    // Test object replacement.
    CALayer *testObject = [CALayer new];
    testObject.name = @"Default text";
    XCTAssertEqualObjects(testObject.name, @"Default text", @"Must match");
    id aspect = [testObject aspect_hookSelector:@selector(name) withOptions:AspectPositionInstead usingBlock:^(id<AspectInfo> info) {
        NSString *customText = @"Custom Text";
        [[info originalInvocation] setReturnValue:&customText];
    } error:NULL];
    XCTAssertEqualObjects(testObject.name, @"Custom Text", @"Must match");

    // Test second object, and ensure that this doesn't change the override of the first object.
    CALayer *testObject2 = [CALayer new];
    testObject2.name = @"Default text2";
    XCTAssertEqualObjects(testObject2.name, @"Default text2", @"Must match");
    id aspect2 = [testObject2 aspect_hookSelector:@selector(name) withOptions:AspectPositionInstead usingBlock:^(id<AspectInfo> info) {
        NSString *customText = @"Custom Text2";
        [[info originalInvocation] setReturnValue:&customText];
    } error:NULL];
    XCTAssertEqualObjects(testObject2.name, @"Custom Text2", @"Must match");

    // Globally override.
    id globalAspect = [CALayer aspect_hookSelector:@selector(name) withOptions:AspectPositionAfter usingBlock:^(id<AspectInfo> info) {
        NSString *customText = @"Global";
        [[info originalInvocation] setReturnValue:&customText];
    } error:NULL];
    XCTAssertEqualObjects(testObject2.name, @"Global", @"Must match");

    CALayer *testObject3 = [CALayer new];
    XCTAssertEqualObjects(testObject3.name, @"Global", @"Must match");
    testObject3.name = @"Test";
    XCTAssertEqualObjects(testObject3.name, @"Global", @"Must match");
    XCTAssertTrue([globalAspect remove], @"Must work");
    XCTAssertEqualObjects(testObject3.name, @"Test", @"Must match");

    // Test that removing an aspect returns the original.
    XCTAssertEqualObjects(testObject.name, @"Custom Text", @"Must match");
    XCTAssertTrue([aspect remove], @"Must return YES");
    XCTAssertEqualObjects(testObject.name, @"Default text", @"Must match");
    XCTAssertFalse([aspect remove], @"Must return NO");

    XCTAssertTrue([aspect2 remove], @"Must be able to deregister");
}

- (void)testAspectsCalledPerObject {
    TestClass *testClass = [TestClass new];

    __block BOOL called = NO;
    id aspect = [testClass aspect_hookSelector:@selector(testCall) withOptions:AspectPositionAfter usingBlock:^(id<AspectInfo> info) {
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
    TestClass *testClass = [TestClass new];

    __block BOOL called_before = NO;
    __block BOOL called_after  = NO;
    __block BOOL called_after2 = NO;
    id aspect_before = [TestClass aspect_hookSelector:@selector(testCallAndExecuteBlock:) withOptions:AspectPositionBefore usingBlock:^(id<AspectInfo> info, id block) {
        called_before = YES;
    } error:NULL];
    id aspect_after = [TestClass aspect_hookSelector:@selector(testCallAndExecuteBlock:) withOptions:AspectPositionAfter usingBlock:^(id<AspectInfo> info, id block) {
        called_after2 = YES;
    } error:NULL];
    id aspect_after2 = [TestClass aspect_hookSelector:@selector(testCallAndExecuteBlock:) withOptions:AspectPositionAfter usingBlock:^(id<AspectInfo> info, id block) {
        called_after = YES;
    } error:NULL];
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
    id aspectToken = [testClass aspect_hookSelector:@selector(testCall) withOptions:AspectPositionAfter usingBlock:^(id<AspectInfo> info) {
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
    id aspect = [testClass aspect_hookSelector:@selector(testThatReturnsAStruct) withOptions:AspectPositionAfter usingBlock:^(id<AspectInfo> info) {
    } error:NULL];

    CGRect rectHooked = [testClass testThatReturnsAStruct];
    XCTAssertTrue(CGRectEqualToRect(rect, rectHooked), @"Must be equal");
    XCTAssertTrue([aspect remove], @"Must be able to deregister");
}

- (void)testDoubleReturn {
    TestClass *testClass = [TestClass new];
    double d1 = [testClass callReturnsDouble];
    __block BOOL testCallCalled = NO;
    id aspect = [testClass aspect_hookSelector:@selector(callReturnsDouble) withOptions:AspectPositionAfter usingBlock:^(id<AspectInfo> info) {
        testCallCalled = YES;
    } error:NULL];
    double d2 = [testClass callReturnsDouble];

    XCTAssertEqual(d1, d2, @"Must be equal");
    XCTAssertTrue(testCallCalled, @"Must call hook");
    XCTAssertTrue([aspect remove], @"Must be able to deregister");
}

- (void)testDoubleReturnInstead {
    TestClass *testClass = [TestClass new];
    double previousExpectedValue = [testClass callReturnsDouble];
    double expectedValue = 3.5;
    
    id aspect = [testClass aspect_hookSelector:@selector(callReturnsDouble) withOptions:AspectPositionInstead usingBlock:^(id<AspectInfo> info){
        double toReturn = 3.5;
        void *ptr = &toReturn;
        [info.originalInvocation setReturnValue:ptr];
    }error:NULL];
    double actualValue = [testClass callReturnsDouble];
    
    XCTAssertNotEqual(previousExpectedValue, actualValue, @"Must not return what it returned before we called our Instead");
    XCTAssertEqual(expectedValue, actualValue, @"Must be equal");
    XCTAssertTrue([aspect remove], @"Must be able to deregister");
}

- (void)testLongLongReturn {
    TestClass *testClass = [TestClass new];
    long long d1 = [testClass callReturnsLongLong];
    __block BOOL testCallCalled = NO;
    id aspect = [testClass aspect_hookSelector:@selector(callReturnsLongLong) withOptions:AspectPositionAfter usingBlock:^(id<AspectInfo> info) {
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
    id aspectToken = [testClass aspect_hookSelector:NSSelectorFromString(@"release") withOptions:AspectPositionAfter usingBlock:^(id<AspectInfo> info) {
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
    __block id aspectToken = [testClass aspect_hookSelector:NSSelectorFromString(@"dealloc") withOptions:AspectPositionBefore usingBlock:^(id<AspectInfo> info) {
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
    id aspectToken = [testClass aspect_hookSelector:NSSelectorFromString(@"dealloc") withOptions:AspectPositionInstead usingBlock:^(id<AspectInfo> info) {
        deallocCalled = YES;
        NSLog(@"called from dealloc");
    } error:&error];
    XCTAssertNil(aspectToken, @"Must NOT return a token.");
    XCTAssertEqual(error.code, AspectErrorSelectorDeallocPosition, @"Error must be correct");

    testClass = nil;
    XCTAssertFalse(deallocCalled, @"Dealloc-hook must not work.");
}

- (void)testInvalidSelectorHooking {
    TestClass *testClass = [TestClass new];
    NSError *error;
    __block id aspectToken = [testClass aspect_hookSelector:NSSelectorFromString(@"fakeSelector") withOptions:AspectPositionBefore usingBlock:^(id<AspectInfo> info) {
    } error:&error];
    XCTAssertNil(aspectToken, @"Must return nil token.");
    XCTAssertEqual(error.code, AspectErrorDoesNotRespondToSelector, @"Error code must match");
}

- (void)testInvalidGlobalSelectorHooking {
    NSError *error;
    __block id aspectToken = [TestClass aspect_hookSelector:NSSelectorFromString(@"fakeSelector2") withOptions:AspectPositionBefore usingBlock:^(id<AspectInfo> info) {
    } error:&error];
    XCTAssertNil(aspectToken, @"Must return nil token.");
    XCTAssertEqual(error.code, AspectErrorDoesNotRespondToSelector, @"Error code must match");
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Test Deregistration

- (void)testInstanceTokenDeregistration {
    TestClass *testClass = [TestClass new];

    __block BOOL testCallCalled = NO;
    id aspectToken = [testClass aspect_hookSelector:@selector(testCall) withOptions:AspectPositionInstead usingBlock:^(id<AspectInfo> info) {
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

- (void)testGlobalTokenDeregistrationWithCustomForwardInvocation {
    TestWithCustomForwardInvocation *testClass = [TestWithCustomForwardInvocation new];
    Method originalForwardInvocationMethod = class_getInstanceMethod(testClass.class, @selector(forwardInvocation:));
    IMP originalForwardInvocationIMP = method_getImplementation(originalForwardInvocationMethod);

    // Test that forwardInvocation points to NSObject.
    {
        Method objectMethod = class_getInstanceMethod(TestWithCustomForwardInvocation.class, @selector(forwardInvocation:));
        XCTAssertEqual(method_getImplementation(originalForwardInvocationMethod), method_getImplementation(objectMethod), @"Implementations must be equal");
    }

    __block BOOL testCalled = NO;
    id token = [TestWithCustomForwardInvocation aspect_hookSelector:@selector(test) withOptions:AspectPositionInstead usingBlock:^(id<AspectInfo> info) {
        testCalled = YES;
    } error:NULL];
    XCTAssertNotNil(token, @"Must return a token.");

    [testClass test];
    XCTAssertTrue(testCalled, @"Hook must work.");

    XCTAssertEqualObjects(testClass.class, object_getClass(testClass), @"Object must not have a custom subclass.");

    // Test that forwardInvocation points to our own implementation.
    {
        Method forwardInvocationMethod = class_getInstanceMethod(testClass.class, @selector(forwardInvocation:));
        XCTAssertNotEqual(method_getImplementation(forwardInvocationMethod), originalForwardInvocationIMP, @"Implementations must not be equal");
    }

    XCTAssertTrue([token remove], @"Deregistration must work");

    // Test that forwardInvocation (again) points to NSObject and thus is correctly restored.
    {
        Method forwardInvocationMethod = class_getInstanceMethod(testClass.class, @selector(forwardInvocation:));
        XCTAssertEqual(method_getImplementation(forwardInvocationMethod), originalForwardInvocationIMP, @"Implementations must be equal");
    }

    testCalled = NO;
    [testClass test];
    XCTAssertFalse(testCalled, @"Hook must no longer work.");

    XCTAssertFalse([token remove], @"Deregistration must not work twice");
}

- (void)testGlobalTokenDeregistration {
    TestClass *testClass = [TestClass new];

    // Test that forwardInvocation points to NSObject.
    {
        Method forwardInvocationMethod = class_getInstanceMethod(testClass.class, @selector(forwardInvocation:));
        Method objectMethod = class_getInstanceMethod(NSObject.class, @selector(forwardInvocation:));
        XCTAssertEqual(method_getImplementation(forwardInvocationMethod), method_getImplementation(objectMethod), @"Implementations must be equal");
    }

    __block BOOL testCallCalled = NO;
    id token = [TestClass aspect_hookSelector:@selector(testCall) withOptions:AspectPositionInstead usingBlock:^(id<AspectInfo> info) {
        testCallCalled = YES;
    } error:NULL];
    XCTAssertNotNil(token, @"Must return a token.");

    [testClass testCall];
    XCTAssertTrue(testCallCalled, @"Hook must work.");

    XCTAssertEqualObjects(testClass.class, object_getClass(testClass), @"Object must not have a custom subclass.");

    // Test that forwardInvocation points to our own implementation.
    {
        Method forwardInvocationMethod = class_getInstanceMethod(testClass.class, @selector(forwardInvocation:));
        Method objectMethod = class_getInstanceMethod(NSObject.class, @selector(forwardInvocation:));
        XCTAssertNotEqual(method_getImplementation(forwardInvocationMethod), method_getImplementation(objectMethod), @"Implementations must not be equal");
    }

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
    TestClass *testClass = [TestClass new];

    __block BOOL called = NO;
    id aspectToken = [TestClass aspect_hookSelector:@selector(testCall) withOptions:AspectPositionAfter usingBlock:^(id<AspectInfo> info) {
        called = YES;
    } error:NULL];
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
    id aspectToken = [testClass aspect_hookSelector:@selector(testCall) withOptions:AspectPositionAfter|AspectOptionAutomaticRemoval usingBlock:^(id<AspectInfo> info) {
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
    id aspectToken = [testClass aspect_hookSelector:@selector(setString:) withOptions:AspectPositionAfter usingBlock:^(id<AspectInfo> info, NSString *string) {
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
    id aspectToken = [TestWithCustomForwardInvocation aspect_hookSelector:@selector(test) withOptions:AspectPositionInstead usingBlock:^(id info) {
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

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Test Selector Mangling

@interface A : NSObject
- (void)foo;
@end

@implementation A
- (void)foo {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}
- (void)bar {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}
@end

@interface B : A @end

@implementation B
- (void)foo {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    [super foo];
}
- (void)bar {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    [super bar];
}
@end

@interface C : NSObject
- (void)foo;
@end

@implementation C
- (void)foo {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}
@end

@interface AspectsSelectorTests : XCTestCase @end
@implementation AspectsSelectorTests

//- (void)testSelectorMangling {
//    __block BOOL A_aspect_called = NO;
//    __block BOOL B_aspect_called = NO;
//    [B aspect_hookSelector:@selector(foo) withOptions:AspectPositionBefore usingBlock:^(id instance, NSArray *arguments) {
//        NSLog(@"before -[B foo]");
//        B_aspect_called = YES;
//    }];
//    [A aspect_hookSelector:@selector(foo) withOptions:AspectPositionBefore usingBlock:^(id instance, NSArray *arguments) {
//        NSLog(@"before -[A foo]");
//        A_aspect_called = YES;
//    }];
//
//    B *b = [B new];
//    [b foo];
//
//    XCTAssertTrue(B_aspect_called, @"B aspect should be called");
//    XCTAssertFalse(A_aspect_called, @"A aspect should not be called");
//}

// TODO: Since tests change the runtime, it's hard to clean up.
- (void)testSelectorMangling2 {
    __block BOOL A_aspect_called = NO;
    __block BOOL B_aspect_called = NO;
    __block BOOL C_aspect_called = NO;

    id aspectToken1 = [A aspect_hookSelector:@selector(foo) withOptions:AspectPositionBefore usingBlock:^(id<AspectInfo> info) {
        NSLog(@"before -[A foo]");
        A_aspect_called = YES;
    } error:NULL];
    XCTAssertNotNil(aspectToken1, @"Must return a token");

    id aspectToken2 = [B aspect_hookSelector:@selector(foo) withOptions:AspectPositionBefore usingBlock:^(id<AspectInfo> info) {
        NSLog(@"before -[B foo]");
        B_aspect_called = YES;
    } error:NULL];
    XCTAssertNil(aspectToken2, @"Must not return a token");

    // a sibling and it's subclasses should be able to hook the same selector
    id aspectToken3 = [C aspect_hookSelector:@selector(foo) withOptions:AspectPositionBefore usingBlock:^(id<AspectInfo> info) {
        NSLog(@"before -[C foo]");
        C_aspect_called = YES;
    } error:NULL];
    XCTAssertNotNil(aspectToken3, @"Must return a token");

    B *b = [B new];
    [b foo];

    // TODO: A is not yet called, we can't detect the target IMP for an invocation.
    XCTAssertTrue(A_aspect_called, @"A aspect should be called");
    XCTAssertFalse(B_aspect_called, @"B aspect should not be called");
    XCTAssertFalse(C_aspect_called, @"C aspect should not be called");

    C *c = [C new];
    [c foo];
    XCTAssertTrue(C_aspect_called, @"C aspect should be called");

    XCTAssertTrue([aspectToken1 remove], @"Must be able to deregister");
    XCTAssertTrue([aspectToken3 remove], @"Must be able to deregister");
}
- (void)testSelectorMangling3 {
    __block BOOL A_aspect_called = NO;
    __block BOOL B_aspect_called = NO;

    id aspectToken1 = [B aspect_hookSelector:@selector(bar) withOptions:AspectPositionBefore usingBlock:^(id<AspectInfo> info) {
        NSLog(@"before -[B bar]");
        B_aspect_called = YES;
    } error:NULL];
    XCTAssertNotNil(aspectToken1, @"Must return a token");

    // if a subclass already hooks this selector we shouldn't be able to hook it in a superclass
    id aspectToken2 = [A aspect_hookSelector:@selector(bar) withOptions:AspectPositionBefore usingBlock:^(id<AspectInfo> info) {
        NSLog(@"before -[A bar]");
        A_aspect_called = YES;
    } error:NULL];
    XCTAssertNil(aspectToken2, @"Must not return a token");

    B *b = [B new];
    [b bar];

    XCTAssertFalse(A_aspect_called, @"A aspect should not be called");
    XCTAssertTrue(B_aspect_called, @"B aspect should be called");

    XCTAssertTrue([aspectToken1 remove], @"Must be able to deregister");
}

@end
