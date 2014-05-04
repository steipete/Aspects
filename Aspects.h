//
//  Aspects.h
//  Aspects - A delightful, simple library for aspect oriented programming
//
//  Copyright (c) 2014 Peter Steinberger. Licensed under the MIT license.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, AspectPosition) {
    AspectPositionBefore,  /// Called before the original implementation.
    AspectPositionInstead, /// Will replace the original implementation.
    AspectPositionAfter    /// Called after the original implementation.
};

/// Opaque Aspect Token that allows to deregister the hook.
@protocol Aspect <NSObject>

/// Deregisters an aspect.
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
/// If you choose `AspectPositionInstead`, the `arguments` array will contain the original invocation as last argument.
/// @return A token which allows to later deregister the aspect.
- (id<Aspect>)aspect_hookSelector:(SEL)selector
                       atPosition:(AspectPosition)position
                        withBlock:(void (^)(__unsafe_unretained id object, NSArray *arguments))block
                            error:(NSError **)error;

/// Hooks a selector class-wide.
+ (id<Aspect>)aspect_hookSelector:(SEL)selector
                       atPosition:(AspectPosition)position
                        withBlock:(void (^)(__unsafe_unretained id object, NSArray *arguments))block
                            error:(NSError **)error;

@end


typedef NS_ENUM(NSUInteger, AspectsErrorCode) {
    AspectsErrorSelectorBlacklisted,                   /// Selectors like release, retain, autorelease are blacklisted.
    AspectsErrorSelectorDeallocPosition,               /// When hooking dealloc, AspectPositionInstead is not allowed.
    AspectsErrorSelectorAlreadyHookedInClassHierarchy, /// Statically hooking the same method in subclasses is not allowed.
    AspectsErrorFailedToAllocateClassPair,             /// The runtime failed creating a class pair.
    AspectsErrorRemoveObjectAlreadyDeallocated = 100   /// (for removing) The object hooked is already deallocated.
};
extern NSString *const AspectsErrorDomain;
