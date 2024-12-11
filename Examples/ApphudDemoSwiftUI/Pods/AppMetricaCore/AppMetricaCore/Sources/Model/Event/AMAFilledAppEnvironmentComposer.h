
#import <Foundation/Foundation.h>
#import "AMAAppEnvironmentComposer.h"

@class AMAReporterStateStorage;

@interface AMAFilledAppEnvironmentComposer : NSObject <AMAAppEnvironmentComposer>

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithStorage:(AMAReporterStateStorage *)storage;

@end
