#import <Foundation/Foundation.h>


#ifdef __cplusplus
extern "C" {
#endif //__cplusplus

/**
 If you want to use @autorelease{} in a coroutine, and
 suspend in the scope. Enable this.
 
 @discussion Since a coroutine's calling stack may suspend.
 If you suspend in the @autorelease{} scope, autorelease pool
 may drop by the current runloop, then cause a crash.
 
 So we hook `autoreleasePoolPush` `autoreleasePoolPop`
 `autorelease` try to fix this. If you want suspend in a
 @autorelease{} scope, you may call `co_autoreleaseInit`.
 */
extern BOOL co_enableAutorelease;
extern void co_autoreleaseInit(void);

extern void * co_autoreleasePoolPush(void);
extern void co_autoreleasePoolPop(void *ctxt);

extern void co_autoreleasePoolPrint(void);

extern id co_autoreleaseObj(id obj);

extern void co_autoreleasePoolDealloc(void *p);

#ifdef __cplusplus
}
#endif //__cplusplus

