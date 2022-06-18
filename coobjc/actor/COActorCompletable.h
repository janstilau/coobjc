#import <Foundation/Foundation.h>
#import <coobjc/COPromise.h>

/*
 这其实就是一个 Promise, 单独定义一个类型, 让语义更加的明确. 
 */
@interface COActorCompletable : COPromise

@end
