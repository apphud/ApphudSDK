
#import <Foundation/Foundation.h>
#import <AppMetricaStorageUtils/AppMetricaStorageUtils.h>

@protocol AMAKeyValueStorageDataProviding;

@interface AMAGenericStringKeyValueStorageProvider : NSObject <AMAKeyValueStorageProviding>

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithDataProvider:(id<AMAKeyValueStorageDataProviding>)dataProvider;

@end
