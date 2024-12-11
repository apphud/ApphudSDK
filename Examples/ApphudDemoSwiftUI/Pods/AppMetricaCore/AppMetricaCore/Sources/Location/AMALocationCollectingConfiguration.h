
#import <Foundation/Foundation.h>

@class AMAMetricaConfiguration;

@interface AMALocationCollectingConfiguration : NSObject

@property (nonatomic, assign, readonly) BOOL collectingEnabled;
@property (nonatomic, assign, readonly) BOOL visitsCollectingEnabled;
@property (nonatomic, copy, readonly) NSArray *hosts;
@property (nonatomic, assign, readonly) NSTimeInterval minUpdateInterval;
@property (nonatomic, assign, readonly) double minUpdateDistance;
@property (nonatomic, assign, readonly) NSUInteger recordsCountToForceFlush;
@property (nonatomic, assign, readonly) NSUInteger maxRecordsCountInBatch;
@property (nonatomic, assign, readonly) NSTimeInterval maxAgeToForceFlush;
@property (nonatomic, assign, readonly) NSUInteger maxRecordsToStoreLocally;
@property (nonatomic, assign, readonly) double defaultDesiredAccuracy;
@property (nonatomic, assign, readonly) double defaultDistanceFilter;
@property (nonatomic, assign, readonly) double accurateDesiredAccuracy;
@property (nonatomic, assign, readonly) double accurateDistanceFilter;
@property (nonatomic, assign, readonly) BOOL pausesLocationUpdatesAutomatically;

- (instancetype)initWithMetricaConfiguration:(AMAMetricaConfiguration *)metricaConfiguration;

@end
