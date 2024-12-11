
#import "AMAConfigurationDatabaseSchemeMigrationTo6.h"
#import "AMAMigrationUtils.h"

@implementation AMAConfigurationDatabaseSchemeMigrationTo6

- (NSUInteger)schemeVersion
{
    return 6;
}

- (BOOL)applyTransactionalMigrationToDatabase:(AMAFMDatabase *)db
{
    BOOL result = YES;

    result = [AMAMigrationUtils addServerTimeOffsetToSessionsTableInDatabase:db];

    if (result) {
        result = [AMAMigrationUtils addErrorEnvironmentToEventsAndErrorsTableInDatabase:db];
    }
    if (result) {
        result = [AMAMigrationUtils addUserInfoInDatabase:db];
    }

    return result;
}

@end
