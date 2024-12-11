
#import <Foundation/Foundation.h>
#import "AMADatabaseKeyValueStorageProviding.h"
#import "AMADatabaseObjectProviderBlock.h"

@protocol AMADatabaseProtocol;
@protocol AMAKeyValueStorageConverting;
@protocol AMAKeyValueStorageDataProviding;

@interface AMADatabaseKeyValueStorageProvider : NSObject <AMADatabaseKeyValueStorageProviding>

@property (nonatomic, weak) id<AMADatabaseProtocol> database;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithTableName:(NSString *)tableName
                        converter:(id<AMAKeyValueStorageConverting>)converter
                   objectProvider:(AMADatabaseObjectProviderBlock)objectProvider
           backingKVSDataProvider:(id<AMAKeyValueStorageDataProviding>)backingDataProvider;

@end
