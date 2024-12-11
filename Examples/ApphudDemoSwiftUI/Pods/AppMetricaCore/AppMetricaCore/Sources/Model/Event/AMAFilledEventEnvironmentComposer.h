
#import <Foundation/Foundation.h>
#import "AMAEventEnvironmentComposer.h"

@class AMAReporterStateStorage;

@interface AMAFilledEventEnvironmentComposer : NSObject <AMAEventEnvironmentComposer>

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithStorage:(AMAReporterStateStorage *)storage;

@end
