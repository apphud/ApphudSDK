
#import "AMACore.h"
#import "AMAConfigurationDatabaseSchemeMigrationTo15.h"
#import "AMAMigrationUtils.h"
#import "AMAEventTypes.h"
#import <AppMetricaFMDB/AppMetricaFMDB.h>

static NSString *const kAMAFilePathPrefix = @"/Library/Caches/ru.yandex.mobile.YandexMobileMetrica/";

@implementation AMAConfigurationDatabaseSchemeMigrationTo15

- (NSUInteger)schemeVersion
{
    return 15;
}

- (BOOL)applyTransactionalMigrationToDatabase:(AMAFMDatabase *)db
{
    BOOL result = [AMAMigrationUtils addEncryptionTypeInDatabase:db];
    result = result && [self fixFilePathInDatabase:db];
    return result;
}

- (BOOL)fixFilePathInDatabase:(AMAFMDatabase *)db
{
    AMAFMResultSet *eventsSet = [db executeQuery:@"SELECT id, value FROM events WHERE type = ?"
                         withArgumentsInArray:@[ @(28) ]];
    while ([eventsSet next]) {
        NSString *eventValue = [eventsSet stringForColumn:@"value"];
        NSRange prefixRange = [eventValue rangeOfString:kAMAFilePathPrefix];
        if (prefixRange.length != 0) {
            NSInteger eventID = [eventsSet intForColumn:@"id"];
            NSString *trimmedEventValue = [eventValue substringFromIndex:NSMaxRange(prefixRange)];
            BOOL updateIsOK = [db executeUpdate:@"UPDATE events SET value = ? WHERE id = ?"
                           withArgumentsInArray:@[ trimmedEventValue, @(eventID) ]];
            if (updateIsOK == NO) {
                AMALogError(@"migration failed: %@", [db lastError]);
            }
        }
    }
    return YES;
}

@end
