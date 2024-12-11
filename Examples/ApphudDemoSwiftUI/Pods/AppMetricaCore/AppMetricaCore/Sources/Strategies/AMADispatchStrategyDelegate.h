
#import <Foundation/Foundation.h>

@class AMADispatchStrategy;

@protocol AMADispatchStrategyDelegate <NSObject>

@required
- (void)dispatchStrategyWantsReportingToHappen:(AMADispatchStrategy *)strategy;

@end
