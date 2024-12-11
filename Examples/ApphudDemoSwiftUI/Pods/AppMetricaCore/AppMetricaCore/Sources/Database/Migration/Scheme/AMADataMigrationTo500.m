
#import <AppMetricaLog/AppMetricaLog.h>
#import "AMADataMigrationTo500.h"
#import "AMADatabaseConstants.h"
#import "AMAStorageKeys.h"
#import <AppMetricaFMDB/AppMetricaFMDB.h>
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>
#import "AMAMigrationTo500Utils.h"
#import "AMADatabaseProtocol.h"
#import "AMATableDescriptionProvider.h"
#import "AMAMigrationUtils.h"
#import "AMAInstantFeaturesConfiguration.h"

@implementation AMADataMigrationTo500

- (NSString *)migrationKey
{
    return AMAStorageStringKeyDidApplyDataMigrationFor500;
}

- (void)applyMigrationToDatabase:(id<AMADatabaseProtocol>)database
{
    NSString *oldDBPath = [[AMAMigrationTo500Utils migrationPath] stringByAppendingPathComponent:@"storage.sqlite"];
    
    @synchronized (self) {
        if ([AMAFileUtility fileExistsAtPath:oldDBPath]) {
            [self migrateData:oldDBPath database:database];
            
            // Reset startup update date
            [database inDatabase:^(AMAFMDatabase *db) {
                [AMAMigrationUtils resetStartupUpdatedAtToDistantPastInDatabase:database db:db];
            }];
            [self migrateExtendedStartupParametersIfNeeded:database];
        }
        
        [self migrateInstantIfNeeded:database];
        
        [AMAMigrationTo500Utils migrateCrashReportsIfNeeded];
    }
}

- (void)migrateInstantIfNeeded:(id<AMADatabaseProtocol>)database
{
    NSString *instantMigrationPath = [[AMAMigrationTo500Utils migrationPath] stringByAppendingPathComponent:kAMAInstantFileName];
    if ([AMAFileUtility fileExistsAtPath:instantMigrationPath]) {
        [AMAMigrationTo500Utils migrateUUID];
    }
}
    
- (void)migrateData:(NSString *)sourceDBPath
           database:(id<AMADatabaseProtocol>)database
{
    AMAFMDatabase *sourceDB = [AMAFMDatabase databaseWithPath:sourceDBPath];
    
    if ([sourceDB open] == NO) {
        AMALogWarn(@"Failed to open database at path: %@", sourceDBPath);
        return;
    }
    
    [database inDatabase:^(AMAFMDatabase *db) {
        [AMAMigrationTo500Utils migrateTable:kAMAKeyValueTableName
                                 tableScheme:[AMATableDescriptionProvider binaryKVTableMetaInfo]
                                    sourceDB:sourceDB
                               destinationDB:db];
        
        [db close];
    }];
    [AMAMigrationTo500Utils migrateDeviceIDFromDB:sourceDB];
    [sourceDB close];
}

- (void)migrateExtendedStartupParametersIfNeeded:(id<AMADatabaseProtocol>)database
{
    NSString *adHostKey = @"get_ad.host";
    [database inDatabase:^(AMAFMDatabase *db) {
        NSString *adHost = [[database.storageProvider storageForDB:db] stringForKey:adHostKey error:nil];
        
        if (adHost != nil) {
            [[database.storageProvider storageForDB:db] saveJSONDictionary:@{@"get_ad" : adHost}
                                                                    forKey:AMAStorageStringKeyExtendedParameters
                                                                     error:nil];
        }
    }];
}

@end
