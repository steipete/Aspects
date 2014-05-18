//
//  Aspects.m
//  Aspects - A delightful, simple library for aspect oriented programming.
//
//  Copyright (c) 2014 Peter Steinberger. Licensed under the MIT license.
//

#import "Aspects.h"
#import <AssertMacros.h>
#import <libkern/OSAtomic.h>
#import <objc/runtime.h>
#import <objc/message.h>

#define AspectLog(...)
//#define AspectLog(...) do { NSLog(__VA_ARGS__); }while(0)
#define AspectLogError(...) do { NSLog(__VA_ARGS__); }while(0)

// Used within hooking on the block.
@interface AspectInfo : NSObject <AspectInfo>
- (id)initWithInstance:(__unsafe_unretained id)instance invocation:(NSInvocation *)invocation;
@property (nonatomic, unsafe_unretained, readonly) id instance;
@property (nonatomic, strong, readonly) NSArray *arguments;
@property (nonatomic, strong, readonly) NSInvocation *originalInvocation;
@end

// Tracks a single aspect, allows removal.
@interface AspectIdentifier : NSObject
+ (instancetype)identifierWithSelector:(SEL)selector object:(id)object options:(AspectOptions)options block:(id)block error:(NSError **)error;
- (void)invokeWithAspectInfo:(id<AspectInfo>)info;
@property (nonatomic, assign) SEL selector;
@property (nonatomic, strong) id block;
@property (nonatomic, strong) NSMethodSignature *blockSignature;
@property (nonatomic, weak) id object;
@property (nonatomic, assign) AspectOptions options;
@end

// Tracks all aspects for an object/class.
@interface AspectsContainer : NSObject
- (void)addAspect:(AspectIdentifier *)aspect withOptions:(AspectOptions)injectPosition;
- (BOOL)removeAspect:(id)aspect;
- (BOOL)hasAspects;
@property (atomic, copy) NSArray *beforeAspects;
@property (atomic, copy) NSArray *insteadAspects;
@property (atomic, copy) NSArray *afterAspects;
@end

@interface NSInvocation (Aspects)
- (NSArray *)aspects_arguments;
@end

IMP aspects_implementationForwardingToSelector(SEL forwardingSelector, BOOL returnsAStructValue);

#define AspectPositionFilter 0x07

#define AspectError(errorCode, errorDescription) do { \
AspectLogError(@"Aspects: %@", errorDescription); \
if (error) { *error = [NSError errorWithDomain:AspectErrorDomain code:errorCode userInfo:@{NSLocalizedDescriptionKey: errorDescription}]; }}while(0)

NSString *const AspectErrorDomain = @"AspectErrorDomain";
static NSString *const AspectsSubclassSuffix = @"-Aspects_";
static NSString *const AspectsMessagePrefix         = @"__aspects_";
static NSString *const AspectsMessagePrefixOriginal = @"__aspects_original_";

@implementation NSObject (Aspects)

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Public Aspects API

+ (id<AspectToken>)aspect_hookSelector:(SEL)selector
                           withOptions:(AspectOptions)options
                            usingBlock:(id)block
                                 error:(NSError **)error {
    return aspect_add((id)self, selector, options, block, error);
}

/// @return A token which allows to later deregister the aspect.
- (id<AspectToken>)aspect_hookSelector:(SEL)selector
                           withOptions:(AspectOptions)options
                            usingBlock:(id)block
                                 error:(NSError **)error {
    return aspect_add(self, selector, options, block, error);
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Private Helper

static id aspect_add(id self, SEL selector, AspectOptions options, id block, NSError **error) {
    NSCParameterAssert(self);
    NSCParameterAssert(selector);
    NSCParameterAssert(block);

    __block AspectIdentifier *identifier = nil;
    aspect_performLocked(^{
        if (aspect_isSelectorAllowed(self, selector, options, error)) {
            AspectsContainer *aspectContainer = aspect_getContainerForObject(self, selector);
            identifier = [AspectIdentifier identifierWithSelector:selector object:self options:options block:block error:error];
            if (identifier) {
                [aspectContainer addAspect:identifier withOptions:options];

                // Modify the class to allow message interception.
                aspect_prepareClassAndHookSelector(self, selector, options, error);
            }
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
            // destroy token
            aspect.object = nil;
            aspect.block = nil;
            aspect.selector = NULL;
        }else {
            NSString *errrorDesc = [NSString stringWithFormat:@"Unable to deregister hook. Object already deallocated: %@", aspect];
            AspectError(AspectErrorRemoveObjectAlreadyDeallocated, errrorDesc);
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

// @selector(foo) -> __aspects_original_AClass_foo
static SEL aspect_aliasForSelector(Class klass, SEL selector, BOOL original) {
    NSCParameterAssert(selector);
	return NSSelectorFromString([original ? AspectsMessagePrefixOriginal : AspectsMessagePrefix stringByAppendingFormat:@"%@_%@",
                                 NSStringFromClass(klass), NSStringFromSelector(selector)]);
}

static SEL aspect_originalSelectorFromForwardingSelector(SEL forwardingSelector) {
    return NSSelectorFromString([NSStringFromSelector(forwardingSelector) stringByReplacingOccurrencesOfString:AspectsMessagePrefix withString:AspectsMessagePrefixOriginal]);
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - C Calling Conventions

// We need to honor C calling conventions, where stuct-based returns have a different stack layout.
// This is platform dependant and not easy to figure out.
// https://github.com/ReactiveCocoa/ReactiveCocoa/issues/783
// http://infocenter.arm.com/help/topic/com.arm.doc.ihi0042e/IHI0042E_aapcs.pdf (Section 5.4)
static BOOL aspect_methodReturnsStructValue(Method method) {
    NSCParameterAssert(method);
    const char *encoding = method_getTypeEncoding(method);
    BOOL methodReturnsStructValue = encoding[0] == _C_STRUCT_B;
    if (methodReturnsStructValue) {
        @try {
            NSUInteger valueSize = 0;
            NSGetSizeAndAlignment(encoding, &valueSize, NULL);

            if (valueSize == 1 || valueSize == 2 || valueSize == 4 || valueSize == 8) {
                methodReturnsStructValue = NO;
            }
        } @catch (__unused NSException *e) {}
    }
    return methodReturnsStructValue;
}

static BOOL aspect_isMsgForwardIMP(IMP impl) {
    return impl == _objc_msgForward
#if !defined(__arm64__)
    || impl == (IMP)_objc_msgForward_stret
#endif
    ;
}

static IMP aspect_getMsgForwardIMP(Method method) {
    IMP msgForwardIMP = _objc_msgForward;
#if !defined(__arm64__)
    if (aspect_methodReturnsStructValue(method)) {
        msgForwardIMP = (IMP)_objc_msgForward_stret; // OBJC_ARM64_UNAVAILABLE
    }
#endif
    return msgForwardIMP;
}

static BOOL aspect_isClassMethod(Class klass, SEL selector, AspectOptions options) {
    BOOL hasInstanceMethod = [klass instancesRespondToSelector:selector];
    BOOL hasClassMethod = [klass respondsToSelector:selector];
    BOOL prefersClassMethod = (options & AspectOptionPreferClassMethod) > 0;
    return (prefersClassMethod && hasClassMethod) || (!hasInstanceMethod && hasClassMethod);
}

static Method aspect_getInstanceOrClassMethod(Class klass, SEL s, BOOL isClassMethod) {
    return isClassMethod ? class_getClassMethod(klass, s) : class_getInstanceMethod(klass, s);
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Class + Selector Preparation

static void aspect_prepareClassAndHookSelector(NSObject *self, SEL originalSEL, AspectOptions options, NSError **error) {
    NSCParameterAssert(originalSEL);
    // Create dynamic subclass if we hook a single object.
    BOOL isClassMethod = aspect_isClassMethod([self class], originalSEL, options);
    Class hookedClass = aspect_hookClass(self, isClassMethod, error);
    Class statedClass = [hookedClass class]; // if we lie about the class, be consistent.

    // Build new unique selector names based on the class name.
    SEL forwardingSEL = aspect_aliasForSelector(statedClass, originalSEL, NO);
    SEL originalImplementationSEL = aspect_aliasForSelector(statedClass, originalSEL, YES);
    Method method = aspect_getInstanceOrClassMethod(hookedClass, originalSEL, isClassMethod);
    NSCAssert(method, @"We must be able to get the method.");
    IMP targetMethodIMP = method_getImplementation(method);
    BOOL recordingClassDoesImplementOriginalSelector = ([hookedClass instanceMethodForSelector:originalSEL] != [[hookedClass superclass] instanceMethodForSelector:originalSEL]) || ([hookedClass methodForSelector:originalSEL] != [[hookedClass superclass] methodForSelector:originalSEL]);
    BOOL isMsgForwardIMP = aspect_isMsgForwardIMP(targetMethodIMP);

    // Check if class is still free to be modified
    if (![hookedClass instancesRespondToSelector:forwardingSEL]) {
        // Add original method with scheme aspects_original_ClassName_SelectorName with the original implementation.
        if (![hookedClass instancesRespondToSelector:originalImplementationSEL]) {
            __unused BOOL addedAlias = class_addMethod(hookedClass, originalImplementationSEL, targetMethodIMP, method_getTypeEncoding(method));
            NSCAssert(addedAlias, @"Original implementation for %@ is already copied to %@ on %@", NSStringFromSelector(originalSEL), NSStringFromSelector(originalImplementationSEL), hookedClass);
        }

        // Add new method to the current class (replacing an existing method!)
        if (recordingClassDoesImplementOriginalSelector && !isMsgForwardIMP) {
            // Generate forwarder that deals as our custom _objc_msgForward/_objc_msgForward_stret token.
            // This allows is to correctly find and idientify which implementation should be called.
            BOOL useStret = aspect_methodReturnsStructValue(method);
            method_setImplementation(method, aspects_implementationForwardingToSelector(forwardingSEL, useStret));
        }else {
            // The method we want to hook doesn't exist in the current class. We add a dummy forwarder instead.
            if (!isMsgForwardIMP) {
                class_replaceMethod(hookedClass, originalSEL, aspect_getMsgForwardIMP(method), method_getTypeEncoding(method));
            }
        }
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

    // Restore the original method implementation.
    const char *typeEncoding = method_getTypeEncoding(targetMethod);
    SEL aliasSelector = aspect_aliasForSelector(klass, selector, YES);
    Method originalMethod = class_getInstanceMethod(klass, aliasSelector);
    IMP originalIMP = method_getImplementation(originalMethod);
    if (originalIMP) {
        if (aspect_isMsgForwardIMP(targetMethodIMP)) {
            class_replaceMethod(klass, selector, originalIMP, typeEncoding);
        }else {
            Method method = class_getInstanceMethod(klass, selector);
            method_setImplementation(method, originalIMP);
        }
        AspectLog(@"Aspects: Removed hook for -[%@ %@].", klass, NSStringFromSelector(selector));
    }

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

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Hook Class methods

static Class aspect_hookClass(NSObject *self, BOOL isClassMethod, NSError **error) {
    NSCParameterAssert(self);
	Class statedClass = self.class;
	Class baseClass = object_getClass(self);
	NSString *className = NSStringFromClass(baseClass);

    // Already subclassed
	if ([className hasSuffix:AspectsSubclassSuffix]) {
		return baseClass;

        // We swizzle a class object, not a single object.
	}else if (class_isMetaClass(baseClass)) {
        return aspect_swizzleClassInPlace(isClassMethod ? baseClass : (Class)self);
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
            AspectError(AspectErrorFailedToAllocateClassPair, errrorDesc);
            return nil;
        }

		aspect_swizzleForwardInvocation(subclass);
		aspect_swizzleMethodSignature(subclass);
		aspect_swizzleGetClass(subclass, statedClass);
		aspect_swizzleGetClass(object_getClass(subclass), statedClass);
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

// TODO: Add undo code
static void aspect_swizzleMethodSignature(Class klass) {
    // Get original implementation.
    SEL selector = @selector(methodSignatureForSelector:);
    Method method = class_getInstanceMethod(klass, selector);
    method_getImplementation(method);
    NSMethodSignature* (*originalMethodSignatureIMP)(id, SEL, SEL) = NULL;
	if (method != NULL) {
		originalMethodSignatureIMP = (__typeof__(originalMethodSignatureIMP))method_getImplementation(method);
	}

    // Swap with new hook.
    IMP newIMP = imp_implementationWithBlock(^(id self, SEL forwardingSelector) {
        if ([NSStringFromSelector(forwardingSelector) hasPrefix:AspectsMessagePrefix]) {
            SEL originalSEL = aspect_originalSelectorFromForwardingSelector(forwardingSelector);
            Method forwardedMethod = class_getInstanceMethod(object_getClass(self), originalSEL);
            return [NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(forwardedMethod)];
        }else {
            return originalMethodSignatureIMP(self, selector, forwardingSelector);
        }
    });
	class_replaceMethod(klass, selector, newIMP, method_getTypeEncoding(method));
}

static void aspect_swizzleGetClass(Class klass, Class statedClass) {
    NSCParameterAssert(klass);
    NSCParameterAssert(statedClass);
	Method method = class_getInstanceMethod(klass, @selector(class));
	IMP newIMP = imp_implementationWithBlock(^(id self) {
		return statedClass;
	});
	class_replaceMethod(klass, @selector(class), newIMP, method_getTypeEncoding(method));
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

static NSString *aspect_getClassName(Class klass) {
    NSString *className = NSStringFromClass(klass);
    if (class_isMetaClass(klass)) {
        className = [className stringByAppendingString:@"__aspect_metaclass__"];
    }
    return className;
}

static Class aspect_swizzleClassInPlace(Class klass) {
    NSCParameterAssert(klass);
    NSString *className = aspect_getClassName(klass);

    _aspect_modifySwizzledClasses(^(NSMutableSet *swizzledClasses) {
        if (![swizzledClasses containsObject:className]) {
            aspect_swizzleForwardInvocation(klass);
            aspect_swizzleMethodSignature(klass);
            [swizzledClasses addObject:className];
        }
    });
    return klass;
}

static void aspect_undoSwizzleClassInPlace(Class klass) {
    NSCParameterAssert(klass);
    NSString *className = aspect_getClassName(klass);

    _aspect_modifySwizzledClasses(^(NSMutableSet *swizzledClasses) {
        if ([swizzledClasses containsObject:className]) {
            aspect_undoSwizzleForwardInvocation(klass);
            [swizzledClasses removeObject:className];
        }
    });
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Aspects Invoke Point

// This is a macro so we get a cleaner stack trace.
#define aspect_invoke(aspects, info) \
for (AspectIdentifier *aspect in aspects) { \
[aspect invokeWithAspectInfo:info]; \
if (aspect.options & AspectOptionAutomaticRemoval) { \
aspectsToRemove = [aspectsToRemove?:@[] arrayByAddingObject:aspect]; }}

// This is the swizzled forwardInvocation: method.
static void __ASPECTS_ARE_BEING_CALLED__(__unsafe_unretained NSObject *self, SEL selector, NSInvocation *invocation) {
    NSCParameterAssert(self);
    NSCParameterAssert(invocation);
    SEL invocationSelector = invocation.selector;
    SEL classLookupSelector = invocationSelector;
	SEL originalSelector = aspect_originalSelectorFromForwardingSelector(invocationSelector);

    // Subclass situation. We're called with the raw selector and forward to the _original_ one.
    if (invocationSelector == originalSelector) {
        originalSelector = aspect_aliasForSelector(self.class, invocationSelector, YES);
        classLookupSelector = aspect_aliasForSelector(self.class, invocationSelector, NO);
    }
    invocation.selector = originalSelector;
    AspectsContainer *objectContainer = objc_getAssociatedObject(self, classLookupSelector);
    AspectsContainer *classContainer = aspect_getContainerForClass(object_getClass(self), classLookupSelector);
    AspectInfo *info = [[AspectInfo alloc] initWithInstance:self invocation:invocation];
    NSArray *aspectsToRemove = nil;

    // Before hooks.
    aspect_invoke(classContainer.beforeAspects,  info);
    aspect_invoke(objectContainer.beforeAspects, info);

    // Instead hooks.
    BOOL respondsToAlias = YES;
    if (objectContainer.insteadAspects.count || classContainer.insteadAspects.count) {
        aspect_invoke(classContainer.insteadAspects,  info);
        aspect_invoke(objectContainer.insteadAspects, info);
    }else {
        Class klass = object_getClass(invocation.target);
        do {
            if ((respondsToAlias = [klass instancesRespondToSelector:originalSelector])) {
                [invocation invoke];
                break;
            }
        }while (!respondsToAlias && (klass = class_getSuperclass(klass)));
    }

    // After hooks.
    aspect_invoke(classContainer.afterAspects,  info);
    aspect_invoke(objectContainer.afterAspects, info);

    // If no hooks are installed, call original implementation (usually to throw an exception)
    if (!respondsToAlias) {
        invocation.selector = invocationSelector;
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

// Loads or creates the aspect container.
static AspectsContainer *aspect_getContainerForObject(NSObject *self, SEL selector) {
    NSCParameterAssert(self);
    selector = aspect_aliasForSelector(self.class, selector, NO);
    AspectsContainer *aspectContainer = objc_getAssociatedObject(self, selector);
    if (!aspectContainer) {
        aspectContainer = [AspectsContainer new];
        objc_setAssociatedObject(self, selector, aspectContainer, OBJC_ASSOCIATION_RETAIN);
    }
    return aspectContainer;
}

static AspectsContainer *aspect_getContainerForClass(Class klass, SEL selector) {
    NSCParameterAssert(klass);
    AspectsContainer *classContainer = nil;
    do {
        classContainer = objc_getAssociatedObject(klass, selector);
        if (classContainer.hasAspects) break;
    }while ((klass = class_getSuperclass(klass)));

    return classContainer;
}

static void aspect_destroyContainerForObject(id<NSObject> self, SEL selector) {
    NSCParameterAssert(self);
    SEL aliasSelector = aspect_aliasForSelector(self.class, selector, NO);
    objc_setAssociatedObject(self, aliasSelector, nil, OBJC_ASSOCIATION_RETAIN);
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Selector Blacklist Checking/Validation

static BOOL aspect_isSelectorAllowed(NSObject *self, SEL selector, AspectOptions options, NSError **error) {
    NSString *selectorName = NSStringFromSelector(selector);

    // Check against the blacklist.
    static NSSet *disallowedSelectorList;
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{
        disallowedSelectorList = [NSSet setWithObjects:@"retain", @"release", @"autorelease", @"copy", @"mutableCopy", @"finalize", @"allowsWeakReference", @"retainWeakReference",@"forwardInvocation:", @"forwardingTargetForSelector:", @"methodSignatureForSelector:", @"methodForSelector:", nil];
    });
    if ([disallowedSelectorList containsObject:selectorName]) {
        NSString *errorDesc = [NSString stringWithFormat:@"Selector %@ is blacklisted.", selectorName];
        AspectError(AspectErrorSelectorBlacklisted, errorDesc);
        return NO;
    }

    // Additional checks for dealloc.
    AspectOptions position = options&AspectPositionFilter;
    if ([selectorName isEqualToString:@"dealloc"] && position != AspectPositionBefore) {
        NSString *errorDesc = @"AspectPositionBefore is the only valid position when hooking dealloc.";
        AspectError(AspectErrorSelectorDeallocPosition, errorDesc);
        return NO;
    }

    // Check if the selector exists at all.
    if (![self respondsToSelector:selector] && ![self.class instancesRespondToSelector:selector]) {
        NSString *errorDesc = [NSString stringWithFormat:@"Unable to find selector -[%@ %@].", NSStringFromClass(self.class), selectorName];
        AspectError(AspectErrorDoesNotRespondToSelector, errorDesc);
        return NO;
    }

    return YES;
}

@end

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Trampoline Code

#import <mach/mach_init.h>
#import <mach/vm_types.h>
#import <mach/vm_map.h>
extern id aspects_forwarding_trampoline_page(id, SEL);
extern id aspects_forwarding_trampoline_stret_page(id, SEL);

typedef struct {
#ifndef __arm64__
    IMP msgSend;
#endif
    SEL selector;
} AspectsTrampolineDataBlock;

#if defined(__arm64__)
typedef int32_t AspectsTrampolineEntryPointBlock[2];
static const int32_t AspectsTrampolineInstructionCount = 6;
#elif defined(_ARM_ARCH_7)
typedef int32_t AspectsTrampolineEntryPointBlock[2];
static const int32_t AspectsTrampolineInstructionCount = 4;
#elif defined(__i386__)
typedef int32_t AspectsTrampolineEntryPointBlock[2];
static const int32_t AspectsTrampolineInstructionCount = 6;
#else
#error Aspects is not yet supported on this platform.
#endif

static const size_t numberOfTrampolinesPerPage = (PAGE_SIZE - AspectsTrampolineInstructionCount * sizeof(int32_t)) / sizeof(AspectsTrampolineEntryPointBlock);

typedef struct {
    union {
        struct {
            IMP msgSend;
            int32_t nextAvailableTrampolineIndex;
        };
        int32_t trampolineSize[AspectsTrampolineInstructionCount];
    };
    AspectsTrampolineDataBlock trampolineData[numberOfTrampolinesPerPage];
    int32_t trampolineInstructions[AspectsTrampolineInstructionCount];
    AspectsTrampolineEntryPointBlock trampolineEntryPoints[numberOfTrampolinesPerPage];
} AspectsTrampolinePage;

check_compile_time(sizeof(AspectsTrampolineEntryPointBlock) == sizeof(AspectsTrampolineDataBlock));
check_compile_time(sizeof(AspectsTrampolinePage) == 2 * PAGE_SIZE);
check_compile_time(offsetof(AspectsTrampolinePage, trampolineInstructions) == PAGE_SIZE);

static AspectsTrampolinePage *aspects_trampolinePageAlloc(BOOL returnsStructValue) {
    vm_address_t trampolineTemplatePage = returnsStructValue ? (vm_address_t)&aspects_forwarding_trampoline_stret_page : (vm_address_t)&aspects_forwarding_trampoline_page;

    vm_address_t newTrampolinePage = 0;
    kern_return_t kernReturn = KERN_SUCCESS;

    // allocate two consequent memory pages.
    kernReturn = vm_allocate(mach_task_self(), &newTrampolinePage, PAGE_SIZE * 2, VM_FLAGS_ANYWHERE);
    NSCAssert1(kernReturn == KERN_SUCCESS, @"vm_allocate failed", kernReturn);

    // deallocate second page where we will store our trampoline/
    vm_address_t trampoline_page = newTrampolinePage + PAGE_SIZE;
    kernReturn = vm_deallocate(mach_task_self(), trampoline_page, PAGE_SIZE);
    NSCAssert1(kernReturn == KERN_SUCCESS, @"vm_deallocate failed", kernReturn);

    // trampoline page will be remapped with implementation of aspects_objc_forwarding_trampoline.
    vm_prot_t cur_protection, max_protection;
    kernReturn = vm_remap(mach_task_self(), &trampoline_page, PAGE_SIZE, 0, 0, mach_task_self(), trampolineTemplatePage, FALSE, &cur_protection, &max_protection, VM_INHERIT_SHARE);
    NSCAssert1(kernReturn == KERN_SUCCESS, @"vm_remap failed", kernReturn);

    return (void *)newTrampolinePage;
}

static AspectsTrampolinePage *aspects_nextTrampolinePage(BOOL returnsStructValue) {
    static NSMutableArray *normalTrampolinePages = nil, *stretTrampolinePages = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        normalTrampolinePages = [NSMutableArray array];
        stretTrampolinePages  = [NSMutableArray array];
    });

    NSMutableArray *trampolinePages = returnsStructValue ? stretTrampolinePages : normalTrampolinePages;
    AspectsTrampolinePage *trampolinePage = [trampolinePages.lastObject pointerValue];

    // No trampoline page, or full?
    if (!trampolinePage || trampolinePage->nextAvailableTrampolineIndex == numberOfTrampolinesPerPage) {
        trampolinePage = aspects_trampolinePageAlloc(returnsStructValue);
        [trampolinePages addObject:[NSValue valueWithPointer:trampolinePage]];
    }
    trampolinePage->msgSend = objc_msgSend;
    return trampolinePage;
}

IMP aspects_implementationForwardingToSelector(SEL forwardingSelector, BOOL returnsAStructValue) {
#ifdef __arm64__
    returnsAStructValue = NO;
#endif
    AspectsTrampolinePage *dataPageLayout = aspects_nextTrampolinePage(returnsAStructValue);
    int32_t nextAvailableTrampolineIndex = dataPageLayout->nextAvailableTrampolineIndex;
#ifndef __arm64__
    dataPageLayout->trampolineData[nextAvailableTrampolineIndex].msgSend = returnsAStructValue ? (IMP)objc_msgSend_stret : objc_msgSend;
#endif
    dataPageLayout->trampolineData[nextAvailableTrampolineIndex].selector = forwardingSelector;
    dataPageLayout->nextAvailableTrampolineIndex++;

    return (IMP)&dataPageLayout->trampolineEntryPoints[nextAvailableTrampolineIndex];
}

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

+ (NSInvocation *)aspects_invocationWithBlockSignature:(NSMethodSignature *)blockSignature
                                            selfObject:(id)selfObject
                               argumentsFromInvocation:(NSInvocation *)originalInvocation {

    // Be extra paranoid. We already check that on hook registration.
    NSUInteger numberOfArguments = blockSignature.numberOfArguments;
    if (numberOfArguments > originalInvocation.methodSignature.numberOfArguments) {
        AspectLogError(@"Block has too many arguments. Not calling %@", selfObject);
        return NO;
    }

    // Start generating the invocation.
    NSInvocation *blockInvocation = [NSInvocation invocationWithMethodSignature:blockSignature];
    if (numberOfArguments > 1) {
        [blockInvocation setArgument:&selfObject atIndex:1];
    }

	void *argBuf = NULL;
    for (NSUInteger idx = 2; idx < numberOfArguments; idx++) {
        const char *type = [originalInvocation.methodSignature getArgumentTypeAtIndex:idx];
		NSUInteger argSize;
		NSGetSizeAndAlignment(type, &argSize, NULL);

		if (!(argBuf = reallocf(argBuf, argSize))) {
            AspectLogError(@"Failed to allocate memory for block invocation.");
			return nil;
		}

		[originalInvocation getArgument:argBuf atIndex:idx];
		[blockInvocation setArgument:argBuf atIndex:idx];
    }
    if (argBuf != NULL) free(argBuf);

    return blockInvocation;
}

@end

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Block Signatures

// Block internals definition (stable ABI)
typedef NS_OPTIONS(int, AspectBlockFlags) {
	AspectBlockFlagsHasCopyDisposeHelpers = (1 << 25),
	AspectBlockFlagsHasSignature          = (1 << 30)
};
typedef struct _AspectBlock {
	__unused Class isa;
	AspectBlockFlags flags;
	__unused int reserved;
	void (__unused *invoke)(struct _AspectBlock *block, ...);
	struct {
		unsigned long int reserved, size;
		// requires AspectBlockFlagsHasCopyDisposeHelpers
		void (*copy)(void *dst, const void *src);
		void (*dispose)(const void *);
		// requires AspectBlockFlagsHasSignature
		const char *signature;
		const char *layout;
	} *descriptor;
	// imported variables
} *AspectBlockRef;

static NSMethodSignature *aspect_blockMethodSignature(id block, NSError **error) {
    NSCParameterAssert(block);
    AspectBlockRef layout = (__bridge void *)block;
	if (!(layout->flags & AspectBlockFlagsHasSignature)) {
        NSString *description = [NSString stringWithFormat:@"The block %@ doesn't contain a type signature.", block];
        AspectError(AspectErrorMissingBlockSignature, description);
        return nil;
    }
	void *desc = layout->descriptor;
	desc += 2 * sizeof(unsigned long int);
	if (layout->flags & AspectBlockFlagsHasCopyDisposeHelpers) {
		desc += 2 * sizeof(void *);
    }
	if (!desc) {
        NSString *description = [NSString stringWithFormat:@"The block %@ doesn't has a type signature.", block];
        AspectError(AspectErrorMissingBlockSignature, description);
        return nil;
    }
	const char *signature = (*(const char **)desc);
	return [NSMethodSignature signatureWithObjCTypes:signature];
}

static NSMethodSignature* aspect_methodSignatureForSelector(id object, SEL selector, AspectOptions options) {
    NSMethodSignature *methodSignature = [[object class] instanceMethodSignatureForSelector:selector];
    if (!methodSignature || (options & AspectOptionPreferClassMethod)) {
        methodSignature = [[object class] methodSignatureForSelector:selector] ?: methodSignature;
    }
    return methodSignature;
}

static BOOL aspect_isCompatibleBlockSignature(NSMethodSignature *blockSignature, id object, SEL selector, AspectOptions options, NSError **error) {
    NSCParameterAssert(blockSignature);
    NSCParameterAssert(object);
    NSCParameterAssert(selector);

    BOOL signaturesMatch = YES;
    NSMethodSignature *methodSignature = aspect_methodSignatureForSelector(object, selector, options);
    if (blockSignature.numberOfArguments > methodSignature.numberOfArguments) {
        signaturesMatch = NO;
    }else {
        if (blockSignature.numberOfArguments > 1) {
            const char *blockType = [blockSignature getArgumentTypeAtIndex:1];
            if (blockType[0] != '@') {
                signaturesMatch = NO;
            }
        }
        // Argument 0 is self/block, argument 1 is SEL or id<AspectInfo>. We start comparing at argument 2.
        // The block can have less arguments than the method, that's ok.
        if (signaturesMatch) {
            for (NSUInteger idx = 2; idx < blockSignature.numberOfArguments; idx++) {
                const char *methodType = [methodSignature getArgumentTypeAtIndex:idx];
                const char *blockType = [blockSignature getArgumentTypeAtIndex:idx];
                // Only compare parameter, not the optional type data.
                if (!methodType || !blockType || methodType[0] != blockType[0]) {
                    signaturesMatch = NO; break;
                }
            }
        }
    }

    if (!signaturesMatch) {
        NSString *desc = [NSString stringWithFormat:@"Blog signature %@ doesn't match %@.", blockSignature, methodSignature];
        AspectError(AspectErrorIncompatibleBlockSignature, desc);
        return NO;
    }

    // Warn if there's a return type in the block signature that does not make sense.
    const char *blockReturn = blockSignature.methodReturnType;
    if (blockReturn[0] != _C_VOID && blockReturn[0] != methodSignature.methodReturnType[0]) {
        AspectLogError(@"Warning! Block return type %s will be ignored.", blockSignature.methodReturnType);
    }

    return YES;
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - AspectIdentifier

@implementation AspectIdentifier

+ (instancetype)identifierWithSelector:(SEL)selector object:(id)object options:(AspectOptions)options block:(id)block error:(NSError **)error {
    AspectIdentifier *identifier = nil;

    NSMethodSignature *blockSignature = aspect_blockMethodSignature(block, error);
    if (aspect_isCompatibleBlockSignature(blockSignature, object, selector, options, error)) {
        identifier = [AspectIdentifier new];
        identifier.selector = selector;
        identifier.block = block;
        identifier.blockSignature = blockSignature;
        identifier.options = options;
        identifier.object = object; // weak
    }
    return identifier;
}

- (void)invokeWithAspectInfo:(id<AspectInfo>)info {
    NSInvocation *invocation = [NSInvocation aspects_invocationWithBlockSignature:self.blockSignature
                                                                       selfObject:info
                                                          argumentsFromInvocation:info.originalInvocation];
    [invocation invokeWithTarget:self.block];

    // Transfer the return value if the hooked method returns data.
    const char *methodReturnType = invocation.methodSignature.methodReturnType;
    if (methodReturnType[0] != _C_VOID && self.blockSignature.methodReturnType[0] == methodReturnType[0]) {
        NSUInteger argSize;
        NSGetSizeAndAlignment(methodReturnType, &argSize, NULL);

        void *argBuf = NULL;
        if (!(argBuf = reallocf(argBuf, argSize))) {
            AspectLogError(@"Failed to allocate memory for block invocation.");
            return;
        }
        [invocation getReturnValue:argBuf];
        [info.originalInvocation setReturnValue:argBuf];
        free(argBuf);
    }
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p, SEL:%@ object:%@ options:%tu block:%@ (#%tu args)>", self.class, self, NSStringFromSelector(self.selector), self.object, self.options, self.block, self.blockSignature.numberOfArguments];
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
    NSParameterAssert(aspect);
    switch (options & AspectPositionFilter) {
        case AspectPositionBefore:  self.beforeAspects  = [(self.beforeAspects ?:@[]) arrayByAddingObject:aspect]; break;
        case AspectPositionInstead: self.insteadAspects = [(self.insteadAspects?:@[]) arrayByAddingObject:aspect]; break;
        case AspectPositionAfter:   self.afterAspects   = [(self.afterAspects  ?:@[]) arrayByAddingObject:aspect]; break;
    }
}

#define P(roperty) NSStringFromSelector(@selector(roperty))
- (BOOL)removeAspect:(id)aspect {
    for (NSString *arrayName in @[P(beforeAspects), P(insteadAspects), P(afterAspects)]) {
        NSArray *array = [self valueForKey:arrayName];
        NSUInteger index = [array indexOfObjectIdenticalTo:aspect];
        if (array && index != NSNotFound) {
            NSMutableArray *newArray = [NSMutableArray arrayWithArray:array];
            [newArray removeObjectAtIndex:index];
            [self setValue:newArray forKey:arrayName];
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
#pragma mark - AspectInfo

@implementation AspectInfo

@synthesize arguments = _arguments;

- (id)initWithInstance:(__unsafe_unretained id)instance invocation:(NSInvocation *)invocation {
    NSCParameterAssert(instance);
    NSCParameterAssert(invocation);
    if (self = [super init]) {
        _instance = instance;
        _originalInvocation = invocation;
    }
    return self;
}

- (NSArray *)arguments {
    if (!_arguments) {
        // Lazily evaluate arguments, boxing is expensive.
        _arguments = self.originalInvocation.aspects_arguments;
    }
    return _arguments;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p, instance:%@, invocation:%@>", self.class, self, self.instance, self.originalInvocation];
}

@end
