
#import "AMAConfigurationDatabaseSchemeMigrationTo13.h"
#import "AMAMigrationUtils.h"

@implementation AMAConfigurationDatabaseSchemeMigrationTo13

- (NSUInteger)schemeVersion
{
    return 13;
}

- (BOOL)applyTransactionalMigrationToDatabase:(AMAFMDatabase *)db
{
    return [AMAMigrationUtils addLocationEnabledInDatabase:db];
}

@end
