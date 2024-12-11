
#import <Foundation/Foundation.h>
#import <AppMetricaStorageUtils/AppMetricaStorageUtils.h>
#import "AMADatabaseObjectProviderBlock.h"

@class AMAFMDatabase;
@class AMAFMResultSet;

@interface AMADatabaseKVSDataProvider : NSObject <AMAKeyValueStorageDataProviding>

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithDatabase:(AMAFMDatabase *)database
                       tableName:(NSString *)tableName
                  objectProvider:(AMADatabaseObjectProviderBlock)objectProvider;

@end
