#import <Foundation/Foundation.h>
#import <coobjc/COCoroutine.h>
#import <coobjc/COActorMessage.h>
#import <coobjc/COActorChan.h>
#import <coobjc/COActorCompletable.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^COActorExecutor)(COActorChan *);

/**
 This is implementation of Actor model
 */
@interface COActor : COCoroutine

/**
 The block of actor.
 */
@property(nonatomic, copy) COActorExecutor exector;

/**
 The channel of the actor
 */
@property(nonatomic, readonly) COActorChan *messageChan;


/**
 Send a message to the Actor.
 
 @param message any oc object
 @return An awaitable Channel.
 */
- (COActorCompletable *)sendMessage:(id)message;


/**
 Actor create method
 
 @param block execute code block
 @param queue the dispatch_queue_t this actor run.
 @return The actor instance.
 */
+ (instancetype)actorWithBlock:(COActorExecutor)block onQueue:(dispatch_queue_t _Nullable)queue;

@end

NS_ASSUME_NONNULL_END
