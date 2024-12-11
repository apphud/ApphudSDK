
#import "AMAConfigurationDatabaseSchemeMigrationTo7.h"
#import <AppMetricaFMDB/AppMetricaFMDB.h>

@implementation AMAConfigurationDatabaseSchemeMigrationTo7

- (NSUInteger)schemeVersion
{
    return 7;
}

- (BOOL)applyTransactionalMigrationToDatabase:(AMAFMDatabase *)db
{
    BOOL result = YES;

    result = [self createBackupTableInDatabase:db];

    if (result) {
        result = [self copyCurrentTableToBackupTableInDatabase:db];
    }
    if (result) {
        result = [self dropCurrentTableInDatabase:db];
    }
    if (result) {
        result = [self renameBackupTableInDataBase:db];
    }

    return result;
}

- (BOOL)createBackupTableInDatabase:(AMAFMDatabase *)db
{
    return [db executeUpdate:@"CREATE TABLE sessions_backup ("
            "id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "
            "start_time STRING NOT NULL, "
            "server_time_offset DOUBLE, "
            "updated_at STRING NOT NULL, "
            "locale STRING NOT NULL, "
            "event_seq INTEGER NOT NULL DEFAULT 0, "
            "api_key STRING NOT NULL, "
            "type INTEGER NOT NULL, "
            "app_state STRING, "
            "finished BOOL NOT NULL DEFAULT 0)"
    ];
}

- (BOOL)copyCurrentTableToBackupTableInDatabase:(AMAFMDatabase *)db
{
    return [db executeUpdate:@"INSERT INTO sessions_backup "
            "SELECT id, "
            "start_time, "
            "server_time_offset, "
            "updated_at, "
            "locale, "
            "event_seq, "
            "api_key, "
            "type, "
            "app_state, "
            "finished "
            "FROM sessions"];
}

- (BOOL)dropCurrentTableInDatabase:(AMAFMDatabase *)db
{
    return [db executeUpdate:@"DROP TABLE sessions"];
}

- (BOOL)renameBackupTableInDataBase:(AMAFMDatabase *)db
{
    return [db executeUpdate:@"ALTER TABLE sessions_backup RENAME TO sessions"];
}

@end
