//
//  Aspects.h
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

/// Opaque Aspect Token that allows to deregister the hook.
@protocol Aspect <NSObject>

/// Deegister an aspect.
/// @return YES if deregistration is successful, otherwise NO.
- (BOOL)remove;

@end

/**
 Aspects uses Objective-C message forwarding to hook into messages. This will create some overhead. Don't add aspects to methods that are called a lot. Aspects is meant for view/controller code that is not called a 1000 times per second.

 Aspects collects all arguments in the `arguments` array. Primitive values will be boxed.
 Adding aspects returns an opaque token which can be used to deregister again. All calls are thread safe.
 */
@interface NSObject (Aspects)

/// Adds a block of code before/instead/after the current `selector` for a specific object.
/// If you choose `AspectPositionInstead`, `arguments` contains an additional argument which is the original invocation.
/// @return A token which allows to later deregister the aspect.
- (id<Aspect>)aspect_hookSelector:(SEL)selector atPosition:(AspectPosition)position withBlock:(void (^)(__unsafe_unretained id object, NSArray *arguments))block;

/// Hooks a selector class-wide.
+ (id<Aspect>)aspect_hookSelector:(SEL)selector atPosition:(AspectPosition)position withBlock:(void (^)(__unsafe_unretained id object, NSArray *arguments))block;

@end
