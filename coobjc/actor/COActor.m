#import "COActor.h"

@implementation COActor

@synthesize messageChan = _messageChan;

+ (instancetype)actorWithBlock:(COActorExecutor)block onQueue:(dispatch_queue_t _Nullable)queue {
    COActor *actor = [self coroutineWithBlock:^{ } onQueue:queue];
    [actor setExector:block];
    return actor;
}

- (COActorChan *)messageChan {
    if (!_messageChan) {
        _messageChan = [COActorChan expandableChan];
    }
    return _messageChan;
}

- (COActorCompletable *)sendMessage:(id)message {
    COActorCompletable *completable = [COActorCompletable promise];
    [self.dispatch dispatch_block:^{
        COActorMessage *actorMessage = [[COActorMessage alloc] initWithType:message completable:completable];
        [self.messageChan send_nonblock:actorMessage];
    }];
    return completable;
}

/*
 - (void)execute {
     if (self.mainTask) {
         self.mainTask();
     }
 }
 */
// 上面是 COCoroutine 的协程启动方法的使用, 在 COActor 里面, 替换掉了.
- (void)execute {
    if (_exector) {
        _exector(self.messageChan);
    }
}


@end
