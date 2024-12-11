
#import <Foundation/Foundation.h>
#import "AMARevenueSource.h"
#import "AMAJSONSerializable.h"

@class AMABoundMapping;
@class AMACurrencyMapping;
@class AMAEventFilter;

@interface AMARevenueAttributionModelConfiguration : NSObject <AMAJSONSerializable>

@property (nonatomic, copy, readonly) NSArray<AMABoundMapping *> *boundMappings;
@property (nonatomic, copy, readonly) NSArray<AMAEventFilter *> *events;
@property (nonatomic, strong, readonly) AMACurrencyMapping *currencyMapping;

- (instancetype)initWithBoundMappings:(NSArray<AMABoundMapping *> *)boundMappings
                               events:(NSArray<AMAEventFilter *> *)events
                      currencyMapping:(AMACurrencyMapping *)currencyMapping;

@end
