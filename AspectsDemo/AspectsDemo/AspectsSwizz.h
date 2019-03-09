//
//  AspectsSwizz.h
//  AspectsDemo
//
//  Created by Justin.wang on 2018/3/19.
//  Copyright © 2018年 PSPDFKit GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

@interface AspectsSwizz : NSObject

+ (void)swizzingInstanceMethodByClass:(Class)cls
                       originSelector:(SEL)originSelector
                     swizzingSelector:(SEL)swizzingSelector;

+ (void)swizzingClassMethodByClass:(Class)cls
                    originSelector:(SEL)originSelector
                  swizzingSelector:(SEL)swizzingSelector;

@end
