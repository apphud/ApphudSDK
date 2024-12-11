
#import <Foundation/Foundation.h>
#import "AMALocationComposer.h"

@class AMALocationManager;

@interface AMAFilledLocationComposer : NSObject <AMALocationComposer>

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithLocationManager:(AMALocationManager *)manager;

@end
