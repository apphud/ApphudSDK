
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(EventFlushableDelegate)
@protocol AMAEventFlushableDelegate <NSObject>

+ (void)sendEventsBuffer;

@end

NS_ASSUME_NONNULL_END
