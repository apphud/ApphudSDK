
#import "AMAConfigurationDatabaseSchemeMigrationTo10.h"
#import <AppMetricaFMDB/AppMetricaFMDB.h>

@implementation AMAConfigurationDatabaseSchemeMigrationTo10

- (NSUInteger)schemeVersion
{
    return 10;
}

- (BOOL)applyTransactionalMigrationToDatabase:(AMAFMDatabase *)db
{
    BOOL result = YES;

    NSArray *operations = @[
        [self createEditTableForSessionsTable],
        [self copyDataToEditTableFromSessionsTable],
        [self dropSessionsTable],
        [self moveEditTableToSessionsTable],
    ];

    for (NSString *operation in operations) {
        result = [db executeUpdate:operation];
        if (result == NO) {
            break;
        }
    }

    return result;
}

- (NSString *)createEditTableForSessionsTable
{
    return @"CREATE TABLE sessions_backup ("
                "id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "
                "start_time STRING NOT NULL, "
                "server_time_offset DOUBLE, "
                "last_event_time STRING, "
                "pause_time STRING NOT NULL, "
                "locale STRING NOT NULL, "
                "event_seq INTEGER NOT NULL DEFAULT 0, "
                "api_key STRING NOT NULL, "
                "type INTEGER NOT NULL, "
                "app_state STRING, "
                "finished BOOL NOT NULL DEFAULT 0 "
            ")";
}

- (NSString *)copyDataToEditTableFromSessionsTable
{
    return @"INSERT INTO sessions_backup ( "
                "id, "
                "start_time, "
                "server_time_offset, "
                "last_event_time, "
                "pause_time, "
                "locale, "
                "event_seq, "
                "api_key, "
                "type, "
                "app_state, "
                "finished "
            ") "

            "SELECT "
                "id, "
                "start_time, "
                "server_time_offset, "
                "updated_at, " // Use old 'updated_at' as new 'last_event_time'
                "updated_at, " // Use old 'updated_at' as new 'pause_time'
                "locale, "
                "event_seq, "
                "api_key, "
                "type, "
                "app_state, "
                "finished "
            "FROM sessions";
}

- (NSString *)dropSessionsTable
{
    return @"DROP TABLE sessions";
}

- (NSString *)moveEditTableToSessionsTable
{
    return @"ALTER TABLE sessions_backup RENAME TO sessions";
}

@end
