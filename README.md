Aspects
=======

Delightful, simple library for aspect oriented programming.

**Think of Aspects as method swizzling on steroids.** It allows you to hook onto selectors either per object or per class, and you can choose the insertion point (AspectPosition: before/instead/after). Aspects automatically deals with calling super and is easier to use than regular method swizzling.

Aspects extends NSObject with the following methods:

    - (id)aspect_hookSelector:(SEL)selector
                   atPosition:(AspectPosition)injectPosition
                    withBlock:(void (^)(id object, NSArray *arguments))block;

    + (id)aspect_hookSelector:(SEL)selector
                   atPosition:(AspectPosition)injectPosition
                     withBlock:(void (^)(id object, NSArray *arguments))block;

    + (BOOL)aspect_remove:(id)aspect;

Adding aspects returns an opaque token which can be used to deregister again. All calls are thread safe.

Aspects uses Objective-C message forwarding to hook into messages. This will create some overhead. Don't add aspects to methods that are called a lot. This means it's not a good fit for your model, but works well for view or controller code.

Aspects collects all arguments in the `arguments` array. Primitive values will be boxed.

Using Aspects with methods with a return type
---------------------------------------------

When you're using Aspects with `AspectPositionInstead`, the last argument of the `arguments` array will be the `NSInvocation` of the original implementation. You can use this invocation to customize the return value:

```objectivec
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


Release Notes
-----------------

Version 1.0.0

- Initial release


Supported iOS & SDK Versions
-----------------------------

* Aspects requires ARC.
* Aspects is tested with iOS 6+.

License
-------
MIT licensed.