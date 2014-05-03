//
//  NSObject+Aspects.h
//  PSPDFKit
//
//  Copyright (c) 2013-2014 PSPDFKit GmbH. All rights reserved.
//
//  THIS SOURCE CODE AND ANY ACCOMPANYING DOCUMENTATION ARE PROTECTED BY INTERNATIONAL COPYRIGHT LAW
//  AND MAY NOT BE RESOLD OR REDISTRIBUTED. USAGE IS BOUND TO THE PSPDFKIT LICENSE AGREEMENT.
//  UNAUTHORIZED REPRODUCTION OR DISTRIBUTION IS SUBJECT TO CIVIL AND CRIMINAL PENALTIES.
//  This notice may not be removed from this file.
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
