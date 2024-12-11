
#import "AMAConfigurationDatabaseSchemeMigrationTo8.h"
#import "AMAMigrationUtils.h"
#import <AppMetricaFMDB/AppMetricaFMDB.h>

@implementation AMAConfigurationDatabaseSchemeMigrationTo8

- (NSUInteger)schemeVersion
{
    return 8;
}

- (BOOL)applyTransactionalMigrationToDatabase:(AMAFMDatabase *)db
{
     BOOL result = YES;

    NSMutableArray *operations = [NSMutableArray new];
    for (NSString *table in @[@"events", @"errors"]) {
        [operations addObjectsFromArray:@[
                [self createBackupTableForTable:table],
                [self copyDataToBackupTableFromTable:table],
                [self dropTable:table],
                [self moveBackupTableToTable:table],
        ]];
    }

    for (NSString *operation in operations) {
        result = [db executeUpdate:operation];
        if (result == NO) {
            break;
        }
    }

    if (result) {
        result = [AMAMigrationUtils addAppEnvironmentToEventsAndErrorsTableInDatabase:db];
    }
    if (result) {
        result = [AMAMigrationUtils addTruncatedToEventsAndErrorsTableInDatabase:db];
    }

    return result;
}

- (NSString *)createBackupTableForTable:(NSString *)table
{
    return [NSString stringWithFormat:
            @"CREATE TABLE %@_backup ("
            "id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "
            "created_at STRING NOT NULL, "
            "session_id INTEGER NOT NULL, "
            "seq INTEGER NOT NULL, "
            "offset STRING NOT NULL, "
            "name STRING, "
            "value STRING, "
            "type INTEGER NOT NULL, "
            "latitude DOUBLE, "
            "longitude DOUBLE, "
            "location_timestamp STRING, "
            "location_horizontal_accuracy INTEGER, "
            "location_vertical_accuracy INTEGER, "
            "location_direction INTEGER, "
            "location_speed INTEGER, "
            "location_altitude INTEGER, "
            "error_environment STRING, "
            "user_info STRING )",
            table
    ];
}

- (NSString *)copyDataToBackupTableFromTable:(NSString *)table
{
    return [NSString stringWithFormat:
            @"INSERT INTO %@_backup( "
            "id, "
            "created_at, "
            "session_id, "
            "seq, "
            "offset, "
            "name, "
            "value, "
            "type, "
            "latitude, "
            "longitude, "
            "location_timestamp, "
            "location_horizontal_accuracy, "
            "location_vertical_accuracy, "
            "location_direction, "
            "location_speed, "
            "location_altitude, "
            "error_environment, "
            "user_info ) "

            "SELECT id, "
            "created_at, "
            "session_id, "
            "seq, "
            "offset, "
            "name, "
            "value, "
            "type, "
            "latitude, "
            "longitude, "
            "location_timestamp, "
            "location_horizontal_accuracy, "
            "location_vertical_accuracy, "
            "location_direction, "
            "location_speed, "
            "location_altitude, "
            "environment, "
            "user_info "
            "FROM %@",
            table,
            table
    ];
}

- (NSString *)dropTable:(NSString *)table
{
    return [NSString stringWithFormat:@"DROP TABLE %@", table];
}

- (NSString *)moveBackupTableToTable:(NSString *)table
{
    return [NSString stringWithFormat:@"ALTER TABLE %@_backup RENAME TO %@", table, table];
}

@end
