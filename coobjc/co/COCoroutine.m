#import "COCoroutine.h"
#import "COChan.h"
#import "coroutine.h"
#import "co_queue.h"
#import "coobjc.h"

NSString *const COInvalidException = @"COInvalidException";

@interface COCoroutine ()

@property(nonatomic, assign) BOOL isFinished;
@property(nonatomic, assign) BOOL isCancelled;
@property(nonatomic, assign) BOOL isResume;
@property(nonatomic, strong) NSMutableDictionary *parameters;
@property(nonatomic, copy, nullable) dispatch_block_t joinBlock;
@property(nonatomic, strong) NSMutableArray *subroutines;
@property(nonatomic, weak) COCoroutine *parent;

- (void)execute;

- (void)setParam:(id _Nullable )value forKey:(NSString *_Nonnull)key;
- (id _Nullable )paramForKey:(NSString *_Nonnull)key;

- (void)removeChild:(COCoroutine *)child;
- (void)addChild:(COCoroutine *)child;

@end

/*
 就和 Thread 如何和 pthread 挂钩上一样.
 其实就是 pthread 后去到 coroutine_t, 然后找到对应的 userdata, 那么可以看到, 这个 user data, 其实就是一个 COCoroutine 对象了.
 */
COCoroutine *co_get_obj(coroutine_t  *co) {
    if (co == nil) {
        return nil;
    }
    id obj = (__bridge id)coroutine_getuserdata(co);
    if ([obj isKindOfClass:[COCoroutine class]]) {
        return obj;
    }
    return nil;
}

NSError *co_getError() {
    // 找到当前的 CORoutine 对象, 找到最后一个 Error 对象. 
    return [COCoroutine currentCoroutine].lastError;
}


BOOL co_setspecific(NSString *key, id _Nullable value) {
    COCoroutine *co = [COCoroutine currentCoroutine];
    if (!co) {
        return NO;
    }
    [co setParam:value forKey:key];
    return YES;
}

id _Nullable co_getspecific(NSString *key) {
    COCoroutine *co = [COCoroutine currentCoroutine];
    if (!co) {
        return nil;
    }
    return [co paramForKey:key];
}

// 开启一个协程的入口函数, 可以理解成为 pthread start 函数.
static void co_exec(coroutine_t  *co) {
    
    COCoroutine *coObj = co_get_obj(co);
    if (coObj) {
        [coObj execute];
        
        // 当 execute 结束了之后, 这个协程的状态也就完毕了.
        coObj.isFinished = YES;
        if (coObj.finishedBlock) {
            coObj.finishedBlock();
            coObj.finishedBlock = nil;
        }
        if (coObj.joinBlock) {
            coObj.joinBlock();
            coObj.joinBlock = nil;
        }
        [coObj.parent removeChild:coObj];
    }
}

static void co_obj_dispose(void *coObj) {
    COCoroutine *obj = (__bridge_transfer id)coObj;
    if (obj) {
        obj.co = nil;
    }
}

@implementation COCoroutine


- (void)execute {
    if (self.mainTask) {
        self.mainTask();
    }
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _parameters = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)setParam:(id)value forKey:(NSString *)key {
    [_parameters setValue:value forKey:key];
}

- (id)paramForKey:(NSString *)key {
    return [_parameters valueForKey:key];
}

+ (COCoroutine *)currentCoroutine {
    return co_get_obj(coroutine_self());
}

+ (BOOL)isActive {
    coroutine_t  *co = coroutine_self();
    if (co) {
        if (co->is_cancelled) {
            return NO;
        } else {
            return YES;
        }
    } else {
        @throw [NSException exceptionWithName:COInvalidException reason:@"isActive must called in a routine" userInfo:@{}];
    }
}

- (instancetype)initWithBlock:(void (^)(void))block onQueue:(dispatch_queue_t)queue stackSize:(NSUInteger)stackSize {
    self = [super init];
    if (self) {
        _mainTask = [block copy];
        _dispatch = queue ? [CODispatch dispatchWithQueue:queue] : [CODispatch currentDispatch];
        
        // 在这里, 设置了 协程的启动函数. 
        coroutine_t  *co = coroutine_create((void (*)(void *))co_exec);
        if (stackSize > 0 && stackSize < 1024*1024) {   // Max 1M
            co->stack_size = (uint32_t)((stackSize % 16384 > 0) ? ((stackSize/16384 + 1) * 16384) : stackSize);        // Align with 16kb
        }
        _co = co;
        coroutine_setuserdata(co, (__bridge_retained void *)self, co_obj_dispose);
    }
    return self;
}

+ (instancetype)coroutineWithBlock:(void (^)(void))block onQueue:(dispatch_queue_t)queue {
    
    return [self coroutineWithBlock:block onQueue:queue stackSize:0];
}

+ (instancetype)coroutineWithBlock:(void(^)(void))block onQueue:(dispatch_queue_t)queue stackSize:(NSUInteger)stackSize {
    return [[[self class] alloc] initWithBlock:block onQueue:queue stackSize:stackSize];
}

- (void)performBlockOnQueue:(dispatch_block_t)block {
    [self.dispatch dispatch_block:block];
}

- (void)_internalCancel {
    // dead
    if (_co == nil) {
        return;
    }
    
    if (_isCancelled) {
        return;
    }
    NSArray *subroutines = self.subroutines.copy;
    // 将, cancel 的状态, 向下传递了过去. 
    if (subroutines.count) {
        for (COCoroutine *subco in subroutines) {
            [subco cancel];
        }
    }
    
    _isCancelled = YES;
    
    coroutine_t *co = self.co;
    if (co) {
        co->is_cancelled = YES;
    }
    
    COChan *chan = self.currentChan;
    if (chan) {
        [chan cancelForCoroutine:self];
    }
}

- (void)cancel {
    [self performBlockOnQueue:^{
        [self _internalCancel];
    }];
}

- (void)addChild:(COCoroutine *)child {
    [self.subroutines addObject:child];
}

- (void)removeChild:(COCoroutine *)child {
    [self.subroutines removeObject:child];
}

- (COCoroutine *)resume {
    COCoroutine *currentCo = [COCoroutine currentCoroutine];
    BOOL isSubroutine = [currentCo.dispatch isEqualToDipatch:self.dispatch] ? YES : NO;
    [self.dispatch dispatch_async_block:^{
        if (self.isResume) {
            return;
        }
        if (isSubroutine) {
            self.parent = currentCo;
            [currentCo addChild:self];
        }
        self.isResume = YES;
        coroutine_resume(self.co);
    }];
    return self;
}

- (void)resumeNow {
    COCoroutine *currentCo = [COCoroutine currentCoroutine];
    BOOL isSubroutine = [currentCo.dispatch isEqualToDipatch:self.dispatch] ? YES : NO;
    [self performBlockOnQueue:^{
        if (self.isResume) {
            return;
        }
        if (isSubroutine) {
            self.parent = currentCo;
            [currentCo addChild:self];
        }
        self.isResume = YES;
        coroutine_resume(self.co);
    }];
}

- (void)addToScheduler {
    [self performBlockOnQueue:^{
        coroutine_add(self.co);
    }];
}

- (void)join {
    COChan *chan = [COChan chanWithBuffCount:1];
    [self performBlockOnQueue:^{
        if ([self isFinished]) {
            [chan send_nonblock:@(1)];
        }
        else{
            [self setJoinBlock:^{
                [chan send_nonblock:@(1)];
            }];
        }
    }];
    [chan receive];
}

- (void)cancelAndJoin {
    COChan *chan = [COChan chanWithBuffCount:1];
    [self performBlockOnQueue:^{
        if ([self isFinished]) {
            [chan send_nonblock:@(1)];
        }
        else{
            [self setJoinBlock:^{
                [chan send_nonblock:@(1)];
            }];
            [self _internalCancel];
        }
    }];
    [chan receive];
}

@end


id co_await(id awaitable) {
    coroutine_t  *t = coroutine_self();
    if (t == nil) {
        @throw [NSException exceptionWithName:COInvalidException reason:@"Cannot call co_await out of a coroutine" userInfo:nil];
    }
    
    if (t->is_cancelled) {
        return nil;
    }
    
    if ([awaitable isKindOfClass:[COChan class]]) {
        COCoroutine *co = co_get_obj(t);
        co.lastError = nil;
        id val = [(COChan *)awaitable receive];
        return val;
    } else if ([awaitable isKindOfClass:[COPromise class]]) {
        /*
         如果在 await 里面, 是一个 Promise, 那么是创建了一个 COChan 对象. 在 Promise 的回调里面, 增加了 send 的调用.
         而在配置完这一切之后, 是调用了 receive 来进行协程的暂停.
         所有的协程控制, 是放到了 COChan 之中了. 
         */
        COChan *chan = [COChan chanWithBuffCount:1];
        COCoroutine *currentCoroutine = co_get_obj(t);
        
        currentCoroutine.lastError = nil;
        
        // 当 Promise 的值确定了之后, 会触发 Channel 的 send .
        COPromise *promise = awaitable;
        [[promise
          then:^id _Nullable(id  _Nullable value) {
            [chan send_nonblock:value];
            return value;
        }]
         catch:^(NSError * _Nonnull error) {
            currentCoroutine.lastError = error;
            [chan send_nonblock:nil];
        }];
        
        // receiveWithOnCancel 中, 会出现协程的切换.
        // 这里, chan 会一直等待, 有新的值发生, 如果没有发生, 会发生协程的暂停. 
        id val = [chan receiveWithOnCancel:^(COChan * _Nonnull chan) {
            [promise cancel];
        }];
        return val;
        
    } else {
        @throw [NSException exceptionWithName:COInvalidException
                                       reason:[NSString stringWithFormat:@"Cannot await object: %@.", awaitable]
                                     userInfo:nil];
    }
}

NSArray *co_batch_await(NSArray * awaitableList) {
    
    coroutine_t  *t = coroutine_self();
    if (t == nil) {
        @throw [NSException exceptionWithName:COInvalidException
                                       reason:@"Cannot run co_batch_await out of a coroutine"
                                     userInfo:nil];
    }
    if (t->is_cancelled) {
        return nil;
    }
    
    uint32_t count = (uint32_t)awaitableList.count;
    
    if (count == 0) {
        return nil;
    }
    
    NSMutableArray *result = [[NSMutableArray alloc] initWithCapacity:count];
    
    COChan *chan = [COChan chanWithBuffCount:count];
    
    for (int i = 0; i < count; i++) {
        
        [result addObject:[NSNull null]];
        id awaitable = awaitableList[i];
        
        // start subroutines
        co_launch(^{
            
            id val = co_await(awaitable);
            if (!co_isCancelled()) {
                if (val) {
                    [result replaceObjectAtIndex:i withObject:val];
                } else {
                    NSError *error = co_getError();
                    if (error) {
                        [result replaceObjectAtIndex:i withObject:error];
                    }
                }
            }
            [chan send_nonblock:@(i)];
        });
    }
    
    [chan receiveWithCount:count];
    return result.copy;
}



