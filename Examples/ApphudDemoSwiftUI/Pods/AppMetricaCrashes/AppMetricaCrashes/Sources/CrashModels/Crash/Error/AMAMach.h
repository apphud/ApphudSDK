
#import <Foundation/Foundation.h>

@interface AMAMach : NSObject

@property (nonatomic, assign, readonly) int32_t exceptionType;
@property (nonatomic, assign, readonly) int64_t code;
@property (nonatomic, assign, readonly) int64_t subcode;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithExceptionType:(int32_t)exceptionType code:(int64_t)code subcode:(int64_t)subcode;

@end
