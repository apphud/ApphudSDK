
#import <Foundation/Foundation.h>
#import <AppMetricaStorageUtils/AppMetricaStorageUtils.h>

@interface AMAInMemoryKeyValueStorageDataProvider : NSObject <AMAKeyValueStorageDataProviding>

- (instancetype)initWithDictionary:(NSMutableDictionary *)dictionary;

@end
