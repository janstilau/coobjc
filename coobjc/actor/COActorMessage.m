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

- (void (^)(id))complete {
    COActorCompletable *completable = _completableObj;
    return ^(id val){
        if (completable) {
            if (val) {
                [completable fulfill:val];
            }
            else{
                NSError *error = co_getError();
                if (error) {
                    [completable reject:error];
                }
                else{
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
