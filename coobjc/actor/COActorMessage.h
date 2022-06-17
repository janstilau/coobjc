#import <Foundation/Foundation.h>
#import <coobjc/COActorCompletable.h>

NS_ASSUME_NONNULL_BEGIN

/**
 The message object send to COActor
 */
@interface COActorMessage : NSObject

/**
 Reply to sender with a return object.
 */
@property(nonatomic, copy) void (^complete)(id _Nullable result);

/**
 The value pass to message.
 */
@property(nonatomic, readonly, nullable) id type;


/**
 Create a actor message
 
 @param type the message content value
 @param completable the complete promise object.
 @return The actor message
 */
- (instancetype)initWithType:(id)type
                 completable:(COActorCompletable *)completable;


/**
 Trans value to string type.
 */
- (NSString * _Nullable)stringType;

/**
 Trans value to int type.
 */
- (int)intType;

/**
 Trans value to uint type.
 */
- (NSUInteger)uintType;

/**
 Trans value to double type.
 */
- (double)doubleType;

/**
 Trans value to float type.
 */
- (float)floatType;

/**
 Trans value to NSDictionary type.
 */
- (NSDictionary * _Nullable)dictType;

/**
 Trans value to NSArray type.
 */
- (NSArray * _Nullable)arrayType;

@end

NS_ASSUME_NONNULL_END
