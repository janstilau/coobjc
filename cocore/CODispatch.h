#import <Foundation/Foundation.h>

@interface CODispatchTimer : NSObject

@property (nonatomic, strong) dispatch_block_t _Nonnull block;

- (void)invalidate;

@end




NS_ASSUME_NONNULL_BEGIN

@interface CODispatch : NSObject

+ (instancetype)dispatchWithQueue:(dispatch_queue_t)q;

+ (instancetype)currentDispatch;

- (BOOL)isCurrentDispatch;

- (void)dispatch_block:(dispatch_block_t)block;

- (void)dispatch_async_block:(dispatch_block_t)block;


- (CODispatchTimer*)dispatch_timer:(dispatch_block_t)block
                          interval:(NSTimeInterval)interval;

- (BOOL)isEqualToDipatch:(CODispatch*)dispatch;

@end

NS_ASSUME_NONNULL_END
