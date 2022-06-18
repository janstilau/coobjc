#import "COActorChan.h"

@interface COActorChan ()
{
    unsigned long enum_state;
}

@property(nonatomic, strong) COActorMessage *lastMessage;

@end

@implementation COActorChan

// 唯一和 COChan 的区别, 就是实现了 Next 方法, 可以使用迭代这个概念了.
- (COActorMessage *)next {
    id obj = [self receive];
    if (![obj isKindOfClass:[COActorMessage class]]) {
        self.lastMessage = nil;
        return nil;
    }
    self.lastMessage = obj;
    return obj;
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
                                  objects:(id __unsafe_unretained _Nullable [_Nonnull])buffer
                                    count:(NSUInteger)len {
    
    if (state->state == 0) {
        state->mutationsPtr = &enum_state;
        state->state = enum_state;
    }
    
    NSUInteger count = 0;
    state->itemsPtr = buffer;
    COActorMessage *message = [self next];
    if (message) {
        buffer[0] = message;
        count++;
    }
    
    return count;
}

@end
