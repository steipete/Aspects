Aspects v1.0.1 [![Build Status](https://travis-ci.org/steipete/Aspects.svg?branch=master)](https://travis-ci.org/steipete/Aspects)
==============

Delightful, simple library for aspect oriented programming (AOP) by [@steipete](http://twitter.com/steipete).

**Think of Aspects as method swizzling on steroids. It allows you to add code to existing methods per class or per instance**, whilst thinking of the insertion point e.g. before/instead/after. Aspects automatically deals with calling super and is easier to use than regular method swizzling.

Aspects extends `NSObject` with the following methods:

``` objc
/// Adds a block of code before/instead/after the current `selector` for a specific object.
/// If you choose `AspectPositionInstead`, `arguments` contains an additional argument which is the original invocation.
/// @return A token which allows to later deregister the aspect.
- (id)aspect_hookSelector:(SEL)selector
               atPosition:(AspectPosition)position
                withBlock:(void (^)(id object, NSArray *arguments))block;

/// Hooks a selector class-wide.
+ (id)aspect_hookSelector:(SEL)selector
               atPosition:(AspectPosition)position
                withBlock:(void (^)(id object, NSArray *arguments))block;

/// Unregister an aspect.
/// @return YES if deregistration is successful, otherwise NO.
+ (BOOL)aspect_remove:(id)aspect;
```

Adding aspects returns an opaque token which can be used to deregister again. All calls are thread-safe.

Aspects uses Objective-C message forwarding to hook into messages. This will create some overhead. Don't add aspects to methods that are called a lot. Aspects is meant for view/controller code that is not called 1000 times per second.

Aspects collects all arguments in the `arguments` array. Primitive values will be boxed.

When to use Aspects
-------------------

Aspects can be used to **dynamically add logging** for debug builds only:

``` objc
[UIViewController aspect_hookSelector:@selector(viewWillAppear:) atPosition:AspectPositionAfter withBlock:^(id object, NSArray *arguments) {
    NSLog(@"View Controller %@ will appear animated: %@", object, arguments.firstObject);
}];
```

-------------------
It can be used to greatly simplify your analytics setup:
https://github.com/orta/ARAnalytics/pull/74

-------------------
You can check if methods are really being called in your test cases:
``` objc
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
```

-------------------
Another convenient use case is adding handlers for classes that you don't own. I've written it for use in [PSPDFKit](http://pspdfkit.com), where we require notifications when a view controller is being dismissed modally. This includes UIKit view controllers like `MFMailComposeViewController` or `UIImagePickerController`. We could have created subclasses for each of these controllers, but this would be quite a lot of unnecessary code. Aspects gives you a simpler solution for this problem:

``` objc
@implementation UIViewController (DismissActionHook)

// Will add a dismiss action once the controller gets dismissed.
- (void)pspdf_addWillDismissAction:(void (^)(void))action {
    PSPDFAssert(action != NULL);

    __weak __typeof(self)weakSelf = self;
    [self aspect_hookSelector:@selector(viewWillDisappear:) atPosition:AspectPositionAfter withBlock:^(id object, NSArray *arguments) {
        if (weakSelf.isBeingDismissed) {
            action();
        }
    }];
}

@end
```

Debugging
---------
Aspects identifies itself nicely in the stack trace, so it's easy to see if a method has been hooked:

<img src="https://raw.githubusercontent.com/steipete/Aspects/master/stacktrace@2x.png?token=58493__eyJzY29wZSI6IlJhd0Jsb2I6c3RlaXBldGUvQXNwZWN0cy9tYXN0ZXIvc3RhY2t0cmFjZUAyeC5wbmciLCJleHBpcmVzIjoxMzk5NzQ3OTI3fQ%3D%3D--97cf7e7bac491149eb8db3d1b9a562ab88154a3c" width="75%">

Using Aspects with methods with a return type
---------------------------------------------

When you're using Aspects with `AspectPositionInstead`, the last argument of the `arguments` array will be the `NSInvocation` of the original implementation. You can use this invocation to customize the return value:

``` objc
    [PSPDFDrawView aspect_hookSelector:@selector(shouldProcessTouches:withEvent:) atPosition:AspectPositionInstead withBlock:^(id object, NSArray *arguments) {
        // Call original implementation.
        BOOL processTouches;
        NSInvocation *invocation = arguments.lastObject;
        [invocation invoke];
        [invocation getReturnValue:&processTouches];

        if (processTouches) {
            processTouches = pspdf_stylusShouldProcessTouches(arguments[0], arguments[1]);
            [invocation setReturnValue:&processTouches];
        }
    }];
```

Installation
------------
The simplest option is to use `pod "Aspects"`.

You can also add the two files NSObject+Aspects.h/m. There are no further requirements.

Compatibility
-------------
You can freely mix Aspects with regular method swizzling.

KVO works if observers are created after your calls aspect_hookSelector: It most likely will crash the other way around.
Still looking for workarounds here - any help apprechiated.

Because of ugly implementation details on the ObjC runtime, methods that return unions that also contain structs might not work correctly unless this code runs on the arm64 runtime.

Credits
-------
The idea to use `_objc_msgForward` and parts of the `NSInvocation` argument selection is from the excellent [ReactiveCocoa](https://github.com/ReactiveCocoa/ReactiveCocoa) from the GitHub guys.


Supported iOS & SDK Versions
-----------------------------

* Aspects requires ARC.
* Aspects is tested with iOS 6+.

License
-------
MIT licensed, Copyright (c) 2014 Peter Steinberger, steipete@gmail.com, [@steipete](http://twitter.com/steipete)


Release Notes
-----------------

Version 1.0.1

- Minor tweaks and documentation improvements.

Version 1.0.0

- Initial release
