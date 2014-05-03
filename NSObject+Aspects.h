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

@interface NSObject (Aspects)

/// Adds a block of code before/instead or after the current selector.
/// If you choose `AspectPositionInstead`, `arguments` contains an additional argument which is the original invocation.
/// @return A token which allows to later deregister the aspect.
- (id)aspect_hookSelector:(SEL)selector atPosition:(AspectPosition)injectPosition withBlock:(void (^)(id object, NSArray *arguments))block;

/// Hook a selector class-wide.
+ (id)aspect_hookSelector:(SEL)selector atPosition:(AspectPosition)injectPosition withBlock:(void (^)(id object, NSArray *arguments))block;

/// Unregister aspect.
/// @return YES if deregistration is successful, otherwise NO.
+ (BOOL)aspect_remove:(id)aspect;

@end
