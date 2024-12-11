
#import <Foundation/Foundation.h>
#import <AppMetricaStorageUtils/AppMetricaStorageUtils.h>
#import "AMAUnderlyingKVSDataProviderTypes.h"

@interface AMAProxyDataToStringKVSDataProvider : NSObject <AMAKeyValueStorageDataProviding>

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithUnderlyingDataProvider:(id<AMAKeyValueStorageDataProviding>)dataPrivder;

@end
