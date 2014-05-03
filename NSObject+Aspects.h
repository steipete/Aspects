//
//  NSObject+Aspects.h
//  Aspects
//
//  Copyright (c) 2014 Peter Steinberger. Licensed under the MIT license.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, AspectPosition) {
    AspectPositionBefore,
    AspectPositionInstead,
    AspectPositionAfter
};

/**
 Aspects uses Objective-C message forwarding to hook into messages. This will create some overhead. Don't add aspects to methods that are called a lot. Aspects is meant for view/controller code that is not called a 1000 times per second.

 Aspects collects all arguments in the `arguments` array. Primitive values will be boxed.
 Adding aspects returns an opaque token which can be used to deregister again. All calls are thread safe.
 */
@interface NSObject (Aspects)

/// Adds a block of code before/instead or after the current selector.
/// If you choose `AspectPositionInstead`, `arguments` contains an additional argument which is the original invocation.
/// @return A token which allows to later deregister the aspect.
- (id)aspect_hookSelector:(SEL)selector atPosition:(AspectPosition)position withBlock:(void (^)(id object, NSArray *arguments))block;

/// Hook a selector class-wide.
+ (id)aspect_hookSelector:(SEL)selector atPosition:(AspectPosition)position withBlock:(void (^)(id object, NSArray *arguments))block;

/// Unregister aspect.
/// @return YES if deregistration is successful, otherwise NO.
+ (BOOL)aspect_remove:(id)aspect;

@end
