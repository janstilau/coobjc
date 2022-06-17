#import "COPromise.h"
#import "COChan.h"
#import "COCoroutine.h"
#import "co_queue.h"
#import "COLock.h"

// Promise 的状态值, 是固定的几个值. 在各方实现上都是一致的.
// 只能是从 Pending 都 Fulfilled, 从 Pending 到 Rejected.
typedef NS_ENUM(NSInteger, COPromiseState) {
    COPromiseStatePending = 0,
    COPromiseStateFulfilled,
    COPromiseStateRejected,
};

NSString *const COPromiseErrorDomain = @"COPromiseErrorDomain";

// 定义一个专门的值, 来当做 Error 中 cancle 的标识, 这是一个非常通用的做法.
enum {
    COPromiseCancelledError = -2341,
};

/*
    存储所有的回调, 到 Promise 的内部.
    当, 添加新的回调的时候, 如果状态已经 Resolved 了, 那么直接调用对应的回调. 如果还没有, 那么就是存储, 然后在 resolved 的时候, 调用所有存储的回调.
 */
typedef void (^COPromiseObserver)(COPromiseState state, id __nullable resolution);

@interface COPromise<Value>()
{
    COPromiseState _state;
    // 把所有的, 回调存储起来.
    NSMutableArray<COPromiseObserver> *_observers;
    // 如果在 Swfit 里面, 这就是一个 Result 类型的值.
    // 但是在 OC 里面, 就需要两个值来进行存储.
    id __nullable _value;
    NSError *__nullable _error;
@protected
    // 所有的, 对于内部状态的修改, 都应该在锁的环境下进行.
    dispatch_semaphore_t    _lock;
}

typedef void (^COPromiseOnFulfillBlock)(Value __nullable value);
typedef void (^COPromiseOnRejectBlock)(NSError *error);
typedef id __nullable (^__nullable COPromiseChainedFulfillBlock)(Value __nullable value);
typedef id __nullable (^__nullable COPromiseChainedRejectBlock)(NSError *error);

@end

@implementation COPromise

- (instancetype)init
{
    self = [super init];
    if (self) {
        COOBJC_LOCK_INIT(_lock);
        // LOCK = dispatch_semaphore_create(1)
        // 使用, 信号量来当做锁的实现.
    }
    return self;
}

// typedef void (^COPromiseConstructor)(COPromiseFulfill fullfill, COPromiseReject reject);
- (instancetype)initWithContructor:(COPromiseConstructor)constructor dispatch:(CODispatch*)dispatch {
    self = [self init];
    if (self) {
        if (constructor) {
            /*
             和 Promise 的设计是一样的, 将改变内部状态的函数进行封装, 然后传递出去.
             constructor 其实就是触发异步函数的地方, 在异步函数的回调里面, 调用 fulfill, reject 来真正的进行数据的改变.
             然后 Promise 的数据改变, 会触发后续的操作.
             */
            // 在类的内部, 只有这里调用了 fulfill 和 reject 方法.
            // 在类的外部, 这两个方法可以大量的使用.
            COPromiseFulfill fulfill = ^(id value){
                [self fulfill:value];
            };
            COPromiseReject reject = ^(NSError *error){
                [self reject:error];
            };
            if (dispatch) {
                [dispatch dispatch_block:^{
                    constructor(fulfill, reject);
                }];
            } else {
                constructor(fulfill, reject);
            }
        }
    }
    return self;
}

+ (instancetype)promise {
    return [[self alloc] init];
}

+ (instancetype)promise:(COPromiseConstructor)constructor {
    return [[self alloc] initWithContructor:constructor dispatch:[CODispatch currentDispatch]];
}

+ (instancetype)promise:(COPromiseConstructor)constructor onQueue:(dispatch_queue_t)queue {
    return [[self alloc] initWithContructor:constructor dispatch:[CODispatch dispatchWithQueue:queue]];
}
/*
#define COOBJC_LOCK(LOCK)               dispatch_semaphore_wait(LOCK, DISPATCH_TIME_FOREVER)
#define COOBJC_UNLOCK(LOCK)             dispatch_semaphore_signal(LOCK)
 */
/*
 #define COOBJC_SCOPELOCK(LOCK)          COOBJC_LOCK(LOCK); \
 COOBJC_LOCK_TYPE COOBJC_CONCAT(auto_lock_, __LINE__) __attribute__((cleanup(COOBJC_unlock), unused)) = LOCK
 
 COOBJC_SCOPELOCK 中, 定义了一个可以自动放开锁的东西.
 使用 C 语言独特的写法, 实现了 Defer 的效果.
 */

// 所有的, 对于状态值的读取和修改, 都伴随着锁的设计.
// 虽然, 这是一个协程的环境, 但是涉及到多线程, 改加锁还是应该进行加锁.
- (BOOL)isPending {
    COOBJC_SCOPELOCK(_lock);
    BOOL isPending = _state == COPromiseStatePending;
    return isPending;
}

- (BOOL)isFulfilled {
    COOBJC_SCOPELOCK(_lock);
    BOOL isFulfilled = _state == COPromiseStateFulfilled;
    return isFulfilled;
}

- (BOOL)isRejected {
    COOBJC_SCOPELOCK(_lock);
    BOOL isRejected = _state == COPromiseStateRejected;
    return isRejected;
}

// Value, 是 Success 的情况下, 才应该获取到的值.
- (nullable id)value {
    COOBJC_SCOPELOCK(_lock);
    id result = _value;
    return result;
}

- (NSError *__nullable)error {
    COOBJC_SCOPELOCK(_lock);
    NSError *error = _error;
    return error;
}

- (void)fulfill:(id)value {
    // 在多线程的环境下, 在锁内进行复制, 在锁外进行对应的使用, 是一个非常常用的写法.
    // 这样的写法, 使得临界区会大大的减小.
    NSArray<COPromiseObserver> * observers = nil;
    COPromiseState state;
    
    // do while 的这种写法, 仅仅是为了包住代码块而已, 为了逻辑更加的清晰.
    do {
        COOBJC_SCOPELOCK(_lock);
        // 必须, 是在 Pending 下, 调用 FullFill 才可以.
        if (_state == COPromiseStatePending) {
            _state = COPromiseStateFulfilled;
            state = _state;
            _value = value;
            observers = [_observers copy];
            _observers = nil;
        } else{
            return;
        }
    } while(0);
    
    // 在临界区外, 进行各种回调的触发.
    if (observers.count > 0) {
        for (COPromiseObserver observer in observers) {
            observer(state, value);
        }
    }
}

- (void)reject:(NSError *)error {
    NSAssert([error isKindOfClass:[NSError class]], @"Invalid error type.");
    NSArray<COPromiseObserver> * observers = nil;
    COPromiseState state;
    
    do {
        COOBJC_SCOPELOCK(_lock);
        if (_state == COPromiseStatePending) {
            _state = COPromiseStateRejected;
            state = _state;
            _error = error;
            observers = [_observers copy];
            _observers = nil;
        }
        else{
            return;
        }
        
    } while(0);
    
    for (COPromiseObserver observer in observers) {
        // 失败的场景, 就是传入的是 Error.
        observer(state, error);
    }
}

+ (BOOL)isPromiseCancelled:(NSError *)error {
    // 使用, COPromiseErrorDomain 这个特殊的字符, 来保证, Error 是 Promise 相关的 Error.
    // 使用 COPromiseCancelledError 这个特殊的 Int, 来确保, Error 是 cancel 类型的.
    if ([error.domain isEqualToString:COPromiseErrorDomain] &&
        error.code == COPromiseCancelledError) {
        return YES;
    } else {
        return NO;
    }
}

// Cancel, 就是使用特殊的 Error 来完成 Resolve.
- (void)cancel {
    NSError *cancelError = [NSError errorWithDomain:COPromiseErrorDomain code:COPromiseCancelledError userInfo:@{NSLocalizedDescriptionKey: @"Promise was cancelled."}];
    [self reject:cancelError];
}

// 这种, 使用 on 开头的注册回调的方式, 是非常非常普遍的.
- (void)onCancel:(COPromiseOnCancelBlock)onCancelBlock {
    if (onCancelBlock) {
        __weak typeof(self) weakSelf = self;
        // catch 是给 所有的 Error 加回调, 如果是 cancle 的, 那么就调用
        [self catch:^(NSError * _Nonnull error) {
            if ([COPromise isPromiseCancelled:error]) {
                onCancelBlock(weakSelf);
            }
        }];
    }
}

#pragma mark - then

// 给当前的 Promise 来添加回调的过程.
- (void)observeWithFulfill:(COPromiseOnFulfillBlock)onFulfill reject:(COPromiseOnRejectBlock)onReject {
    if (!onFulfill && !onReject) {
        return;
    }
    COPromiseState state = COPromiseStatePending;
    id value = nil;
    NSError *error = nil;
    
    do {
        COOBJC_SCOPELOCK(_lock);
        switch (_state) {
                // 如果, 当前的状态时 Pending, 那么就是存储各种闭包.
            case COPromiseStatePending: {
                if (!_observers) {
                    _observers = [[NSMutableArray alloc] init];
                }
                [_observers addObject:^(COPromiseState state, id __nullable resolution) {
                    switch (state) {
                        case COPromiseStatePending:
                            break;
                        case COPromiseStateFulfilled:
                            if (onFulfill) {
                                onFulfill(resolution);
                            }
                            break;
                        case COPromiseStateRejected:
                            if (onReject) {
                                onReject(resolution);
                            }
                            break;
                    }
                }];
                break;
            }
            case COPromiseStateFulfilled: {
                state = COPromiseStateFulfilled;
                value = _value;
                break;
            }
            case COPromiseStateRejected: {
                state = COPromiseStateRejected;
                error = _error;
                break;
            }
            default:
                break;
        }
    } while (0);
    
    // 如果, 当前的状态时 Resolved 的了, 那么就是调用传递过来的闭包. 
    if (state == COPromiseStateFulfilled) {
        if (onFulfill) {
            onFulfill(value);
        }
    } else if(state == COPromiseStateRejected){
        if (onReject) {
            onReject(error);
        }
    }
}

- (COPromise *)chainedPromiseWithFulfill:(COPromiseChainedFulfillBlock)chainedFulfill
                           chainedReject:(COPromiseChainedRejectBlock)chainedReject {
    
    COPromise *promise = [COPromise promise];
    // 原来在 OC 里面, 也是有 auto 这样的一个东西存在的.
    __auto_type resolver = ^(id __nullable value, BOOL isReject) {
        if ([value isKindOfClass:[COPromise class]]) {
            // 如果, 闭包生成了一个新的闭包, 那么这个新的闭包的状态, 来决定返回 Promise 的状态.
            [(COPromise *)value observeWithFulfill:^(id  _Nullable value) {
                [promise fulfill:value];
            } reject:^(NSError *error) {
                [promise reject:error];
            }];
        } else {
            // 否则, 就是使用 Result 的状态, 来决定返回 Promise 的状态.
            if (isReject) {
                [promise reject:value];
            } else {
                [promise fulfill:value];
            }
        }
    };
    
    /*
     chainedPromiseWithFulfill 的触发点, 是 then, 和 catch.
     所以, 这两个参数, 是一个可能有, 一个可能没有的.
     当 Promise 的 Result 确定了, 如果有对应情况的处理, 那么使用传递过来的闭包来获取结果, 否则, 就是继续传递.
     这里的处理逻辑, 和 JS 中是一致的.
     */
    [self observeWithFulfill:^(id  _Nullable value) {
        value = chainedFulfill ? chainedFulfill(value) : value;
        resolver(value, NO);
    } reject:^(NSError *error) {
        // 如果, chainedReject 把一个 Error 又变为了一个 Promise, 那这其实是一个 catch error resume 的操作.
        id value = chainedReject ? chainedReject(error) : error;
        resolver(value, YES);
    }];
    
    return promise;
}

- (COPromise *)then:(COPromiseThenWorkBlock)work {
    return [self chainedPromiseWithFulfill:work chainedReject:nil];
}

- (COPromise *)catch:(COPromiseCatchWorkBlock)reject {
    return [self chainedPromiseWithFulfill:nil chainedReject:^id _Nullable(NSError *error) {
        if (reject) {
            reject(error);
        }
        // 还要继续传递给后方的节点.
        return error;
    }];
}

@end

@interface COProgressValue : NSObject

@property (nonatomic, assign) float progress;

@end

@implementation COProgressValue

- (void)dealloc{
    NSLog(@"test");
}

@end

@interface COProgressPromise (){
    unsigned long enum_state;
}

@property (nonatomic, strong) NSProgress *progress;
@property (nonatomic, strong) COChan *progressChannel;
@property (nonatomic, strong) id lastValue;

@end

static void *COProgressObserverContext = &COProgressObserverContext;

@implementation COProgressPromise

- (instancetype)init{
    self = [super init];
    if (self) {
        _progressChannel = [COChan chanWithBuffCount:1];
    }
    return self;
}

- (void)fulfill:(id)value{
    [self.progressChannel send_nonblock:nil];
    [super fulfill:value];
}

- (void)reject:(NSError *)error{
    [self.progressChannel send_nonblock:nil];
    [super reject:error];
}

- (COProgressValue*)_nextProgressValue{
    if (![self isPending]) {
        return nil;
    }
    COProgressValue *result = [self.progressChannel receive];
    return result;
}

- (void)setupWithProgress:(NSProgress*)progress{
    NSProgress *oldProgress = nil;
    do {
        COOBJC_SCOPELOCK(_lock);
        if (self.progress) {
            oldProgress = self.progress;
        }
        self.progress = progress;
    } while (0);
    
    if (oldProgress) {
        [oldProgress removeObserver:self
                         forKeyPath:NSStringFromSelector(@selector(fractionCompleted))
                            context:COProgressObserverContext];
    }
    if (progress) {
        [progress addObserver:self
                   forKeyPath:NSStringFromSelector(@selector(fractionCompleted))
                      options:NSKeyValueObservingOptionInitial
                      context:COProgressObserverContext];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                        change:(NSDictionary *)change context:(void *)context
{
    if (context == COProgressObserverContext)
    {
        NSProgress *progress = object;
        COProgressValue *value = [[COProgressValue alloc] init];
        value.progress = progress.fractionCompleted;
        [self.progressChannel send_nonblock:value];
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object
                               change:change context:context];
    }
}

- (float)next {
    COProgressValue *value = [self _nextProgressValue];
    return value.progress;
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id __unsafe_unretained _Nullable [_Nonnull])buffer count:(NSUInteger)len {
    
    if (state->state == 0) {
        state->mutationsPtr = &enum_state;
        state->state = enum_state;
    }
    
    NSUInteger count = 0;
    state->itemsPtr = buffer;
    COProgressValue* value= [self _nextProgressValue];
    if (value) {
        self.lastValue = @(value.progress);
        buffer[0] = self.lastValue;
        count++;
    }
    
    return count;
}

- (void)dealloc{
    
    if (_progress) {
        [_progress removeObserver:self
                       forKeyPath:NSStringFromSelector(@selector(fractionCompleted))
                          context:COProgressObserverContext];
    }
}

@end
