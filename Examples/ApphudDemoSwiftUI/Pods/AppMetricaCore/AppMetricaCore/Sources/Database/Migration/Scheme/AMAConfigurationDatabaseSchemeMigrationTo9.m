
#import "AMAConfigurationDatabaseSchemeMigrationTo9.h"
#import <AppMetricaFMDB/AppMetricaFMDB.h>

@implementation AMAConfigurationDatabaseSchemeMigrationTo9

- (NSUInteger)schemeVersion
{
    return 9;
}

- (BOOL)applyTransactionalMigrationToDatabase:(AMAFMDatabase *)db
{
    BOOL result = YES;

    NSMutableArray *operations = [NSMutableArray new];
    for (NSString *table in @[@"events", @"errors"]) {
        [operations addObjectsFromArray:@[
                                          [self createEditTableForTable:table],
                                          [self copyDataToEditTableFromTable:table],
                                          [self dropTable:table],
                                          [self moveEditTableToTable:table],
                                          ]];
    }
    [operations addObject:[self dropLegacyKVRows]];

    for (NSString *operation in operations) {
        result = [db executeUpdate:operation];
        if (result == NO) {
            break;
        }
    }

    return result;
}

- (NSString *)createEditTableForTable:(NSString *)table
{
    return [NSString stringWithFormat:
            @"CREATE TABLE %@_edit ("
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
            "user_info STRING, "
            "app_environment STRING, "
            "bytes_truncated INTEGER)",
            table
            ];
}

- (NSString *)copyDataToEditTableFromTable:(NSString *)table
{
    return [NSString stringWithFormat:
            @"INSERT INTO %@_edit( "
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
            "user_info, "
            "app_environment, "
            "bytes_truncated ) "

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
            "error_environment, "
            "user_info, "
            "app_environment, "
            "is_truncated "
            "FROM %@",
            table,
            table
            ];
}

- (NSString *)dropTable:(NSString *)table
{
    return [NSString stringWithFormat:@"DROP TABLE %@", table];
}

- (NSString *)moveEditTableToTable:(NSString *)table
{
    return [NSString stringWithFormat:@"ALTER TABLE %@_edit RENAME TO %@", table, table];
}

- (NSString *)dropLegacyKVRows
{
    return @"DELETE FROM kv "
            "WHERE k IN ("
                "'previous.bundle_version',"
                "'previous.os_version',"
                "'add.was.terminated',"
                "'app.was.in.background'"
            ")";
}

@end
