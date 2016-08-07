//
//  TestObject.m
//  手动实现KVO
//
//  Created by FunctionMaker on 16/8/5.
//  Copyright © 2016年 FunctionMaker. All rights reserved.
//

#import "TestObject.h"

@implementation TestObject

- (void)willChangeValueForKey:(NSString *)key {
    NSLog(@"%@ value will changed", key);
}

- (void)didChangeValueForKey:(NSString *)key {
    NSLog(@"%@ value changed", key);
}

@end
