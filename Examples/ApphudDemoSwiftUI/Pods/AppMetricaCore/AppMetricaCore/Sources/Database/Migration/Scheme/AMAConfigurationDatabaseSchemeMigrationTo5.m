
#import "AMAConfigurationDatabaseSchemeMigrationTo5.h"
#import "AMAMigrationUtils.h"

@implementation AMAConfigurationDatabaseSchemeMigrationTo5

- (NSUInteger)schemeVersion
{
    return 5;
}

- (BOOL)applyTransactionalMigrationToDatabase:(AMAFMDatabase *)db
{
    return [AMAMigrationUtils addLocationToTable:@"errors" inDatabase:db];
}

@end
