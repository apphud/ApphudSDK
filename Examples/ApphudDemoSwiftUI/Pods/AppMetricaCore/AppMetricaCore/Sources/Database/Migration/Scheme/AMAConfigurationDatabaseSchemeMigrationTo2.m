
#import "AMAConfigurationDatabaseSchemeMigrationTo2.h"
#import <AppMetricaFMDB/AppMetricaFMDB.h>
#import "AMASession.h"

@implementation AMAConfigurationDatabaseSchemeMigrationTo2

- (NSUInteger)schemeVersion
{
    return 2;
}

- (BOOL)applyTransactionalMigrationToDatabase:(AMAFMDatabase *)db
{
    BOOL result = YES;

    result = [db executeUpdate:@"ALTER TABLE sessions ADD api_key INTEGER NOT NULL DEFAULT 0"];

    if (result) {
        result = [db executeUpdate:@"ALTER TABLE sessions ADD type INTEGER NOT NULL DEFAULT 0"];
    }
    if (result) {
        result = [db executeUpdate:@"UPDATE OR REPLACE sessions SET type = ? WHERE id = -1",
                                   @(AMASessionTypeBackground)];
    }

    return result;
}

@end
