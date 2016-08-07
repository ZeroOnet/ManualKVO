//
//  ViewController.m
//  手动实现KVO
//
//  Created by FunctionMaker on 16/8/5.
//  Copyright © 2016年 FunctionMaker. All rights reserved.
//

#import "ViewController.h"
#import "TestObject.h"
#import "NSObject+ManualKVO.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    TestObject *testObj = [[TestObject alloc] init];
    testObj.observedNum = @11;
    [testObj addManualObserver:self forkey:@"observedNum" withBlock:^(id observedObject, NSString *observedKey, id oldValue, id newValue) {
        NSLog(@"observedObject: %@, observedKey: %@, oldValue: %@, newValue: %@", observedObject, observedKey, oldValue, newValue);
    }];
    
    testObj.observedNum = @13;//对NSNumber对象快速赋值
    
    NSLog(@"%zd", [testObj.observedNum integerValue]);
    
    [testObj removeManualObserver:self forKey:@"observedNum"];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
