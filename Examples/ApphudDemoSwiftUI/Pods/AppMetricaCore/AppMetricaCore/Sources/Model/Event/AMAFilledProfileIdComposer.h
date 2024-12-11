
#import <Foundation/Foundation.h>
#import "AMAProfileIdComposer.h"

@class AMAReporterStateStorage;

@interface AMAFilledProfileIdComposer : NSObject <AMAProfileIdComposer>

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithStorage:(AMAReporterStateStorage *)storage;

@end
