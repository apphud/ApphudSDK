
#import <Foundation/Foundation.h>
#import <AppMetricaStorageUtils/AppMetricaStorageUtils.h>
#import "AMAUnderlyingKVSDataProviderTypes.h"

@interface AMASyncKeyValueStorageDataProvider : NSObject <AMAKeyValueStorageDataProviding>

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithUnderlyingProviderSource:(AMAKVSProviderSource)providerSource;

@end
