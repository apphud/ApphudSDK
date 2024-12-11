
#import <Foundation/Foundation.h>
#import "AMALocationEnabledComposer.h"

@class AMALocationManager;

@interface AMAFilledLocationEnabledComposer : NSObject <AMALocationEnabledComposer>

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithLocationManager:(AMALocationManager *)manager;

@end
