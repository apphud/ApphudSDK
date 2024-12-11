
#import <AppMetricaLog/AppMetricaLog.h>
#import "AMALocationDataMigrationTo500.h"
#import "AMADatabaseConstants.h"
#import "AMAStorageKeys.h"
#import <AppMetricaFMDB/AppMetricaFMDB.h>
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>
#import "AMAMigrationTo500Utils.h"
#import "AMADatabaseProtocol.h"
#import "AMATableDescriptionProvider.h"

@implementation AMALocationDataMigrationTo500

- (NSString *)migrationKey
{
    return AMAStorageStringKeyDidApplyDataMigrationFor500;
}

- (void)applyMigrationToDatabase:(id<AMADatabaseProtocol>)database
{
    NSString *oldDBPath = [[AMAMigrationTo500Utils migrationPath] stringByAppendingPathComponent:@"l_data.sqlite"];

    @synchronized (self) {
        if ([AMAFileUtility fileExistsAtPath:oldDBPath]) {
            [self migrateTables:oldDBPath database:database];
        }
    }
}

- (void)migrateTables:(NSString *)sourceDBPath
             database:(id<AMADatabaseProtocol>)database
{
    AMAFMDatabase *sourceDB = [AMAFMDatabase databaseWithPath:sourceDBPath];
    
    if ([sourceDB open] == NO) {
        AMALogWarn(@"Failed to open database at path: %@", sourceDBPath);
        return;
    }
    
    NSDictionary *tables = @{
        kAMALocationsTableName : [AMATableDescriptionProvider locationsTableMetaInfo],
        kAMALocationsVisitsTableName : [AMATableDescriptionProvider visitsTableMetaInfo],
        kAMAKeyValueTableName : [AMATableDescriptionProvider stringKVTableMetaInfo],
    };
    [database inDatabase:^(AMAFMDatabase *db) {
        for (NSString *table in tables) {
            [AMAMigrationTo500Utils migrateTable:table
                                     tableScheme:[tables objectForKey:table]
                                        sourceDB:sourceDB
                                   destinationDB:db];
        }
        [db close];
    }];
    [sourceDB close];
}

@end
