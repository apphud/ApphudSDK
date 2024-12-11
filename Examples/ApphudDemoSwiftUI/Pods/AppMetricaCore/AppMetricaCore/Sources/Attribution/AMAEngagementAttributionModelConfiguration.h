
#import <Foundation/Foundation.h>
#import "AMAJSONSerializable.h"
#import "AMAAttributionModelType.h"

@class AMABoundMapping;
@class AMAClientEventCondition;
@class AMAECommerceEventCondition;
@class AMARevenueEventCondition;
@class AMAEventFilter;

@interface AMAEngagementAttributionModelConfiguration : NSObject <AMAJSONSerializable>

@property (nonatomic, copy, readonly) NSArray<AMABoundMapping *> *boundMappings;
@property (nonatomic, copy, readonly) NSArray<AMAEventFilter *> *eventFilters;

- (instancetype)initWithEventFilters:(NSArray<AMAEventFilter *> *)eventFilters
                       boundMappings:(NSArray<AMABoundMapping *> *)boundMappings;

@end
