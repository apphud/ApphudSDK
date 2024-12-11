
#import <Foundation/Foundation.h>
#import "AMAOpenIDComposer.h"

@class AMAReporterStateStorage;

@interface AMAFilledOpenIDComposer : NSObject <AMAOpenIDComposer>

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithStorage:(AMAReporterStateStorage *)storage;

@end
