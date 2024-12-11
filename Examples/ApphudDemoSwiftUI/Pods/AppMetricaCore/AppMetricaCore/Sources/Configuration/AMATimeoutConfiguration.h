
#import <Foundation/Foundation.h>

@interface AMATimeoutConfiguration : NSObject

@property (nonatomic, strong) NSDate *limitDate;
@property (nonatomic, assign) NSUInteger count;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithLimitDate:(NSDate *)limitDate count:(NSUInteger)count;

@end
