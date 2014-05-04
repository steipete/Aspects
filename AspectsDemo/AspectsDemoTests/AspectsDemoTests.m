//
//  AspectsDemoTests.m
//  AspectsDemoTests
//
//  Created by Peter Steinberger on 03/05/14.
//  Copyright (c) 2014 PSPDFKit GmbH. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <objc/runtime.h>
#import "NSObject+Aspects.h"

@interface TestClass : NSObject
@property (nonatomic, copy) NSString *string;
@property (nonatomic, assign) BOOL kvoTestCalled;
- (void)testCall;
- (void)testCallAndExecuteBlock:(dispatch_block_t)block;
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

- (void)testInsteadHook {
    // Test object replacement for UILabel.
    UILabel *testLabel = [UILabel new];
    testLabel.text = @"Default text";
    XCTAssertEqualObjects(testLabel.text, @"Default text", @"Must match");
    id aspect = [testLabel aspect_hookSelector:@selector(text) atPosition:AspectPositionInstead withBlock:^(id object, NSArray *arguments) {
        NSInvocation *invocation = arguments.lastObject;
        NSString *customText = @"Custom Text";
        [invocation setReturnValue:&customText];
    }];
    XCTAssertEqualObjects(testLabel.text, @"Custom Text", @"Must match");

    // Test second object, and ensure that this doesn't change the override of the first object.
    UILabel *testLabel2 = [UILabel new];
    testLabel2.text = @"Default text2";
    XCTAssertEqualObjects(testLabel2.text, @"Default text2", @"Must match");
    [testLabel2 aspect_hookSelector:@selector(text) atPosition:AspectPositionInstead withBlock:^(id object, NSArray *arguments) {
        NSInvocation *invocation = arguments.lastObject;
        NSString *customText = @"Custom Text2";
        [invocation setReturnValue:&customText];
    }];
    XCTAssertEqualObjects(testLabel2.text, @"Custom Text2", @"Must match");

    // Globally override.
    id globalAspect = [UILabel aspect_hookSelector:@selector(text) atPosition:AspectPositionInstead withBlock:^(id object, NSArray *arguments) {
        NSInvocation *invocation = arguments.lastObject;
        NSString *customText = @"Global";
        [invocation setReturnValue:&customText];
    }];
    XCTAssertEqualObjects(testLabel2.text, @"Custom Text2", @"Must match");

    UILabel *testLabel3 = [UILabel new];
    XCTAssertEqualObjects(testLabel3.text, @"Global", @"Must match");
    testLabel3.text = @"Test";
    XCTAssertEqualObjects(testLabel3.text, @"Global", @"Must match");
    [UILabel aspect_remove:globalAspect];
    XCTAssertEqualObjects(testLabel3.text, @"Test", @"Must match");

    // Test that removing an aspect returns the original.
    XCTAssertEqualObjects(testLabel.text, @"Custom Text", @"Must match");
    XCTAssertTrue([UILabel aspect_remove:aspect], @"Must return YES");
    XCTAssertEqualObjects(testLabel.text, @"Default text", @"Must match");
    XCTAssertFalse([UILabel aspect_remove:aspect], @"Must return NO");
}

- (void)testAspectsCalledPerObject {
    TestClass *testClass = [TestClass new];

    __block BOOL called = NO;
    [testClass aspect_hookSelector:@selector(testCall) atPosition:AspectPositionAfter withBlock:^(id object, NSArray *arguments) {
        called = YES;
    }];
    [testClass testCall];
    XCTAssertTrue(called, @"Flag must have been set.");

    TestClass *testClass2 = [TestClass new];
    called = NO;
    [testClass2 testCall];
    XCTAssertFalse(called, @"Flag must have been NOT set.");
}

- (void)testExecutionOrderAndMultipleRegistation {
    TestClass *testClass = [TestClass new];

    __block BOOL called_before = NO;
    __block BOOL called_after  = NO;
    __block BOOL called_after2 = NO;
    __unused id aspect_before = [TestClass aspect_hookSelector:@selector(testCallAndExecuteBlock:) atPosition:AspectPositionBefore withBlock:^(id object, NSArray *arguments) {
        called_before = YES;
    }];
    id aspect_after = [TestClass aspect_hookSelector:@selector(testCallAndExecuteBlock:) atPosition:AspectPositionAfter withBlock:^(id object, NSArray *arguments) {
        called_after2 = YES;
    }];
    __unused id aspect_after2 = [TestClass aspect_hookSelector:@selector(testCallAndExecuteBlock:) atPosition:AspectPositionAfter withBlock:^(id object, NSArray *arguments) {
        called_after = YES;
    }];
    [testClass testCallAndExecuteBlock:^{
        XCTAssertTrue(called_before, @"Flag must have been set.");
        XCTAssertFalse(called_after, @"Flag must have not been set.");
        XCTAssertFalse(called_after2, @"Flag must have not been set.");
    }];
    [TestClass aspect_remove:aspect_after];

    XCTAssertTrue(called_before, @"Flag must have been set.");
    XCTAssertTrue(called_after, @"Flag must have been set.");
    XCTAssertTrue(called_after2, @"Flag must have been set.");
}

- (void)testExample {
    TestClass *testClass = [TestClass new];
    TestClass *testClass2 = [TestClass new];

    __block BOOL testCallCalled = NO;
    [testClass aspect_hookSelector:@selector(testCall) atPosition:AspectPositionAfter withBlock:^(id object, NSArray *arguments) {
        testCallCalled = YES;
    }];

    [testClass2 testCallAndExecuteBlock:^{
        [testClass testCall];
    }];
    XCTAssertTrue(testCallCalled, @"Calling testCallAndExecuteBlock must call testCall");
}

- (void)testStructReturn {
    TestClass *testClass = [TestClass new];
    CGRect rect = [testClass testThatReturnsAStruct];
    [testClass aspect_hookSelector:@selector(testThatReturnsAStruct) atPosition:AspectPositionAfter withBlock:^(id object, NSArray *arguments) {
    }];

    CGRect rectHooked = [testClass testThatReturnsAStruct];
    XCTAssertTrue(CGRectEqualToRect(rect, rectHooked), @"Must be equal");
}

- (void)testHookReleaseIsNotAllowed {
    TestClass *testClass = [TestClass new];

    __block BOOL testCallCalled = NO;
    id token = [testClass aspect_hookSelector:NSSelectorFromString(@"release") atPosition:AspectPositionAfter withBlock:^(id object, NSArray *arguments) {
        testCallCalled = YES;
    }];
    XCTAssertNil(token, @"Token must be nil");

    [testClass testCall];
    XCTAssertFalse(testCallCalled, @"Release should not be hookable");
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Test dealloc hooking

// Hooking for deallic is delicate, but should work for AspectPositionBefore and AspectPositionAfter.
- (void)testDeallocHooking {
    TestClass *testClass = [TestClass new];

    __block BOOL testCallCalled = NO;
    id token = [testClass aspect_hookSelector:NSSelectorFromString(@"dealloc") atPosition:AspectPositionAfter withBlock:^(__unsafe_unretained id object, NSArray *arguments) {
        testCallCalled = YES;
        NSLog(@"called from dealloc");
    }];
    XCTAssertNotNil(token, @"Must return a token.");

    testClass = nil;
    XCTAssertTrue(testCallCalled, @"Dealloc-hook must work.");
}

// Replacing dealloc should not work.
- (void)testDeallocReplacing {
    TestClass *testClass = [TestClass new];

    __block BOOL deallocCalled = NO;
    id token = [testClass aspect_hookSelector:NSSelectorFromString(@"dealloc") atPosition:AspectPositionInstead withBlock:^(__unsafe_unretained id object, NSArray *arguments) {
        deallocCalled = YES;
        NSLog(@"called from dealloc");
    }];
    XCTAssertNil(token, @"Must NOT return a token.");

    testClass = nil;
    XCTAssertFalse(deallocCalled, @"Dealloc-hook must not work.");
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Test Deregistration

- (void)testInstanceTokenDeregistration {
    TestClass *testClass = [TestClass new];

    __block BOOL testCallCalled = NO;
    id token = [testClass aspect_hookSelector:@selector(testCall) atPosition:AspectPositionInstead withBlock:^(__unsafe_unretained id object, NSArray *arguments) {
        testCallCalled = YES;
    }];
    XCTAssertNotNil(token, @"Must return a token.");

    [testClass testCall];
    XCTAssertTrue(testCallCalled, @"Hook must work.");

    XCTAssertNotEqualObjects(testClass.class, object_getClass(testClass), @"Object must have a custom subclass.");

    XCTAssertTrue([TestClass aspect_remove:token], @"Deregistration must work");
    XCTAssertEqualObjects(testClass.class, object_getClass(testClass), @"Object must not have a custom subclass.");

    testCallCalled = NO;
    [testClass testCall];
    XCTAssertFalse(testCallCalled, @"Hook must no longer work.");

    XCTAssertFalse([TestClass aspect_remove:token], @"Deregistration must not work twice");
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
    id token = [TestWithCustomForwardInvocation aspect_hookSelector:@selector(test) atPosition:AspectPositionInstead withBlock:^(__unsafe_unretained id object, NSArray *arguments) {
        testCalled = YES;
    }];
    XCTAssertNotNil(token, @"Must return a token.");

    [testClass test];
    XCTAssertTrue(testCalled, @"Hook must work.");

    XCTAssertEqualObjects(testClass.class, object_getClass(testClass), @"Object must not have a custom subclass.");

    // Test that forwardInvocation points to our own implementation.
    {
        Method forwardInvocationMethod = class_getInstanceMethod(testClass.class, @selector(forwardInvocation:));
        XCTAssertNotEqual(method_getImplementation(forwardInvocationMethod), originalForwardInvocationIMP, @"Implementations must not be equal");
    }

    XCTAssertTrue([TestClass aspect_remove:token], @"Deregistration must work");

    // Test that forwardInvocation (again) points to NSObject and thus is correctly restored.
    {
        Method forwardInvocationMethod = class_getInstanceMethod(testClass.class, @selector(forwardInvocation:));
        XCTAssertEqual(method_getImplementation(forwardInvocationMethod), originalForwardInvocationIMP, @"Implementations must be equal");
    }

    testCalled = NO;
    [testClass test];
    XCTAssertFalse(testCalled, @"Hook must no longer work.");

    XCTAssertFalse([TestWithCustomForwardInvocation aspect_remove:token], @"Deregistration must not work twice");
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
    id token = [TestClass aspect_hookSelector:@selector(testCall) atPosition:AspectPositionInstead withBlock:^(__unsafe_unretained id object, NSArray *arguments) {
        testCallCalled = YES;
    }];
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

    XCTAssertTrue([TestClass aspect_remove:token], @"Deregistration must work");

    // Test that forwardInvocation (again) points to NSObject and thus is correctly restored.
    {
        Method forwardInvocationMethod = class_getInstanceMethod(testClass.class, @selector(forwardInvocation:));
        Method objectMethod = class_getInstanceMethod(NSObject.class, @selector(forwardInvocation:));
        XCTAssertEqual(method_getImplementation(forwardInvocationMethod), method_getImplementation(objectMethod), @"Implementations must be equal");
    }

    testCallCalled = NO;
    [testClass testCall];
    XCTAssertFalse(testCallCalled, @"Hook must no longer work.");

    XCTAssertFalse([TestClass aspect_remove:token], @"Deregistration must not work twice");
}

- (void)testSimpleDeregistration {
    TestClass *testClass = [TestClass new];

    __block BOOL called = NO;
    id aspect = [TestClass aspect_hookSelector:@selector(testCall) atPosition:AspectPositionAfter withBlock:^(id object, NSArray *arguments) {
        called = YES;
    }];
    [testClass testCall];
    XCTAssertTrue(called, @"Flag must have been set.");

    called = NO;
    [TestClass aspect_remove:aspect];
    [testClass testCall];
    XCTAssertFalse(called, @"Flag must have been NOT set.");
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Test KVO

- (void)testKVOCoexistance {
    TestClass *testClass = [TestClass new];

    __block BOOL hookCalled = NO;
    [testClass aspect_hookSelector:@selector(setString:) atPosition:AspectPositionAfter withBlock:^(id object, NSArray *arguments) {
        NSLog(@"Aspect hook!");
        hookCalled = YES;
    }];
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
//    [testClass aspect_hookSelector:@selector(setString:) atPosition:AspectPositionAfter withBlock:^(id object, NSArray *arguments) {
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
    [TestWithCustomForwardInvocation aspect_hookSelector:@selector(test) atPosition:AspectPositionInstead withBlock:^(id object, NSArray *arguments) {
        NSLog(@"Aspect hook called");
    }];
    [testClass test];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [testClass performSelector:NSSelectorFromString(@"non_existing_selector")];
#pragma clang diagnostic pop
    XCTAssertTrue(testClass.forwardInvocationCalled, @"Must have called custom forwardInvocation:");
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
@end

@interface B : A @end

@implementation B
- (void)foo {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    [super foo];
}
@end

@interface AspectsSelectorTests : XCTestCase @end
@implementation AspectsSelectorTests

//- (void)testSelectorMangling {
//    __block BOOL A_aspect_called = NO;
//    __block BOOL B_aspect_called = NO;
//    [B aspect_hookSelector:@selector(foo) atPosition:AspectPositionBefore withBlock:^(id object, NSArray *arguments) {
//        NSLog(@"before -[B foo]");
//        B_aspect_called = YES;
//    }];
//    [A aspect_hookSelector:@selector(foo) atPosition:AspectPositionBefore withBlock:^(id object, NSArray *arguments) {
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
    XCTAssertNotNil([A aspect_hookSelector:@selector(foo) atPosition:AspectPositionBefore withBlock:^(id object, NSArray *arguments) {
        NSLog(@"before -[A foo]");
        A_aspect_called = YES;
    }], @"Must return a token");
    XCTAssertNil([B aspect_hookSelector:@selector(foo) atPosition:AspectPositionBefore withBlock:^(id object, NSArray *arguments) {
        NSLog(@"before -[B foo]");
        B_aspect_called = YES;
    }], @"Must not return a token");

    B *b = [B new];
    [b foo];

    // TODO: A is not yet called, we can't detect the target IMP for an invocation.
    XCTAssertTrue(A_aspect_called, @"A aspect should be called");
    XCTAssertFalse(B_aspect_called, @"B aspect should not be called");
}

@end
