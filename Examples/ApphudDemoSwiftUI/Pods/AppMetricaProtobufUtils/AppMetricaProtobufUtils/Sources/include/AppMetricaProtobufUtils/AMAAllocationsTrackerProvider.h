
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol AMAAllocationsTracking;

NS_SWIFT_NAME(AllocationsTrackerProvider)
@interface AMAAllocationsTrackerProvider : NSObject

+ (void)track:(void (^)(id<AMAAllocationsTracking> tracker))block;
+ (id<AMAAllocationsTracking>)manuallyHandledTracker;

@end

NS_ASSUME_NONNULL_END
