
#import <Foundation/Foundation.h>

@interface AMASignal : NSObject

@property (nonatomic, assign, readonly) int32_t signal;
@property (nonatomic, assign, readonly) int32_t code;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithSignal:(int32_t)signal code:(int32_t)code;

@end
