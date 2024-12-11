
#import "AMAKeyValueStorageProvidersFactory.h"
#import "AMADatabaseKeyValueStorageProvider.h"
#import "AMAGenericStringKeyValueStorageProvider.h"
#import "AMAJSONFileKVSDataProvider.h"

@implementation AMAKeyValueStorageProvidersFactory

+ (id<AMADatabaseKeyValueStorageProviding>)databaseProviderForTableName:(NSString *)tableName
                                                              converter:(id<AMAKeyValueStorageConverting>)converter
                                                         objectProvider:(AMADatabaseObjectProviderBlock)objectProvider
                                                 backingKVSDataProvider:(id<AMAKeyValueStorageDataProviding>)backingDataProvider
{
    return [[AMADatabaseKeyValueStorageProvider alloc] initWithTableName:tableName
                                                               converter:converter
                                                          objectProvider:objectProvider
                                                  backingKVSDataProvider:backingDataProvider];
}

+ (id<AMAKeyValueStorageProviding>)jsonFileProviderForFileStorage:(id<AMAFileStorage>)fileStorage
{
    id<AMAKeyValueStorageDataProviding> dataProvider =
        [[AMAJSONFileKVSDataProvider alloc] initWithFileStorage:fileStorage];
    return [[AMAGenericStringKeyValueStorageProvider alloc] initWithDataProvider:dataProvider];
}

+ (id<AMAKeyValueStorageProviding>)userDefaultsProviderForUserDefaults:(NSUserDefaults *)userDefaults
{
    id<AMAKeyValueStorageDataProviding> dataProvider =
        [[AMAUserDefaultsKVSDataProvider alloc] initWithUserDefaults:userDefaults];
    return [[AMAGenericStringKeyValueStorageProvider alloc] initWithDataProvider:dataProvider];
}

@end
