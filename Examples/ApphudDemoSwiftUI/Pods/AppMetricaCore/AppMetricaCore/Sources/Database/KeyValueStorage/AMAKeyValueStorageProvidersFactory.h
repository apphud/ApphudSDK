
#import <Foundation/Foundation.h>
#import "AMADatabaseObjectProviderBlock.h"

@protocol AMAKeyValueStorageProviding;
@protocol AMADatabaseKeyValueStorageProviding;
@protocol AMAKeyValueStorageConverting;
@protocol AMAFileStorage;
@protocol AMAKeyValueStorageDataProviding;

@interface AMAKeyValueStorageProvidersFactory : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

+ (id<AMADatabaseKeyValueStorageProviding>)databaseProviderForTableName:(NSString *)tableName
                                                              converter:(id<AMAKeyValueStorageConverting>)converter
                                                         objectProvider:(AMADatabaseObjectProviderBlock)objectProvider
                                                 backingKVSDataProvider:(id<AMAKeyValueStorageDataProviding>)backingDataProvider;
+ (id<AMAKeyValueStorageProviding>)jsonFileProviderForFileStorage:(id<AMAFileStorage>)fileStorage;
+ (id<AMAKeyValueStorageProviding>)userDefaultsProviderForUserDefaults:(NSUserDefaults *)userDefaults;

@end
