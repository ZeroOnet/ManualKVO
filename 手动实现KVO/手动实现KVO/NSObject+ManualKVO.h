//
//  NSObject+ManualKVO.h
//  手动实现KVO
//
//  Created by FunctionMaker on 16/8/5.
//  Copyright © 2016年 FunctionMaker. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^observeHandler)(id observedObject, NSString *observedKey, id oldValue, id newValue);

@interface NSObject (ManualKVO)

- (void)addManualObserver:(NSObject *)observer forkey:(NSString *)key withBlock:(observeHandler)observedHandler;

- (void)removeManualObserver:(NSObject *)object forKey:(NSString *)key;
@end
