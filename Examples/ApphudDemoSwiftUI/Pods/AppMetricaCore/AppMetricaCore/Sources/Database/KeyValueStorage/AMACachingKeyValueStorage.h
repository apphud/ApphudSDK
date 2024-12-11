
#import <Foundation/Foundation.h>
#import "AMACore.h"

NS_ASSUME_NONNULL_BEGIN

@interface AMACachingKeyValueStorage : NSObject <AMAKeyValueStoring>

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithStorage:(id<AMAKeyValueStoring>)storage;

- (void)flush;

@end

NS_ASSUME_NONNULL_END
