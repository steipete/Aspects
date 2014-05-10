Aspects v1.4.1 [![Build Status](https://travis-ci.org/steipete/Aspects.svg?branch=master)](https://travis-ci.org/steipete/Aspects)
==============

Delightful, simple library for aspect oriented programming by [@steipete](http://twitter.com/steipete).

**Think of Aspects as method swizzling on steroids. It allows you to add code to existing methods per class or per instance**, whilst thinking of the insertion point e.g. before/instead/after. Aspects automatically deals with calling super and is easier to use than regular method swizzling.

This is stable and used in hundreds of apps since it's part of [PSPDFKit, an iOS PDF framework that ships with apps like Dropbox or Evernote](http://pspdfkit.com), and now I finally made it open source.

Aspects extends `NSObject` with the following methods:

``` objc
/// Adds a block of code before/instead/after the current `selector` for a specific class.
///
/// @param block Aspects replicates the type signature of the method being hooked.
/// The first parameter will be `id<AspectInfo>`, followed by all parameters of the method.
/// These parameters are optional and will be filled to match the block signature.
/// You can even use an empty block, or one that simple gets `id<AspectInfo>`.
///
/// @note Hooking static methods is not supported.
/// @return A token which allows to later deregister the aspect.
+ (id<AspectToken>)aspect_hookSelector:(SEL)selector
                      withOptions:(AspectOptions)options
                       usingBlock:(id)block
                            error:(NSError **)error;

/// Adds a block of code before/instead/after the current `selector` for a specific instance.
- (id<AspectToken>)aspect_hookSelector:(SEL)selector
                      withOptions:(AspectOptions)options
                       usingBlock:(id)block
                            error:(NSError **)error;

/// Deregister an aspect.
/// @return YES if deregistration is successful, otherwise NO.
id<AspectToken> aspect = ...;
[aspect remove];
```

Adding aspects returns an opaque token of type `AspectToken` which can be used to deregister again. All calls are thread-safe.

Aspects uses Objective-C message forwarding to hook into messages. This will create some overhead. Don't add aspects to methods that are called a lot. Aspects is meant for view/controller code that is not called 1000 times per second.

Aspects calls and matches block arguments. Blocks without arguments are supported as well. The first block argument will be of type `id<AspectInfo>`.

When to use Aspects
-------------------
Aspect-oritented programming (AOP) is used to encapsulate "cross-cutting" concerns. These are the kind of requirements that *cut-accross* many modules in your system, and so cannot be encapsulated using normal Object Oriented programming. Some examples of these kinds of requirements: 

* *Whenever* a user invokes a method on the service client, security should be checked. 
* *Whenever* a useer interacts with the store, a genius suggestion should be presented, based on their interaction. 
* *All* calls should be logged. 

If we implemented the above requirements using regular OO there'd be some drawbacks: 


Good OO says a class should have a single responsibility, however adding on extra *cross-cutting* requirements means a class that is taking on other responsibilites. For example you might have a **StoreClient** that supposed to be all about making purchases from an online store. Add in some cross-cutting requirements and it might also have to take on the roles of logging, security and recommendations. This is not great: 

* Our StoreClient is now harder to understand and maintain.
* These cross-cutting requirements are duplicated and spreading throughout our app. 

AOP lets us modularize these cross-cutting requirements, and then cleanly identify all of the places they should be applied. As shown in the examples above cross-cutting requirements can be eithe technical or business focused in nature.  

## Here are some concrete examples: 


Aspects can be used to **dynamically add logging** for debug builds only:

``` objc
[UIViewController aspect_hookSelector:@selector(viewWillAppear:) withOptions:AspectPositionAfter usingBlock:^(id<AspectInfo> aspectInfo, BOOL animated) {
    NSLog(@"View Controller %@ will appear animated: %tu", aspectInfo.instance, animated);
} error:NULL];
```

-------------------
It can be used to greatly simplify your analytics setup:
https://github.com/orta/ARAnalytics

-------------------
You can check if methods are really being called in your test cases:
``` objc
- (void)testExample {
    TestClass *testClass = [TestClass new];
    TestClass *testClass2 = [TestClass new];

    __block BOOL testCallCalled = NO;
    [testClass aspect_hookSelector:@selector(testCall) withOptions:AspectPositionAfter usingBlock:^{
        testCallCalled = YES;
    } error:NULL];

    [testClass2 testCallAndExecuteBlock:^{
        [testClass testCall];
    } error:NULL];
    XCTAssertTrue(testCallCalled, @"Calling testCallAndExecuteBlock must call testCall");
}
```
-------------------
It can be really useful for debugging. Here I was curious when exactly the tap gesture changed state:

``` objc
[_singleTapGesture aspect_hookSelector:@selector(setState:) withOptions:AspectPositionAfter usingBlock:^(id<AspectInfo> aspectInfo) {
    NSLog(@"%@: %@", aspectInfo.instance, aspectInfo.arguments);
} error:NULL];
```

-------------------
Another convenient use case is adding handlers for classes that you don't own. I've written it for use in [PSPDFKit](http://pspdfkit.com), where we require notifications when a view controller is being dismissed modally. This includes UIKit view controllers like `MFMailComposeViewController` or `UIImagePickerController`. We could have created subclasses for each of these controllers, but this would be quite a lot of unnecessary code. Aspects gives you a simpler solution for this problem:

``` objc
@implementation UIViewController (DismissActionHook)

// Will add a dismiss action once the controller gets dismissed.
- (void)pspdf_addWillDismissAction:(void (^)(void))action {
    PSPDFAssert(action != NULL);

    [self aspect_hookSelector:@selector(viewWillDisappear:) withOptions:AspectPositionAfter usingBlock:^(id<AspectInfo> aspectInfo) {
        if ([aspectInfo.instance isBeingDismissed]) {
            action();
        }
    } error:NULL];
}

@end
```

Debugging
---------
Aspects identifies itself nicely in the stack trace, so it's easy to see if a method has been hooked:

<img src="https://raw.githubusercontent.com/steipete/Aspects/master/stacktrace@2x.png?token=58493__eyJzY29wZSI6IlJhd0Jsb2I6c3RlaXBldGUvQXNwZWN0cy9tYXN0ZXIvc3RhY2t0cmFjZUAyeC5wbmciLCJleHBpcmVzIjoxMzk5NzQ3OTI3fQ%3D%3D--97cf7e7bac491149eb8db3d1b9a562ab88154a3c" width="75%">

Using Aspects with non-void return types
----------------------------------------

You can use the invocation object to customize the return value:

``` objc
    [PSPDFDrawView aspect_hookSelector:@selector(shouldProcessTouches:withEvent:) withOptions:AspectPositionInstead usingBlock:^(id<AspectInfo> info, NSSet *touches, UIEvent *event) {
        // Call original implementation.
        BOOL processTouches;
        NSInvocation *invocation = info.originalInvocation;
        [invocation invoke];
        [invocation getReturnValue:&processTouches];

        if (processTouches) {
            processTouches = pspdf_stylusShouldProcessTouches(touches, event);
            [invocation setReturnValue:&processTouches];
        }
    } error:NULL];
```

Installation
------------
The simplest option is to use `pod "Aspects"`.

You can also add the two files `Aspects.h/m`. There are no further requirements.

Compatibility and Limitations
-----------------------------
Aspects uses quite some runtime trickery to achieve what it does. You can mostly mix this with regular method swizzling.

An important limitation is that for class-based hooking, a method can only be hooked once within the subclass hierarchy. [See #2](https://github.com/steipete/Aspects/issues/2)
This does not apply for objects that are hooked. Aspects creates a dynamic subclass here and has full control.

KVO works if observers are created after your calls `aspect_hookSelector:` It most likely will crash the other way around.
Still looking for workarounds here - any help apprechiated.

Because of ugly implementation details on the ObjC runtime, methods that return unions that also contain structs might not work correctly unless this code runs on the arm64 runtime.

Credits
-------
The idea to use `_objc_msgForward` and parts of the `NSInvocation` argument selection is from the excellent [ReactiveCocoa](https://github.com/ReactiveCocoa/ReactiveCocoa) from the GitHub guys. [This article](http://codeshaker.blogspot.co.at/2012/01/aop-delivered.html) explains how it works under the hood.


Supported iOS & SDK Versions
-----------------------------

* Aspects requires ARC.
* Aspects is tested with iOS 6+ and OS X 10.7 or higher.

License
-------
MIT licensed, Copyright (c) 2014 Peter Steinberger, steipete@gmail.com, [@steipete](http://twitter.com/steipete)


Release Notes
-----------------

Version 1.4.1

- Rename error codes.

Version 1.4.0

- Add support for block signatures that match method signatures. (thanks to @nickynick)

Version 1.3.1

- Add support for OS X 10.7 or higher. (thanks to @ashfurrow)

Version 1.3.0

- Add automatic deregistration.
- Checks if the selector exists before trying to hook.
- Improved dealloc hooking. (no more unsafe_unretained needed)
- Better examples.
- Always log errors.

Version 1.2.0

- Adds error parameter.
- Improvements in subclassing registration tracking.

Version 1.1.0

- Renamed the files from NSObject+Aspects.m/h to just Aspects.m/h.
- Removing now works via calling `remove` on the aspect token.
- Allow hooking dealloc.
- Fixes infinite loop if the same method is hooked for multiple classes. Hooking will only work for one class in the hierarchy.
- Additional checks to prevent things like hooking retain/release/autorelease or forwardInvocation:
- The original implementation of forwardInvocation is now correctly preserved.
- Classes are properly cleaned up and restored to the original state after the last hook is deregistered.
- Lots and lots of new test cases!

Version 1.0.1

- Minor tweaks and documentation improvements.

Version 1.0.0

- Initial release
