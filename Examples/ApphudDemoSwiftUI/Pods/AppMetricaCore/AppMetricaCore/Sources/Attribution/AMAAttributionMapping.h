
#import <Foundation/Foundation.h>
#import "AMAEventTypes.h"
#import "AMAJSONSerializable.h"

@class AMAClientEventCondition;
@class AMAECommerceEventCondition;
@class AMARevenueEventCondition;
@class AMAEventFilter;

@interface AMAAttributionMapping : NSObject <AMAJSONSerializable>

@property (nonatomic, copy, readonly) NSArray<AMAEventFilter *> *eventFilters;
@property (nonatomic, assign, readonly) NSUInteger requiredCount;
@property (nonatomic, assign, readonly) NSInteger conversionValueDiff;

- (instancetype)initWithEventFilters:(NSArray<AMAEventFilter *> *)eventFilters
                       requiredCount:(NSUInteger)requiredCount
                 conversionValueDiff:(NSInteger)conversionValueDiff;

@end
