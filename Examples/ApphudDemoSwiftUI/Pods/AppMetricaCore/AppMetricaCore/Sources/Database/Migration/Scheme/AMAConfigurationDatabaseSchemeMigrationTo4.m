
#import "AMAConfigurationDatabaseSchemeMigrationTo4.h"
#import "AMAMigrationUtils.h"
#import <AppMetricaFMDB/AppMetricaFMDB.h>

@implementation AMAConfigurationDatabaseSchemeMigrationTo4

- (NSUInteger)schemeVersion
{
    return 4;
}

- (BOOL)applyTransactionalMigrationToDatabase:(AMAFMDatabase *)db
{
    BOOL result = YES;

    result = [AMAMigrationUtils addLocationToTable:@"events" inDatabase:db];

    if (result) {
        result = [self transferLocationFromSessionsToEvents:db];
    }
    if (result) {
        result = [self createBackupTableInDatabase:db];
    }
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

- (BOOL)transferLocationFromSessionsToEvents:(AMAFMDatabase *)db
{
    BOOL locationTransferResult = [db executeUpdate:@"UPDATE events "
                                   "SET latitude= (SELECT sessions.lat FROM sessions WHERE events.session_id=sessions.id), "
                                   "longitude= (SELECT lon FROM sessions WHERE events.session_id=sessions.id), "
                                   "location_horizontal_accuracy=100, "
                                   "location_vertical_accuracy=-1, "
                                   "location_direction=-1, "
                                   "location_speed=-1",
                                   "location_altitude=0",
                                   "location_timestamp=(SELECT sessions.start_time FROM sessions WHERE events.session_id=sessions.id)"
                                   ];
    return locationTransferResult;
}

- (BOOL)createBackupTableInDatabase:(AMAFMDatabase *)db
{
    return [db executeUpdate:@"CREATE TABLE sessions_backup ("
            "id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "
            "start_time STRING NOT NULL, "
            "updated_at STRING NOT NULL,"
            "locale STRING NOT NULL, "
            "event_seq INTEGER NOT NULL DEFAULT 0, "
            "api_key INTEGER NOT NULL, "
            "type INTEGER NOT NULL, "
            "app_state STRING, "
            "finished BOOL NOT NULL DEFAULT 0)"];
}

- (BOOL)copyCurrentTableToBackupTableInDatabase:(AMAFMDatabase *)db
{
    return [db executeUpdate:@"INSERT INTO sessions_backup "
            "SELECT id, "
            "start_time, "
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
