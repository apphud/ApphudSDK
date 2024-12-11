
#import "AMAConfigurationDatabaseSchemeMigrationTo17.h"
#import "AMAStorageKeys.h"
#import <AppMetricaFMDB/AppMetricaFMDB.h>

@implementation AMAConfigurationDatabaseSchemeMigrationTo17

- (NSUInteger)schemeVersion
{
    return 17;
}

- (BOOL)applyTransactionalMigrationToDatabase:(AMAFMDatabase *)db
{
    NSString *query = [self insertHadFirstStartupForKVTable];
    return [db executeUpdate:query withArgumentsInArray:@[ AMAStorageStringKeyHadFirstStartup,
                                                           AMAStorageStringKeyUUID,
                                                           AMAStorageStringKeyFirstStartupUpdateDate,
                                                           @"report.host",
                                                           AMAStorageStringKeyReportHosts]];
}

- (NSString *)insertHadFirstStartupForKVTable
{
    return @"INSERT INTO kv (k, v) VALUES ( ? , ( SELECT min(count(*), 1) FROM kv WHERE k IN (? , ? , ? , ? ) ) )";
}

@end
