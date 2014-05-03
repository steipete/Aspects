//
//  NSObject+Aspects.m
//  Aspects
//
//  Copyright (c) 2014 Peter Steinberger. Licensed under the MIT license.
//

#import "NSObject+Aspects.h"
#import <libkern/OSAtomic.h>
#import <objc/runtime.h>
#import <objc/message.h>

#define AspectLog(...) do { NSLog(__VA_ARGS__); }while(0)

@interface AspectIdentifier : NSObject
- (id)initWithSelector:(SEL)selector object:(id)object block:(id)block;
@property (nonatomic, assign) SEL selector;
@property (nonatomic, strong) id block;
@property (nonatomic, weak) id object;
@end

@interface AspectContainer : NSObject
- (void)addAspect:(AspectIdentifier *)aspect atPosition:(AspectPosition)injectPosition;
- (BOOL)removeAspect:(id)aspect;
- (BOOL)hasAspects;
@property (atomic, copy) NSArray *beforeAspects;
@property (atomic, copy) NSArray *insteadAspects;
@property (atomic, copy) NSArray *afterAspects;
@end

@interface NSInvocation (Aspects)
- (NSArray *)aspects_arguments;
@end

static NSString *const AspectSubclassSuffix = @"_Aspects_";
static NSString *const AspectMessagePrefix = @"aspects_";

@implementation NSObject (Aspects)

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Public Aspects API

+ (id)aspect_hookSelector:(SEL)selector atPosition:(AspectPosition)position withBlock:(void (^)(id object, NSArray *arguments))block {
    return aspect_add(self, selector, position, block);
}

- (id)aspect_hookSelector:(SEL)selector atPosition:(AspectPosition)position withBlock:(void (^)(id object, NSArray *arguments))block {
    return aspect_add(self, selector, position, block);
}

+ (BOOL)aspect_remove:(id)aspect {
    return aspect_remove(aspect);
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Private Helper

static id aspect_add(id self, SEL selector, AspectPosition position, void (^block)(id object, NSArray *arguments)) {
    NSCParameterAssert(block);
    NSCParameterAssert(selector);

    AspectIdentifier *identifier = [[AspectIdentifier alloc] initWithSelector:selector object:self block:block];
    aspect_performLocked(^{
        AspectContainer *aspectContainer = aspect_getContainerForObject(self, selector);
        [aspectContainer addAspect:identifier atPosition:position];

        // Ensure the class is prepared.
        aspect_prepareClassAndHookSelector(self, selector);
    });
    return identifier;
}

static BOOL aspect_remove(AspectIdentifier *aspect) {
    if (![aspect isKindOfClass:AspectIdentifier.class]) {
        AspectLog(@"Aspect: Invalid object given to aspect_remove: %@", aspect);
        return NO;
    }

    __block BOOL success = NO;
    aspect_performLocked(^{
        id object = aspect.object; // strongify
        if (object) {
            AspectContainer *aspectContainer = aspect_getContainerForObject(object, aspect.selector);
            success = [aspectContainer removeAspect:aspect];
        }
    });
    return success;
}

static void aspect_performLocked(dispatch_block_t block) {
    static OSSpinLock aspect_lock = OS_SPINLOCK_INIT;
    OSSpinLockLock(&aspect_lock);
    block();
    OSSpinLockUnlock(&aspect_lock);
}

static SEL aspect_aliasForSelector(SEL selector) {
    NSCParameterAssert(selector);
	return NSSelectorFromString([AspectMessagePrefix stringByAppendingString:NSStringFromSelector(selector)]);
}

// Loads or creates the aspect container.
static AspectContainer *aspect_getContainerForObject(id object, SEL selector) {
    NSCParameterAssert(object);
    NSCParameterAssert(selector);

    SEL aliasSelector = aspect_aliasForSelector(selector);
    AspectContainer *aspectContainer = objc_getAssociatedObject(object, aliasSelector);
    if (!aspectContainer) {
        aspectContainer = [AspectContainer new];
        objc_setAssociatedObject(object, aliasSelector, aspectContainer, OBJC_ASSOCIATION_RETAIN);
    }
    return aspectContainer;
}

static void aspect_prepareClassAndHookSelector(id object, SEL selector) {
    NSCParameterAssert(object);
    NSCParameterAssert(selector);

    Class class = aspect_hookClass(object);
    Method targetMethod = class_getInstanceMethod(class, selector);
    IMP targetMethodIMP = method_getImplementation(targetMethod);
    if (targetMethodIMP != _objc_msgForward && targetMethodIMP != (IMP)_objc_msgForward_stret) {

        // Make a method alias for the existing method implementation.
        const char *typeEncoding = method_getTypeEncoding(targetMethod);
        SEL aliasSelector = aspect_aliasForSelector(selector);
        __unused BOOL addedAlias = class_addMethod(class, aliasSelector, method_getImplementation(targetMethod), typeEncoding);
        NSCAssert(addedAlias, @"Original implementation for %@ is already copied to %@ on %@", NSStringFromSelector(selector), NSStringFromSelector(aliasSelector), class);

        // We use forwardInvocation to hook in.
        BOOL isStruct = (*typeEncoding == '{') ? YES : NO;
        class_replaceMethod(class, selector, isStruct ? (IMP)_objc_msgForward_stret : _objc_msgForward, typeEncoding);

        AspectLog(@"Aspects: Installed hook for -[%@ %@].", class, NSStringFromSelector(selector));
    }
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Hook Class

static Class aspect_hookClass(NSObject *self) {
    NSCParameterAssert(self);

	Class statedClass = self.class;
	Class baseClass = object_getClass(self);
	NSString *className = NSStringFromClass(baseClass);

    // Already subclassed
	if ([className hasSuffix:AspectSubclassSuffix]) {
		return baseClass;

        // We swizzle a class object, not a single object.
	}else if (class_isMetaClass(baseClass)) {
        return aspect_hookClassInPlace((Class)self);
        // Probably a KVO'ed class. Swizzle in place. Also swizzle meta classes in place.
    }else if (statedClass != baseClass) {
        return aspect_hookClassInPlace(baseClass);
    }

    // Default case. Create dynamic subclass.
	const char *subclassName = [className stringByAppendingString:AspectSubclassSuffix].UTF8String;
	Class subclass = objc_getClass(subclassName);

	if (subclass == nil) {
		subclass = objc_allocateClassPair(baseClass, subclassName, 0);
		if (subclass == nil) {
            AspectLog(@"Aspects: objc_allocateClassPair failed to allocate class %s.", subclassName);
            return nil;
        }

		aspect_hookedForwardInvocation(subclass);
		aspect_hookedGetClass(subclass, statedClass);
		aspect_hookedGetClass(object_getClass(subclass), statedClass);
		objc_registerClassPair(subclass);
	}

	object_setClass(self, subclass);
	return subclass;
}

static Class aspect_hookClassInPlace(Class class) {
    NSCParameterAssert(class);

    static NSMutableSet *swizzledClasses;
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{
        swizzledClasses = [NSMutableSet new];
    });

    NSString *className = NSStringFromClass(class);
    @synchronized (swizzledClasses) {
        if (![swizzledClasses containsObject:className]) {
            aspect_hookedForwardInvocation(class);
            [swizzledClasses addObject:className];
        }
    }
    return class;
}

static void aspect_hookedForwardInvocation(Class class) {
    NSCParameterAssert(class);

    class_replaceMethod(class, @selector(forwardInvocation:), (IMP)__ASPECTS_ARE_BEING_CALLED__, "v@:@");
    AspectLog(@"Aspects: %@ is now aspect aware.", class);
}

static void aspect_hookedGetClass(Class class, Class statedClass) {
    NSCParameterAssert(class);
    NSCParameterAssert(statedClass);

	Method method = class_getInstanceMethod(class, @selector(class));
	IMP newIMP = imp_implementationWithBlock(^(id self) {
		return statedClass;
	});
	class_replaceMethod(class, @selector(class), newIMP, method_getTypeEncoding(method));
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Aspect Invoke Point

// This is a macro so we get a cleaner stack trace.
#define aspect_invoke(aspects, arguments) for (AspectIdentifier *aspect in aspects) {((void (^)(id, NSArray *))aspect.block)(self, arguments); }

// This is the swizzled forwardInvocation: method.
static void __ASPECTS_ARE_BEING_CALLED__(id<NSObject> self, SEL selector, NSInvocation *invocation) {
    NSCParameterAssert(self);
    NSCParameterAssert(selector);
    NSCParameterAssert(invocation);

	SEL aliasSelector = aspect_aliasForSelector(invocation.selector);
    AspectContainer *objectContainer = objc_getAssociatedObject(self, aliasSelector);
    AspectContainer *classContainer  = objc_getAssociatedObject(self.class, aliasSelector);

    // Before hooks.
    NSArray *arguments = nil;
    if (objectContainer.hasAspects || classContainer.hasAspects) {
        // Only collect the arguments if there are hooks to call.
        arguments = invocation.aspects_arguments;
        aspect_invoke(classContainer.beforeAspects, arguments);
        aspect_invoke(objectContainer.beforeAspects, arguments);
    }

    // Instead hooks.
    BOOL respondsToAlias = YES;
    if (objectContainer.insteadAspects.count || classContainer.insteadAspects.count) {
        invocation.selector = aliasSelector;
        NSArray *argumentsWithInvocation = [arguments arrayByAddingObject:invocation];
        aspect_invoke(classContainer.insteadAspects, argumentsWithInvocation);
        aspect_invoke(objectContainer.insteadAspects, argumentsWithInvocation);
    }else {
        Class class = object_getClass(invocation.target);
        if ((respondsToAlias = [class instancesRespondToSelector:aliasSelector])) {
            invocation.selector = aliasSelector;
            [invocation invoke];
        }
    }

    // After hooks.
    aspect_invoke(classContainer.afterAspects, arguments);
    aspect_invoke(objectContainer.afterAspects, arguments);

    // If no hooks are installed, call original implementation (usually to throw an exception)
    if (!respondsToAlias) {
        SEL forwardInvocationSEL = @selector(forwardInvocation:);
        Method forwardInvocationMethod = class_getInstanceMethod(self.class, forwardInvocationSEL);

        // Preserve any existing implementation of -forwardInvocation:.
        void (*originalForwardInvocation)(id, SEL, NSInvocation *) = NULL;
        if (forwardInvocationMethod != NULL) {
            originalForwardInvocation = (__typeof__(originalForwardInvocation))method_getImplementation(forwardInvocationMethod);
        }

        if (originalForwardInvocation == NULL) {
            [(id)self doesNotRecognizeSelector:invocation.selector];
        } else {
            originalForwardInvocation(self, forwardInvocationSEL, invocation);
        }
    }
}
#undef aspect_invoke

@end

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSInvocation (Aspects)

@implementation NSInvocation (Aspects)

// Thanks to the ReactiveCocoa team for providing a generic solution for this.
- (id)aspect_argumentAtIndex:(NSUInteger)index {
	const char *argType = [self.methodSignature getArgumentTypeAtIndex:index];
	// Skip const type qualifier.
	if (argType[0] == _C_CONST) argType++;

#define WRAP_AND_RETURN(type) do { type val = 0; [self getArgument:&val atIndex:(NSInteger)index]; return @(val); } while (0)
	if (strcmp(argType, @encode(id)) == 0 || strcmp(argType, @encode(Class)) == 0) {
		__autoreleasing id returnObj;
		[self getArgument:&returnObj atIndex:(NSInteger)index];
		return returnObj;
	} else if (strcmp(argType, @encode(SEL)) == 0) {
        SEL selector = 0;
        [self getArgument:&selector atIndex:(NSInteger)index];
        return NSStringFromSelector(selector);
    } else if (strcmp(argType, @encode(Class)) == 0) {
        __autoreleasing Class theClass = Nil;
        [self getArgument:&theClass atIndex:(NSInteger)index];
        return theClass;
	} else if (strcmp(argType, @encode(char)) == 0) {
		WRAP_AND_RETURN(char);
	} else if (strcmp(argType, @encode(unichar)) == 0) {
		WRAP_AND_RETURN(unichar);
	} else if (strcmp(argType, @encode(int)) == 0) {
		WRAP_AND_RETURN(int);
	} else if (strcmp(argType, @encode(short)) == 0) {
		WRAP_AND_RETURN(short);
	} else if (strcmp(argType, @encode(long)) == 0) {
		WRAP_AND_RETURN(long);
	} else if (strcmp(argType, @encode(long long)) == 0) {
		WRAP_AND_RETURN(long long);
	} else if (strcmp(argType, @encode(unsigned char)) == 0) {
		WRAP_AND_RETURN(unsigned char);
	} else if (strcmp(argType, @encode(unsigned int)) == 0) {
		WRAP_AND_RETURN(unsigned int);
	} else if (strcmp(argType, @encode(unsigned short)) == 0) {
		WRAP_AND_RETURN(unsigned short);
	} else if (strcmp(argType, @encode(unsigned long)) == 0) {
		WRAP_AND_RETURN(unsigned long);
	} else if (strcmp(argType, @encode(unsigned long long)) == 0) {
		WRAP_AND_RETURN(unsigned long long);
	} else if (strcmp(argType, @encode(float)) == 0) {
		WRAP_AND_RETURN(float);
	} else if (strcmp(argType, @encode(double)) == 0) {
		WRAP_AND_RETURN(double);
	} else if (strcmp(argType, @encode(BOOL)) == 0) {
		WRAP_AND_RETURN(BOOL);
	} else if (strcmp(argType, @encode(bool)) == 0) {
		WRAP_AND_RETURN(BOOL);
	} else if (strcmp(argType, @encode(_Bool)) == 0) {
		WRAP_AND_RETURN(_Bool);
	} else if (strcmp(argType, @encode(char *)) == 0) {
		WRAP_AND_RETURN(const char *);
	} else if (strcmp(argType, @encode(void (^)(void))) == 0) {
		__unsafe_unretained id block = nil;
		[self getArgument:&block atIndex:(NSInteger)index];
		return [block copy];
	} else {
		NSUInteger valueSize = 0;
		NSGetSizeAndAlignment(argType, &valueSize, NULL);

		unsigned char valueBytes[valueSize];
		[self getArgument:valueBytes atIndex:(NSInteger)index];

		return [NSValue valueWithBytes:valueBytes objCType:argType];
	}
	return nil;
#undef WRAP_AND_RETURN
}

- (NSArray *)aspects_arguments {
	NSMutableArray *argumentsArray = [NSMutableArray array];
	for (NSUInteger idx = 2; idx < self.methodSignature.numberOfArguments; idx++) {
		[argumentsArray addObject:[self aspect_argumentAtIndex:idx] ?: NSNull.null];
	}
	return [argumentsArray copy];
}

@end

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - AspectIdentifier

@implementation AspectIdentifier

- (id)initWithSelector:(SEL)selector object:(id)object block:(id)block; {
    if (self = [super init]) {
        _selector = selector;
        _object = object;
        _block = block;
    }
    return self;
}

@end

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - AspectContainer

@implementation AspectContainer

- (BOOL)hasAspects {
    return self.beforeAspects.count > 0 || self.insteadAspects.count > 0 || self.afterAspects.count > 0;
}

- (void)addAspect:(AspectIdentifier *)aspect atPosition:(AspectPosition)injectPosition {
    switch (injectPosition) {
        case AspectPositionBefore:  self.beforeAspects  = [(self.beforeAspects ?:@[]) arrayByAddingObject:aspect]; break;
        case AspectPositionInstead: self.insteadAspects = [(self.insteadAspects?:@[]) arrayByAddingObject:aspect]; break;
        case AspectPositionAfter:   self.afterAspects   = [(self.afterAspects  ?:@[]) arrayByAddingObject:aspect]; break;
    }
}

- (BOOL)removeAspect:(id)aspect {
    for (NSString *aspectArrayName in @[NSStringFromSelector(@selector(beforeAspects)),
                                        NSStringFromSelector(@selector(insteadAspects)),
                                        NSStringFromSelector(@selector(afterAspects))]) {
        NSArray *array = [self valueForKey:aspectArrayName];
        NSUInteger index = [array indexOfObjectIdenticalTo:aspect];
        if (array && index != NSNotFound) {
            NSMutableArray *newArray = [NSMutableArray arrayWithArray:array];
            [newArray removeObjectAtIndex:index];
            [self setValue:newArray forKey:aspectArrayName];
            return YES;
        }
    }
    return NO;
}

@end
