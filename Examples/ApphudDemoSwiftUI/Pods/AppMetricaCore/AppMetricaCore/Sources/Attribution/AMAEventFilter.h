
#import <Foundation/Foundation.h>
#import "AMAJSONSerializable.h"
#import "AMAEventTypes.h"

@class AMARevenueEventCondition;
@class AMAClientEventCondition;
@class AMAECommerceEventCondition;

@interface AMAEventFilter : NSObject <AMAJSONSerializable>

@property (nonatomic, assign, readonly) AMAEventType type;
@property (nonatomic, strong, readonly) AMAClientEventCondition *clientEventCondition;
@property (nonatomic, strong, readonly) AMAECommerceEventCondition *eCommerceEventCondition;
@property (nonatomic, strong, readonly) AMARevenueEventCondition *revenueEventCondition;

- (instancetype)initWithEventType:(AMAEventType)type
             clientEventCondition:(AMAClientEventCondition *)clientEventCondition
          eCommerceEventCondition:(AMAECommerceEventCondition *)eCommerceEventCondition
            revenueEventCondition:(AMARevenueEventCondition *)revenueEventCondition;

@end
