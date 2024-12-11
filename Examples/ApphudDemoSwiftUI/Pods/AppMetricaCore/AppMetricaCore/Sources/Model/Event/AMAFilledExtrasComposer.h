#import <Foundation/Foundation.h>
#import "AMAExtrasComposer.h"

NS_ASSUME_NONNULL_BEGIN

@class AMAReporterStateStorage;

@interface AMAFilledExtrasComposer : NSObject <AMAExtrasComposer>

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithStorage:(AMAReporterStateStorage *)storage;

@end

NS_ASSUME_NONNULL_END
