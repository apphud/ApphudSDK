
#import "AMAReporterDatabaseSchemeMigrationTo2.h"
#import "AMAMigrationUtils.h"
#import <AppMetricaFMDB/AppMetricaFMDB.h>

@implementation AMAReporterDatabaseSchemeMigrationTo2

- (NSUInteger)schemeVersion
{
    return 2;
}

- (BOOL)applyTransactionalMigrationToDatabase:(AMAFMDatabase *)db
{
    BOOL result = YES;

    result = result && [AMAMigrationUtils updateColumnTypes:@"k TEXT NOT NULL PRIMARY KEY, v BLOB"
                                            ofKeyValueTable:@"kv"
                                                         db:db];

    return result;
}

@end
