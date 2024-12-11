
#import <Foundation/Foundation.h>
#import "AMAAttributionModelType.h"
#import "AMAJSONSerializable.h"

@protocol AMAKeyValueStoring;
@class AMAConversionAttributionModelConfiguration;
@class AMARevenueAttributionModelConfiguration;
@class AMAEngagementAttributionModelConfiguration;

@interface AMAAttributionModelConfiguration : NSObject <AMAJSONSerializable>

@property (nonatomic, assign, readonly) AMAAttributionModelType type;
@property (nonatomic, assign, readonly) NSNumber *maxSavedRevenueIDs;
@property (nonatomic, assign, readonly) NSNumber *stopSendingTimeSeconds;
@property (nonatomic, strong, readonly) AMAConversionAttributionModelConfiguration *conversion;
@property (nonatomic, strong, readonly) AMARevenueAttributionModelConfiguration *revenue;
@property (nonatomic, strong, readonly) AMAEngagementAttributionModelConfiguration *engagement;

- (instancetype)initWithType:(AMAAttributionModelType)type
          maxSavedRevenueIDs:(NSNumber *)maxSavedRevenueIDs
      stopSendingTimeSeconds:(NSNumber *)stopSendingTimeSeconds
                  conversion:(AMAConversionAttributionModelConfiguration *)conversion
                     revenue:(AMARevenueAttributionModelConfiguration *)revenue
                  engagement:(AMAEngagementAttributionModelConfiguration *)engagement;

@end
