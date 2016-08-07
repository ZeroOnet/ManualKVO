//
//  NSObject+ManualKVO.m
//  手动实现KVO
//
//  Created by FunctionMaker on 16/8/5.
//  Copyright © 2016年 FunctionMaker. All rights reserved.
//

#import "NSObject+ManualKVO.h"
#include <objc/runtime.h>
#include <objc/message.h>

static NSString *const kClassPrefix_KVO = @"Observer_";
static NSString *const KAssiociateObserver_KVO = @"AssiociateObserver";

@interface TestObserverInfo : NSObject

@property (nonatomic, weak) NSObject *observer;
@property (nonatomic, copy) NSString *key;
@property (nonatomic, copy) observeHandler handler;

@end

@implementation TestObserverInfo

- (instancetype)initWithObserver:(NSObject *)observer forKey:(NSString *)key observeHandle:(observeHandler)handler {
    self = [super init];
    if (self) {
        _observer = observer;
        _key = key;
        _handler = handler;
    }
    
    return self;
}

@end

@implementation NSObject (ManualKVO)

- (void)addManualObserver:(NSObject *)observer forkey:(NSString *)key withBlock:(observeHandler)observedHandler {
    
    // 1.获取被观察的属性的setter方法，如果没有则抛出异常，故此Demo只适用于观察属性，而系统的KVO可以观察私有的成员变量
    SEL setterSelector = NSSelectorFromString(getSetter(key));
    
    //self 表示被观察的对象
    Method setterMethod = class_getInstanceMethod([self class], setterSelector);
    if (!setterMethod) {
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat: @"unrecognized selector sent to instance %@", self] userInfo:nil];
        return;
    }
    
    // 2.在对象原本的类名前缀Observer_，表示派生(fork)出的子类，并将当前对象所属的类设置为派生的子类，即对象的isa指针指向这个派生的类
    Class observedClass = object_getClass(self);
    NSString *className = NSStringFromClass(observedClass);
    if (![className hasPrefix:kClassPrefix_KVO]) {
        observedClass = [self createKVOClassWithOriginalClassName:className];
        object_setClass(self, observedClass);
    }
    
    //从新类(或者父类)方法分发表中查找是否有被监听属性的setter方法的实现，没有则添加。IMP是implementation的缩写，它是OC方法实现代码块的地址，类似函数指针，通过它可以访问任意一个方法，并且可以免去发送消息的代价
    if (![self hasSelector:setterSelector]) {
        const char *types = method_getTypeEncoding(setterMethod);
        class_addMethod(observedClass, setterSelector, (IMP)KVO_Setter, types);
    }
    
    //获取当前对象的观察者
    NSMutableArray *observers = objc_getAssociatedObject(self, (__bridge void *)KAssiociateObserver_KVO);
    if (!observers) {
        //观察者对象用于保存观察者的信息
        TestObserverInfo *newInfo = [[TestObserverInfo alloc] initWithObserver:observer forKey:key observeHandle:observedHandler];
        observers = [NSMutableArray array];
        objc_setAssociatedObject(self, (__bridge void *)KAssiociateObserver_KVO, observers, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [observers addObject:newInfo];
    }
}

- (void)removeManualObserver:(NSObject *)object forKey:(NSString *)key {
    NSMutableArray *observers = objc_getAssociatedObject(self, (__bridge void *)KAssiociateObserver_KVO);
    
    TestObserverInfo *observerRemoved = nil;
    for (TestObserverInfo *observerInfo in observers) {
        if (observerInfo.observer == object && [observerInfo.key isEqualToString:key]) {
            observerRemoved = observerInfo;
            break;
        }
    }
    
    [observers removeObject:observerRemoved];
}

static NSString * getSetter(NSString *key) {
    if (key.length <= 0) {
        return nil;
    } else {
        NSString *firstChar = [[key substringToIndex:1] uppercaseString];
        NSString *leaveString = [key substringFromIndex:1];
        
        return [NSString stringWithFormat:@"set%@%@:", firstChar, leaveString];
    }
}

- (Class)createKVOClassWithOriginalClassName:(NSString *)originalClassName {
    NSString *KVOClassName = [kClassPrefix_KVO stringByAppendingString:originalClassName];
    Class observedClass = NSClassFromString(KVOClassName);
    
    //创建新类前，先判断此类是否已经存在
    if (observedClass) {
        return observedClass;
    }
    
    Class originalClass = object_getClass(self);
    
    //创建新类的步骤1：为新派生出的子类分配存储空间
    Class KVOClass = objc_allocateClassPair(originalClass, KVOClassName.UTF8String, 0);
    
    //获取监听对象的class方法的实现，并替换为新类的class实现
    Method classMethod = class_getInstanceMethod(originalClass, @selector(class));
    const char *types = method_getTypeEncoding(classMethod);
    
    //步骤2：为新类增加方法用class_addMethod，为新类增加变量用class_addIvar
    class_addMethod(KVOClass, @selector(class), (IMP)KVO_Class, types);
    
    //步骤3：注册这个新类，以便外界发现使用
    objc_registerClassPair(KVOClass);
    
    return KVOClass;
}

static Class KVO_Class(id self) {
    return class_getSuperclass(object_getClass(self));
}

static void KVO_Setter(id self, SEL _cmd, id newValue) {
    NSString *setterName = NSStringFromSelector(_cmd);
    NSString *getterName = getterForSetter(setterName);
    if (!getterName) {
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"unrecognized selector sent to instance %p", self] userInfo:nil];
        return;
    }
    
    id oldValue = [self valueForKey:getterName];
    struct objc_super superClass = {
        .receiver = self,
        .super_class = class_getSuperclass(object_getClass(self))
    };
    
    //KVO核心部分，在改变值前后回调被观察对象的willChangeValueForKey:和didChangeValueForKey:方法
    [self willChangeValueForKey:getterName];
    
    //通过父类的setter方法设置新的值
    void (*objc_msgSendSuperKVO)(void *, SEL, id) = (void *)objc_msgSendSuper;
    objc_msgSendSuperKVO(&superClass, _cmd, newValue);
    [self didChangeValueForKey:getterName];
    
    NSMutableArray *observers = objc_getAssociatedObject(self, (__bridge void *)KAssiociateObserver_KVO);
    for (TestObserverInfo *info in observers) {
        if ([info.key isEqualToString:getterName]) {
            //异步回调handler
            dispatch_async(dispatch_queue_create(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                info.handler(self, getterName, oldValue, newValue);
            });
        }
    }
}

- (BOOL)hasSelector:(SEL)selector {
    Class observedClass = object_getClass(self);
    unsigned int methodCount = 0;
    Method *methodList = class_copyMethodList(observedClass, &methodCount);
    for (int i = 0; i < methodCount; i++) {
        SEL thisSelector = method_getName(methodList[i]);
        if (thisSelector == selector) {
            free(methodList);
            
            return YES;
        }
    }
    
    free(methodList);
    
    return NO;
}

//从setter方法名中获取getter方法名
static NSString * getterForSetter(NSString *setter) {
    if (setter.length <= 0 || ![setter hasPrefix:@"set"] || ![setter hasSuffix:@":"]) {
        return nil;
    }
    
    NSRange range = NSMakeRange(3, setter.length - 4);
    NSString *getter = [setter substringWithRange:range];
    NSString *firstString = [[getter substringToIndex:1] lowercaseString];
    getter = [getter stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:firstString];
    
    return getter;
}

@end
