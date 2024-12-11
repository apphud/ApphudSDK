
#import "AMAConfigurationDatabaseSchemeMigrationTo11.h"
#import <AppMetricaFMDB/AppMetricaFMDB.h>

@implementation AMAConfigurationDatabaseSchemeMigrationTo11

- (NSUInteger)schemeVersion
{
    return 11;
}

- (BOOL)applyTransactionalMigrationToDatabase:(AMAFMDatabase *)db
{
    NSArray *operations =  @[[self copyDataFromErrorsTableToEventsTable],
                             @"DROP TABLE errors",
                             [self createEventsEditTable],
                             [self joinSessionsTableWithEventsTableToEventsEditTable],
                             @"DROP TABLE events",
                             [self moveEditTableToTable:@"events"],
                             [self createSessionEditTable],
                             [self copyDataFromSessionsTableToSessionsEditTable],
                             @"DROP TABLE sessions",
                             [self moveEditTableToTable:@"sessions"]];
    
    BOOL result = NO;

    for (NSString *operation in operations) {
        result = [db executeUpdate:operation];
        if (result == NO) {
            break;
        }
    }

    return result;
}

- (NSString *)createEventsEditTable
{
    return @"CREATE TABLE events_edit ("
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
            "bytes_truncated INTEGER)";
}

- (NSString *)createSessionEditTable
{
    return @"CREATE TABLE sessions_edit ("
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
            "finished BOOL NOT NULL DEFAULT 0 )";
}

- (NSString *)copyDataFromErrorsTableToEventsTable
{
    return @"INSERT INTO events ( "
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

            "SELECT created_at, "
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
            "bytes_truncated "
            "FROM errors";
}

- (NSString *)joinSessionsTableWithEventsTableToEventsEditTable
{
    return @"INSERT INTO events_edit ( "
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
            "bytes_truncated)"

            "SELECT "
            "event.id, "
            "event.created_at, "
            "event.session_id, "
            "event.seq, "
            "event.offset, "
            "event.name, "
            "event.value, "
            "event.type, "
            "event.latitude, "
            "event.longitude, "
            "event.location_timestamp, "
            "event.location_horizontal_accuracy, "
            "event.location_vertical_accuracy, "
            "event.location_direction, "
            "event.location_speed, "
            "event.location_altitude, "
            "event.error_environment, "
            "event.user_info, "
            "event.app_environment, "
            "event.bytes_truncated "
            "FROM events as event "
            "INNER JOIN sessions as session "
            "ON event.session_id = session.id";
}

- (NSString *)copyDataFromSessionsTableToSessionsEditTable
{
    return @"INSERT INTO sessions_edit ( "
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
            "finished) "

            "SELECT "
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
            "FROM sessions";
}

- (NSString *)moveEditTableToTable:(NSString *)table
{
    return [NSString stringWithFormat:@"ALTER TABLE %@_edit RENAME TO %@", table, table];
}

@end
