
#import <Foundation/Foundation.h>

@interface AMAExponentialBackoff : NSObject

@property (nonatomic, assign, readonly) BOOL maxRetryCountReached;

- (instancetype)initWithMaxRetryCount:(NSInteger)maxRetryCount;
- (NSInteger)next;
- (void)reset;

@end
