
#import <AppMetricaStorageUtils/AppMetricaStorageUtils.h>
#import "AMAMigrationUtils.h"
#import "AMAStorageKeys.h"
#import "AMADatabaseProtocol.h"
#import "AMAOptionalBool.h"
#import <AppMetricaFMDB/AppMetricaFMDB.h>

@implementation AMAMigrationUtils

+ (BOOL)addColumn:(NSString *)columnName
          toTable:(NSString *)tableName
             type:(NSString *)columnType
         database:(AMAFMDatabase *)db
{
    return [self addColumn:columnName
                   toTable:tableName
                      type:columnType
                  database:db
                parameters:nil];
}

+ (BOOL)addColumn:(NSString *)columnName 
          toTable:(NSString *)tableName 
             type:(NSString *)columnType 
         database:(AMAFMDatabase *)db 
       parameters:(NSArray *)parameters
{
    BOOL eventsTableMigrationResult = YES;
    if ([db columnExists:columnName inTableWithName:tableName] == NO) {
        NSString *alterQuery = [NSString stringWithFormat:
                @"ALTER TABLE %@ ADD %@ %@ %@",
                tableName,
                columnName,
                columnType,
                [parameters componentsJoinedByString:@" "] ?: @""
        ];
        eventsTableMigrationResult = [db executeUpdate:alterQuery];
    }
    return eventsTableMigrationResult;
}

+ (BOOL)addLocationToTable:(NSString *)tableName inDatabase:(AMAFMDatabase *)db
{
    BOOL eventsTableMigrationResult = [self addColumn:@"latitude" toTable:tableName type:@"DOUBLE" database:db];

    if (eventsTableMigrationResult) {
        eventsTableMigrationResult = [self addColumn:@"longitude" toTable:tableName type:@"DOUBLE" database:db];
    }
    if (eventsTableMigrationResult) {
        eventsTableMigrationResult = [self addColumn:@"location_timestamp" toTable:tableName type:@"STRING" database:db];
    }
    if (eventsTableMigrationResult) {
        eventsTableMigrationResult = [self addColumn:@"location_horizontal_accuracy" toTable:tableName type:@"INTEGER" database:db];
    }
    if (eventsTableMigrationResult) {
        eventsTableMigrationResult = [self addColumn:@"location_vertical_accuracy" toTable:tableName type:@"INTEGER" database:db];
    }
    if (eventsTableMigrationResult) {
        eventsTableMigrationResult = [self addColumn:@"location_direction" toTable:tableName type:@"INTEGER" database:db];
    }
    if (eventsTableMigrationResult) {
        eventsTableMigrationResult = [self addColumn:@"location_speed" toTable:tableName type:@"INTEGER" database:db];
    }
    if (eventsTableMigrationResult) {
        eventsTableMigrationResult = [self addColumn:@"location_altitude" toTable:tableName type:@"INTEGER" database:db];
    }
    return eventsTableMigrationResult;
}

+ (BOOL)addServerTimeOffsetToSessionsTableInDatabase:(AMAFMDatabase *)db
{
    return [self addColumn:@"server_time_offset" toTable:@"sessions" type:@"DOUBLE" database:db];
}

+ (BOOL)addErrorEnvironmentToEventsAndErrorsTableInDatabase:(AMAFMDatabase *)db
{
    BOOL result = [self addColumn:@"environment" toTable:@"events" type:@"STRING" database:db];
    if (result) {
        result = [self addColumn:@"environment" toTable:@"errors" type:@"STRING" database:db];
    }
    
    return result;
}

+ (BOOL)addAppEnvironmentToEventsAndErrorsTableInDatabase:(AMAFMDatabase *)db
{
    BOOL result = [self addColumn:@"app_environment" toTable:@"events" type:@"STRING" database:db];
    if (result) {
        result = [self addColumn:@"app_environment" toTable:@"errors" type:@"STRING" database:db];
    }

    return result;
}

+ (BOOL)addTruncatedToEventsAndErrorsTableInDatabase:(AMAFMDatabase *)db
{
    NSArray *params = @[@"NOT NULL", @"DEFAULT 0"];
    BOOL result = [self addColumn:@"is_truncated" toTable:@"events" type:@"BOOL" database:db parameters:params];
    if (result) {
        result = [self addColumn:@"is_truncated" toTable:@"errors" type:@"BOOL" database:db parameters:params];
    }

    return result;
}

+ (BOOL)addUserInfoInDatabase:(AMAFMDatabase *)db
{
    BOOL result = [self addColumn:@"user_info" toTable:@"events" type:@"STRING" database:db];
    if (result) {
        result = [self addColumn:@"user_info" toTable:@"errors" type:@"STRING" database:db];
    }
    return result;
}

+ (BOOL)addOptionalBoolFieldWithName:(NSString *)fieldName toTable:(NSString *)tableName db:(AMAFMDatabase *)db
{
    return [self addColumn:fieldName
                   toTable:tableName
                      type:@"INTEGER"
                  database:db
                parameters:@[ [NSString stringWithFormat:@"DEFAULT %ld", (long)AMAOptionalBoolUndefined] ]];
}

+ (BOOL)addLocationEnabledInDatabase:(AMAFMDatabase *)db
{
    return [self addOptionalBoolFieldWithName:@"location_enabled" toTable:@"events" db:db];
}

+ (BOOL)addUserProfileIDInDatabase:(AMAFMDatabase *)db
{
    return [self addColumn:@"user_profile_id" toTable:@"events" type:@"STRING" database:db];
}

+ (BOOL)addEncryptionTypeInDatabase:(AMAFMDatabase *)db
{
    return [self addColumn:@"encryption_type"
                   toTable:@"events"
                      type:@"INTEGER"
                  database:db
                parameters:@[@"NOT NULL", @"DEFAULT 0"]];
}

+ (BOOL)addFirstOccurrenceInDatabase:(AMAFMDatabase *)db
{
    return [self addOptionalBoolFieldWithName:@"first_occurrence" toTable:@"events" db:db];
}

+ (BOOL)addAttributionIDInDatabase:(AMAFMDatabase *)db
{
    return [self addColumn:@"attribution_id" toTable:@"sessions" type:@"STRING" database:db];
}

+ (BOOL)addGlobalEventNumberInDatabase:(AMAFMDatabase *)db
{
    return [self addColumn:@"global_number"
                   toTable:@"events"
                      type:@"INTEGER"
                  database:db
                parameters:@[@"NOT NULL", @"DEFAULT 0"]];
}

+ (BOOL)addEventNumberOfTypeInDatabase:(AMAFMDatabase *)db
{
    return [self addColumn:@"number_of_type"
                   toTable:@"events"
                      type:@"INTEGER"
                  database:db
                parameters:@[@"NOT NULL", @"DEFAULT 0"]];
}

+ (BOOL)updateColumnTypes:(NSString *)columnTypesDescription ofKeyValueTable:(NSString *)tableName db:(AMAFMDatabase *)db
{
    BOOL result = YES;
    NSArray *operations = @[
        [NSString stringWithFormat:@"CREATE TABLE kv_temp (%@)", columnTypesDescription],
        [NSString stringWithFormat:@"INSERT INTO kv_temp (k, v) SELECT k, v FROM %@", tableName],
        [NSString stringWithFormat:@"DROP TABLE %@", tableName],
        [NSString stringWithFormat:@"ALTER TABLE kv_temp RENAME TO %@", tableName],
    ];

    for (NSString *operation in operations) {
        result = [db executeUpdate:operation];
        if (result == NO) {
            break;
        }
    }
    return result;
}

+ (void)resetStartupUpdatedAtToDistantPastInDatabase:(id<AMADatabaseProtocol>)database db:(AMAFMDatabase *)db
{
    [[database.storageProvider storageForDB:db] saveDate:[NSDate distantPast]
                                                  forKey:AMAStorageStringKeyStartupUpdatedAt
                                                   error:nil];
}

@end
