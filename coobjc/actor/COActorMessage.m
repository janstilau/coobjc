#import "COActorMessage.h"

extern NSError *co_getError(void);

@interface COActorMessage ()

@property(nonatomic, strong) COActorCompletable *completableObj;

@end

@implementation COActorMessage

- (instancetype)initWithType:(id)type
                 completable:(COActorCompletable *)completable {
    self = [super init];
    if (self) {
        _type = type;
        _completableObj = completable;
    }
    return self;
}

/*
 for (COActorMessage *message in channel) {
     NSString *url = [message stringType];
     if (url.length > 0) {
         message.complete(_await([self _getDataWithURL:url]));
     } else{
         message.complete(nil);
     }
 }
 外界是这样使用这个 API 的, 直接使用它的返回值, 进行函数调用.
 因为在 _wait 里面, 其实是有着协程控制的, 所以它的调用时机, 其实是在 _wait 之后, 能够确保异步函数调用结束了. 
 */

- (void (^)(id))complete {
    COActorCompletable *completable = _completableObj;
    return ^(id val){
        if (completable) {
            if (val) {
                [completable fulfill:val];
            } else{
                NSError *error = co_getError();
                if (error) {
                    [completable reject:error];
                } else{
                    [completable fulfill:val];
                }
            }
        }
    };
}

- (NSString*)stringType {
    if ([_type isKindOfClass:[NSString class]]) {
        return _type;
    }
    return [_type stringValue];
}

- (int)intType {
    return [_type intValue];
}

- (NSUInteger)uintType {
    return [_type unsignedIntegerValue];
}

- (double)doubleType {
    return [_type doubleValue];
}

- (float)floatType {
    return [_type floatValue];
}

- (NSDictionary*)dictType {
    if ([_type isKindOfClass:[NSMutableDictionary class]]) {
        return [_type copy];
    }
    else if([_type isKindOfClass:[NSDictionary class]]){
        return _type;
    }
    return nil;
}

- (NSArray*)arrayType {
    if ([_type isKindOfClass:[NSMutableArray class]]) {
        return [_type copy];
    }
    else if([_type isKindOfClass:[NSArray class]]){
        return _type;
    }
    return nil;
}
@end
