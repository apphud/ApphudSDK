
#import <Foundation/Foundation.h>
#import "AMADatabaseProtocol.h"

@class AMATableSchemeController;
@class AMADatabaseMigrationManager;
@class AMAStorageTrimManager;
@protocol AMAKeyValueStorageConverting;

NS_ASSUME_NONNULL_BEGIN

@interface AMADatabase : NSObject <AMADatabaseProtocol>

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithTableSchemeController:(AMATableSchemeController *)tableSchemeController
                                 databasePath:(NSString *)databasePath
                             migrationManager:(AMADatabaseMigrationManager *)migrationManager
                                  trimManager:(nullable AMAStorageTrimManager *)trimManager
                      keyValueStorageProvider:(id<AMADatabaseKeyValueStorageProviding>)keyValueStorageProvider
                         criticalKeyValueKeys:(NSArray<NSString *> *)criticalKeyValueKeys;

@end

NS_ASSUME_NONNULL_END
