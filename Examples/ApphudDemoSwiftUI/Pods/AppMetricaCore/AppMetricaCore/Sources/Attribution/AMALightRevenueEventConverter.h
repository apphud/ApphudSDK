
#import <Foundation/Foundation.h>

@class AMALightRevenueEvent;
@class AMARevenueInfoModel;

@interface AMALightRevenueEventConverter : NSObject

- (AMALightRevenueEvent *)eventFromModel:(AMARevenueInfoModel *)model;
- (AMALightRevenueEvent *)eventFromSerializedValue:(id)value;

@end
