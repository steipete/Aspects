Aspects
=======

Delightful, simple library for aspect oriented programming.

Think of Aspects as method swizzling on steroids. It allows you to hook onto selectors either per object or per class, and you can choose the insertion point (before/instead/after).

Aspects extends NSObject with the following methods:

    - (id)aspect_hookSelector:(SEL)selector
                   atPosition:(AspectPosition)injectPosition
                    withBlock:(void (^)(id object, NSArray *arguments))block;

    + (id)aspect_hookSelector:(SEL)selector
                   atPosition:(AspectPosition)injectPosition
                     withBlock:(void (^)(id object, NSArray *arguments))block;

    + (BOOL)aspect_remove:(id)aspect;


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