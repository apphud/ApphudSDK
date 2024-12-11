
#import <UIKit/UIKit.h>
#import "AMAUnderlyingKVSDataProviderTypes.h"

@interface AMABackingKVSDataProvider : NSObject <AMAKeyValueStorageDataProviding>

@property (nonatomic, strong, readonly) NSSet<NSString *> *backingKeys;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithProviderSource:(AMAKVSProviderSource)providerSource
                 backingProviderSource:(AMAKVSProviderSource)backingProviderSource
                           backingKeys:(NSArray<NSString *> *)backingKeys;

@end
