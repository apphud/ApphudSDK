
#import "AMAConfigurationDatabaseSchemeMigrationTo3.h"
#import <AppMetricaFMDB/AppMetricaFMDB.h>

@implementation AMAConfigurationDatabaseSchemeMigrationTo3

- (NSUInteger)schemeVersion
{
    return 3;
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
    if (result) {
        result = [db executeUpdate:@"ALTER TABLE sessions ADD finished BOOL NOT NULL DEFAULT 0"];
    }
    if (result) {
        result = [db executeUpdate:@"ALTER TABLE sessions ADD app_state STRING"];
    }

    return result;
}

- (BOOL)createBackupTableInDatabase:(AMAFMDatabase *)db
{
    return [db executeUpdate:@"CREATE TABLE sessions_backup ("
            "id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "
            "start_time STRING NOT NULL, "
            "updated_at STRING NOT NULL,"
            "locale STRING NOT NULL, "
            "lat DOUBLE,"
            "lon DOUBLE, "
            "event_seq INTEGER NOT NULL DEFAULT 0, "
            "api_key INTEGER NOT NULL, "
            "type INTEGER NOT NULL)"
            ];
}

- (BOOL)copyCurrentTableToBackupTableInDatabase:(AMAFMDatabase *)db
{
    return [db executeUpdate:@"INSERT INTO sessions_backup "
            "SELECT id, "
            "start_time, "
            "updated_at, "
            "locale, "
            "lat, "
            "lon, "
            "event_seq, "
            "api_key, "
            "type "
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
