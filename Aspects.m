//
//  Aspects.m
//  Aspects - A delightful, simple library for aspect oriented programming.
//
//  Copyright (c) 2014 Peter Steinberger. Licensed under the MIT license.
//

#import "Aspects.h"
#import <libkern/OSAtomic.h>
#import <objc/runtime.h>
#import <objc/message.h>

#define AspectLog(...)
//#define AspectLog(...) do { NSLog(__VA_ARGS__); }while(0)
#define AspectLogError(...) do { NSLog(__VA_ARGS__); }while(0)

// Tracks a single aspect.
@interface AspectIdentifier : NSObject <Aspect>
- (id)initWithSelector:(SEL)selector object:(id)object options:(AspectOptions)options block:(id)block;
@property (nonatomic, assign) SEL selector;
@property (nonatomic, strong) id block;
@property (nonatomic, weak) id object;
@property (nonatomic, assign) AspectOptions options;
@end

// Tracks all aspects for an object.
@interface AspectsContainer : NSObject
- (void)addAspect:(AspectIdentifier *)aspect withOptions:(AspectOptions)injectPosition;
- (BOOL)removeAspect:(id)aspect;
- (BOOL)hasAspects;
@property (atomic, copy) NSArray *beforeAspects;
@property (atomic, copy) NSArray *insteadAspects;
@property (atomic, copy) NSArray *afterAspects;
@end

@interface AspectTracker : NSObject
- (id)initWithTrackedClass:(Class)trackedClass parent:(AspectTracker *)parent;
@property (nonatomic, strong) Class trackedClass;
@property (nonatomic, strong) NSMutableSet *selectorNames;
@property (nonatomic, weak) AspectTracker *parentEntry;
@end

// Tracks aspects for a given class, as well as instances of the aspects
@interface AspectClassContainer : NSObject

@property (nonatomic, strong) NSArray *aspectContainers;
@property (nonatomic, strong) NSArray *instances; // "live" aspects on class instances

- (void)removeAspectContainer:(AspectsContainer *)container;

@end

@interface NSInvocation (Aspects)
- (NSArray *)aspects_arguments;
@end

typedef void(^AspectBlock)(id instance, NSArray *arguments);

#define AspectPositionFilter 0x07

#define AspectError(errorCode, errorDescription) do { \
AspectLogError(@"Aspects: %@", errorDescription); \
if (error) { *error = [NSError errorWithDomain:AspectsErrorDomain code:errorCode userInfo:@{NSLocalizedDescriptionKey: errorDescription}]; }}while(0)

NSString *const AspectsErrorDomain = @"AspectsErrorDomain";
static NSString *const AspectsSubclassSuffix = @"_Aspects_";
static NSString *const AspectsMessagePrefix = @"aspects_";

@implementation NSObject (Aspects)

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Public Aspects API

+ (id<Aspect>)aspect_hookSelector:(SEL)selector
                      withOptions:(AspectOptions)options
                       usingBlock:(AspectBlock)block
                            error:(NSError **)error {
    
    static void *AllocKey = &AllocKey;
    id token = objc_getAssociatedObject(self, AllocKey);
    
    if (!token) {
        objc_setAssociatedObject(self, AllocKey, [NSObject new], OBJC_ASSOCIATION_RETAIN);
        aspects_swizzleAlloc(self);
    }
    
    __block AspectIdentifier *identifier = nil;
    aspect_performLocked(^{
        if (aspect_isSelectorAllowedAndTrack((id)self, selector, options, error)) {
            AspectsContainer *aspectContainer = aspect_getContainerForObject((id)self, selector);
            identifier = [[AspectIdentifier alloc] initWithSelector:selector object:self options:options block:block];
            [aspectContainer addAspect:identifier withOptions:options];
            
            AspectClassContainer *classContainer = aspect_getClassContainerForClass(self);
            classContainer.aspectContainers = [(classContainer.aspectContainers ?:@[]) arrayByAddingObject:aspectContainer];
        }
    });
    
    // When the class-level aspect is removed, removed all "live" aspects attached to instances of that class.
    [identifier aspect_hookSelector:@selector(remove) withOptions:AspectPositionBefore usingBlock:^(id instance, NSArray *args) {
        AspectsContainer *aspectContainer = aspect_getContainerForObject((id)self, selector);
        AspectClassContainer *classContainer = aspect_getClassContainerForClass(self);
        NSMutableArray *aspectMutableArray = [classContainer.instances mutableCopy];
        for (AspectIdentifier *aspect in classContainer.instances) {
        if (aspect.selector == identifier.selector) {
                [aspect remove];
                [aspectMutableArray removeObject:aspect];
            }
        }
        classContainer.instances = [NSArray arrayWithArray:aspectMutableArray];
        [classContainer removeAspectContainer:aspectContainer];
    } error:NULL];
    
    return (id<Aspect>)identifier;
}

/// @return A token which allows to later deregister the aspect.
- (id<Aspect>)aspect_hookSelector:(SEL)selector
                      withOptions:(AspectOptions)options
                       usingBlock:(AspectBlock)block
                            error:(NSError **)error {
    return aspect_add(self, selector, options, block, error);
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Private Helper

static id aspect_add(id self, SEL selector, AspectOptions options, AspectBlock block, NSError **error) {
    NSCParameterAssert(self);
    NSCParameterAssert(selector);
    NSCParameterAssert(block);

    __block AspectIdentifier *identifier = nil;
    aspect_performLocked(^{
        if (aspect_isSelectorAllowedAndTrack(self, selector, options, error)) {
            AspectsContainer *aspectContainer = aspect_getContainerForObject(self, selector);
            identifier = [[AspectIdentifier alloc] initWithSelector:selector object:self options:options block:block];
            [aspectContainer addAspect:identifier withOptions:options];

            // Modify the class to allow message interception.
            aspect_prepareClassAndHookSelector(self, selector, error);
        }
    });
    return identifier;
}

static BOOL aspect_remove(AspectIdentifier *aspect, NSError **error) {
    NSCAssert([aspect isKindOfClass:AspectIdentifier.class], @"Must have correct type.");

    __block BOOL success = NO;
    aspect_performLocked(^{
        id self = aspect.object; // strongify
        if (self) {
            AspectsContainer *aspectContainer = aspect_getContainerForObject(self, aspect.selector);
            success = [aspectContainer removeAspect:aspect];

            aspect_cleanupHookedClassAndSelector(self, aspect.selector);
        }else {
            NSString *errrorDesc = [NSString stringWithFormat:@"Unable to deregister hook. Object already deallocated: %@", aspect];
            AspectError(AspectsErrorRemoveObjectAlreadyDeallocated, errrorDesc);
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
	return NSSelectorFromString([AspectsMessagePrefix stringByAppendingFormat:@"_%@", NSStringFromSelector(selector)]);
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Class + Selector Preparation

static void aspect_prepareClassAndHookSelector(NSObject *self, SEL selector, NSError **error) {
    NSCParameterAssert(selector);
    Class klass = aspect_hookClass(self, error);
    Method targetMethod = class_getInstanceMethod(klass, selector);
    IMP targetMethodIMP = method_getImplementation(targetMethod);
    if (targetMethodIMP != _objc_msgForward
#if !defined(__arm64__)
        && targetMethodIMP != (IMP)_objc_msgForward_stret
#endif
        ) {

        // Make a method alias for the existing method implementation, it not already copied.
        const char *typeEncoding = method_getTypeEncoding(targetMethod);
        SEL aliasSelector = aspect_aliasForSelector(selector);
        if (![klass instancesRespondToSelector:aliasSelector]) {
            __unused BOOL addedAlias = class_addMethod(klass, aliasSelector, method_getImplementation(targetMethod), typeEncoding);
            NSCAssert(addedAlias, @"Original implementation for %@ is already copied to %@ on %@", NSStringFromSelector(selector), NSStringFromSelector(aliasSelector), klass);
        }

        // We use forwardInvocation to hook in.
        IMP msgForwardIMP = _objc_msgForward;
#if !defined(__arm64__)
        // As an ugly internal runtime implementation detail in the 32bit runtime, we need to determine of the method we hook returns a struct or anything larger than id.
        // https://developer.apple.com/library/mac/documentation/DeveloperTools/Conceptual/LowLevelABI/000-Introduction/introduction.html
        NSMethodSignature *signature = [self methodSignatureForSelector:selector];
        if (signature.methodReturnLength > sizeof(id)) {
            msgForwardIMP = (IMP)_objc_msgForward_stret;
        }
#endif
        class_replaceMethod(klass, selector, msgForwardIMP, typeEncoding);
        AspectLog(@"Aspects: Installed hook for -[%@ %@].", klass, NSStringFromSelector(selector));
    }
}

// Will undo the runtime changes made.
static void aspect_cleanupHookedClassAndSelector(NSObject *self, SEL selector) {
    NSCParameterAssert(self);
    NSCParameterAssert(selector);

	Class klass = object_getClass(self);
    BOOL isMetaClass = class_isMetaClass(klass);
    if (isMetaClass) {
        klass = (Class)self;
    }

    // Check if the method is marked as forwarded and undo that.
    Method targetMethod = class_getInstanceMethod(klass, selector);
    IMP targetMethodIMP = method_getImplementation(targetMethod);
    if (targetMethodIMP == _objc_msgForward
#if !defined(__arm64__)
        || targetMethodIMP == (IMP)_objc_msgForward_stret
#endif
        ) {

        // Restore the original method implementation.
        const char *typeEncoding = method_getTypeEncoding(targetMethod);
        SEL aliasSelector = aspect_aliasForSelector(selector);
        Method originalMethod = class_getInstanceMethod(klass, aliasSelector);
        IMP originalIMP = method_getImplementation(originalMethod);
        NSCAssert(originalMethod, @"Original implementation for %@ not found %@ on %@", NSStringFromSelector(selector), NSStringFromSelector(aliasSelector), klass);

        class_replaceMethod(klass, selector, originalIMP, typeEncoding);
        AspectLog(@"Aspects: Removed hook for -[%@ %@].", klass, NSStringFromSelector(selector));
    }

    // Deregister global tracked selector
    aspect_deregisterTrackedSelector(self, selector);

    // Get the aspect container and check if there are any hooks remaining. Clean up if there are not.
    AspectsContainer *container = aspect_getContainerForObject(self, selector);
    if (!container.hasAspects) {
        // Destroy the container
        aspect_destroyContainerForObject(self, selector);

        // Figure out how the class was modified to undo the changes.
        NSString *className = NSStringFromClass(klass);
        if ([className hasSuffix:AspectsSubclassSuffix]) {
            Class originalClass = NSClassFromString([className stringByReplacingOccurrencesOfString:AspectsSubclassSuffix withString:@""]);
            NSCAssert(originalClass != nil, @"Original class must exist");
            object_setClass(self, originalClass);
            AspectLog(@"Aspects: %@ has been restored.", NSStringFromClass(originalClass));

            // We can only dispose the class pair if we can ensure that no instances exist using our subclass.
            // Since we don't globally track this, we can't ensure this - but there's also not much overhead in keeping it around.
            //objc_disposeClassPair(object.class);
        }else {
            // Class is most likely swizzled in place. Undo that.
            if (isMetaClass) {
                aspect_undoSwizzleClassInPlace((Class)self);
            }
        }
    }
}

static void aspects_swizzleAlloc(Class klass) {
    Method method = class_getClassMethod(klass, @selector(alloc));
    IMP originalIMP = NULL;
    
    static OSSpinLock lock = OS_SPINLOCK_INIT;
    
    // This block will be called by the client to get original implementation and call it.
    IMP (^originalImpProvider)(void)  = ^IMP{
        // It's possible that another thread can call the method between the call to
        // class_replaceMethod and its return value being set.
        // So to be sure originalIMP has the right value, we need a lock.
        OSSpinLockLock(&lock);
        IMP imp = originalIMP;
        OSSpinLockUnlock(&lock);
        
        if (NULL == imp){
            // If the class does not implement the method
            // we need to find an implementation in one of the superclasses.
            Class superclass = class_getSuperclass(klass);
            imp = method_getImplementation(class_getClassMethod(superclass,@selector(alloc)));
        }
        return imp;
    };
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wshadow"
    id newIMPBlock = ^id (__attribute__((objc_ownership(none))) id self) {
        IMP originalImplementation = originalImpProvider();
        id instance = originalImplementation(self, @selector(alloc));
        
        AspectClassContainer *classContainer = aspect_getClassContainerForClass(klass);
        NSMutableArray *aspectMutableArray = [NSMutableArray array];
        
        for (AspectsContainer *container in classContainer.aspectContainers) {
            for (AspectIdentifier *aspect in container.beforeAspects) {
                [aspectMutableArray addObject:aspect_add(instance, aspect.selector, aspect.options, aspect.block, NULL)];
            }
            for (AspectIdentifier *aspect in container.insteadAspects) {
                [aspectMutableArray addObject:aspect_add(instance, aspect.selector, aspect.options, aspect.block, NULL)];
            }
            for (AspectIdentifier *aspect in container.afterAspects) {
                [aspectMutableArray addObject:aspect_add(instance, aspect.selector, aspect.options, aspect.block, NULL) ];
            }
        }
        
        classContainer.instances = [(classContainer.instances ?: @[]) arrayByAddingObjectsFromArray:aspectMutableArray];
        
        return instance;
    };
#pragma clang diagnostic pop
    
    IMP newIMP = imp_implementationWithBlock(newIMPBlock);
    
    // We need a lock to be sure that originalIMP has the right value in the
    // originalImpProvider block above.
    OSSpinLockLock(&lock);
    originalIMP = class_replaceMethod(object_getClass(klass), @selector(alloc), newIMP, method_getTypeEncoding(method));
    OSSpinLockUnlock(&lock);
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Hook Class

static Class aspect_hookClass(NSObject *self, NSError **error) {
    NSCParameterAssert(self);
	Class statedClass = self.class;
	Class baseClass = object_getClass(self);
	NSString *className = NSStringFromClass(baseClass);

    // Already subclassed
	if ([className hasSuffix:AspectsSubclassSuffix]) {
		return baseClass;

        // We swizzle a class object, not a single object.
	}else if (class_isMetaClass(baseClass)) {
        return aspect_swizzleClassInPlace((Class)self);
        // Probably a KVO'ed class. Swizzle in place. Also swizzle meta classes in place.
    }else if (statedClass != baseClass) {
        return aspect_swizzleClassInPlace(baseClass);
    }

    // Default case. Create dynamic subclass.
	const char *subclassName = [className stringByAppendingString:AspectsSubclassSuffix].UTF8String;
	Class subclass = objc_getClass(subclassName);

	if (subclass == nil) {
		subclass = objc_allocateClassPair(baseClass, subclassName, 0);
		if (subclass == nil) {
            NSString *errrorDesc = [NSString stringWithFormat:@"objc_allocateClassPair failed to allocate class %s.", subclassName];
            AspectError(AspectsErrorFailedToAllocateClassPair, errrorDesc);
            return nil;
        }

		aspect_swizzleForwardInvocation(subclass);
		aspect_hookedGetClass(subclass, statedClass);
		aspect_hookedGetClass(object_getClass(subclass), statedClass);
		objc_registerClassPair(subclass);
	}

	object_setClass(self, subclass);
	return subclass;
}

static NSString *const AspectsForwardInvocationSelectorName = @"__aspects_forwardInvocation:";
static void aspect_swizzleForwardInvocation(Class klass) {
    NSCParameterAssert(klass);
    // If there is no method, replace will act like class_addMethod.
    IMP originalImplementation = class_replaceMethod(klass, @selector(forwardInvocation:), (IMP)__ASPECTS_ARE_BEING_CALLED__, "v@:@");
    if (originalImplementation) {
        class_addMethod(klass, NSSelectorFromString(AspectsForwardInvocationSelectorName), originalImplementation, "v@:@");
    }
    AspectLog(@"Aspects: %@ is now aspect aware.", NSStringFromClass(klass));
}

static void aspect_undoSwizzleForwardInvocation(Class klass) {
    NSCParameterAssert(klass);
    Method originalMethod = class_getInstanceMethod(klass, NSSelectorFromString(AspectsForwardInvocationSelectorName));
    Method objectMethod = class_getInstanceMethod(NSObject.class, @selector(forwardInvocation:));
    // There is no class_removeMethod, so the best we can do is to retore the original implementation, or use a dummy.
    IMP originalImplementation = method_getImplementation(originalMethod ?: objectMethod);
    class_replaceMethod(klass, @selector(forwardInvocation:), originalImplementation, "v@:@");

    AspectLog(@"Aspects: %@ has been restored.", NSStringFromClass(klass));
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
#pragma mark - Swizzle Class In Place

static void _aspect_modifySwizzledClasses(void (^block)(NSMutableSet *swizzledClasses)) {
    static NSMutableSet *swizzledClasses;
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{
        swizzledClasses = [NSMutableSet new];
    });
    @synchronized(swizzledClasses) {
        block(swizzledClasses);
    }
}

static Class aspect_swizzleClassInPlace(Class klass) {
    NSCParameterAssert(klass);
    NSString *className = NSStringFromClass(klass);

    _aspect_modifySwizzledClasses(^(NSMutableSet *swizzledClasses) {
        if (![swizzledClasses containsObject:className]) {
            aspect_swizzleForwardInvocation(klass);
            [swizzledClasses addObject:className];
        }
    });
    return klass;
}

static void aspect_undoSwizzleClassInPlace(Class klass) {
    NSCParameterAssert(klass);
    NSString *className = NSStringFromClass(klass);

    _aspect_modifySwizzledClasses(^(NSMutableSet *swizzledClasses) {
        if ([swizzledClasses containsObject:className]) {
            aspect_undoSwizzleForwardInvocation(klass);
            [swizzledClasses removeObject:className];
        }
    });
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Aspect Invoke Point

// This is a macro so we get a cleaner stack trace.
#define aspect_invoke(aspects, arguments) \
for (AspectIdentifier *aspect in aspects) {\
    ((void (^)(id, NSArray *))aspect.block)(self, arguments);\
    if (aspect.options & AspectOptionAutomaticRemoval) { \
        aspectsToRemove = [aspectsToRemove?:@[] arrayByAddingObject:aspect]; \
    } \
}

// This is the swizzled forwardInvocation: method.
static void __ASPECTS_ARE_BEING_CALLED__(__unsafe_unretained NSObject *self, SEL selector, NSInvocation *invocation) {
    NSCParameterAssert(self);
    NSCParameterAssert(invocation);
	SEL aliasSelector = aspect_aliasForSelector(invocation.selector);
    AspectsContainer *objectContainer = objc_getAssociatedObject(self, aliasSelector);
    NSArray *aspectsToRemove = nil;

    // Before hooks.
    NSArray *arguments = nil;
    if (objectContainer.hasAspects) {
        // Only collect the arguments if there are hooks to call.
        arguments = invocation.aspects_arguments;
        aspect_invoke(objectContainer.beforeAspects, arguments);
    }

    // Instead hooks.
    BOOL respondsToAlias = YES;
    if (objectContainer.insteadAspects.count) {
        invocation.selector = aliasSelector;
        NSArray *argumentsWithInvocation = [arguments arrayByAddingObject:invocation];
        aspect_invoke(objectContainer.insteadAspects, argumentsWithInvocation);
    }else {
        Class klass = object_getClass(invocation.target);
        do {
            if ((respondsToAlias = [klass instancesRespondToSelector:aliasSelector])) {
                invocation.selector = aliasSelector;
                [invocation invoke];
                break;
            }
        }while (!respondsToAlias && (klass = class_getSuperclass(klass)));
    }

    // After hooks.
    aspect_invoke(objectContainer.afterAspects, arguments);

    // If no hooks are installed, call original implementation (usually to throw an exception)
    if (!respondsToAlias) {
        SEL originalForwardInvocationSEL = NSSelectorFromString(AspectsForwardInvocationSelectorName);
        if ([self respondsToSelector:originalForwardInvocationSEL]) {
            ((void( *)(id, SEL, NSInvocation *))objc_msgSend)(self, originalForwardInvocationSEL, invocation);
        }else {
            [self doesNotRecognizeSelector:invocation.selector];
        }
    }

    // Remove any hooks that are queued for deregistration.
    [aspectsToRemove makeObjectsPerformSelector:@selector(remove)];
}
#undef aspect_invoke

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Aspect Container Management

static AspectClassContainer *aspect_getClassContainerForClass(Class klass) {
    NSCParameterAssert(klass);
    
    static void *AspectClassContainerKey = &AspectClassContainerKey;
    
    AspectClassContainer *aspectClassContainer = objc_getAssociatedObject(klass, AspectClassContainerKey);
    if (!aspectClassContainer) {
        aspectClassContainer = [AspectClassContainer new];
        objc_setAssociatedObject(klass, AspectClassContainerKey, aspectClassContainer, OBJC_ASSOCIATION_RETAIN);
    }
    return aspectClassContainer;
}

// Loads or creates the aspect container.
static AspectsContainer *aspect_getContainerForObject(NSObject *self, SEL selector) {
    NSCParameterAssert(self);
    SEL aliasSelector = aspect_aliasForSelector(selector);
    AspectsContainer *aspectContainer = objc_getAssociatedObject(self, aliasSelector);
    if (!aspectContainer) {
        aspectContainer = [AspectsContainer new];
        objc_setAssociatedObject(self, aliasSelector, aspectContainer, OBJC_ASSOCIATION_RETAIN);
    }
    return aspectContainer;
}

static void aspect_destroyContainerForObject(id<NSObject> self, SEL selector) {
    NSCParameterAssert(self);
    SEL aliasSelector = aspect_aliasForSelector(selector);
    objc_setAssociatedObject(self, aliasSelector, nil, OBJC_ASSOCIATION_RETAIN);
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Selector Blacklist Checking

static NSMutableDictionary *aspect_getSwizzledClassesDict() {
    static NSMutableDictionary *swizzledClassesDict;
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{
        swizzledClassesDict = [NSMutableDictionary new];
    });
    return swizzledClassesDict;
}

static BOOL aspect_isSelectorAllowedAndTrack(NSObject *self, SEL selector, AspectOptions options, NSError **error) {
    static NSSet *disallowedSelectorList;
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{
        disallowedSelectorList = [NSSet setWithObjects:@"retain", @"release", @"autorelease", @"forwardInvocation:", nil];
    });

    // Check against the blacklist.
    NSString *selectorName = NSStringFromSelector(selector);
    if ([disallowedSelectorList containsObject:selectorName]) {
        NSString *errorDescription = [NSString stringWithFormat:@"Selector %@ is blacklisted.", selectorName];
        AspectError(AspectsErrorSelectorBlacklisted, errorDescription);
        return NO;
    }

    // Additional checks.
    AspectOptions position = options&AspectPositionFilter;
    if ([selectorName isEqualToString:@"dealloc"] && position != AspectPositionBefore) {
        NSString *errorDesc = @"AspectPositionBefore is the only valid position when hooking dealloc.";
        AspectError(AspectsErrorSelectorDeallocPosition, errorDesc);
        return NO;
    }

    if (![self respondsToSelector:selector] && ![self.class instancesRespondToSelector:selector]) {
        NSString *errorDesc = [NSString stringWithFormat:@"Unable to find selector -[%@ %@].", NSStringFromClass(self.class), selectorName];
        AspectError(AspectsErrorDoesNotRespondToSelector, errorDesc);
        return NO;
    }
    
    return YES;
}

static void aspect_deregisterTrackedSelector(id self, SEL selector) {
    if (!class_isMetaClass(object_getClass(self))) return;

    NSMutableDictionary *swizzledClassesDict = aspect_getSwizzledClassesDict();
    NSString *selectorName = NSStringFromSelector(selector);
    Class currentClass = [self class];
    do {
        AspectTracker *tracker = swizzledClassesDict[currentClass];
        if (tracker) {
            [tracker.selectorNames removeObject:selectorName];
            if (tracker.selectorNames.count == 0) {
                [swizzledClassesDict removeObjectForKey:tracker];
            }
        }
    }while ((currentClass = class_getSuperclass(currentClass)));
}

@end

@implementation AspectTracker

- (id)initWithTrackedClass:(Class)trackedClass parent:(AspectTracker *)parent {
    if (self = [super init]) {
        _trackedClass = trackedClass;
        _parentEntry = parent;
        _selectorNames = [NSMutableSet new];
    }
    return self;
}
- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %@, trackedClass: %@, selectorNames:%@, parent:%p>", self.class, self, NSStringFromClass(self.trackedClass), self.selectorNames, self.parentEntry];
}

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
        // Using this list will box the number with the appropriate constructor, instead of the generic NSValue.
	} else if (strcmp(argType, @encode(char)) == 0) {
		WRAP_AND_RETURN(char);
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

- (id)initWithSelector:(SEL)selector object:(id)object options:(AspectOptions)options block:(id)block {
    NSCParameterAssert(block);
    NSCParameterAssert(selector);
    if (self = [super init]) {
        _selector = selector;
        _block = block;
        _options = options;
        _object = object; // weak
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p, SEL:%@ object:%@ options:%tu block:%@>", self.class, self, NSStringFromSelector(self.selector), self.object, self.options, self.block];
}

- (BOOL)remove {
    return aspect_remove(self, NULL);
}

@end

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - AspectsContainer

@implementation AspectsContainer

- (BOOL)hasAspects {
    return self.beforeAspects.count > 0 || self.insteadAspects.count > 0 || self.afterAspects.count > 0;
}

- (void)addAspect:(AspectIdentifier *)aspect withOptions:(AspectOptions)options {
    NSUInteger position = options&AspectPositionFilter;
    switch (position) {
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

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p, before:%@, instead:%@, after:%@>", self.class, self, self.beforeAspects, self.insteadAspects, self.afterAspects];
}

@end

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - AspectClassContainer

@implementation AspectClassContainer

- (void)removeAspectContainer:(AspectsContainer *)container {
    NSMutableArray *mutableArray = [self.aspectContainers mutableCopy];
    [mutableArray removeObject:container];
    self.aspectContainers = [NSArray arrayWithArray:mutableArray];
}

@end
