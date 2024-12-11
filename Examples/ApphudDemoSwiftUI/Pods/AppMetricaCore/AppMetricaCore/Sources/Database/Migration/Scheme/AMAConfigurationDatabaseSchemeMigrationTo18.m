
#import "AMAConfigurationDatabaseSchemeMigrationTo18.h"
#import "AMAMigrationUtils.h"
#import <AppMetricaFMDB/AppMetricaFMDB.h>

@implementation AMAConfigurationDatabaseSchemeMigrationTo18

- (NSUInteger)schemeVersion
{
    return 18;
}

- (BOOL)applyTransactionalMigrationToDatabase:(AMAFMDatabase *)db
{
    BOOL success = YES;
    success = success && [AMAMigrationUtils addGlobalEventNumberInDatabase:db];
    success = success && [AMAMigrationUtils addEventNumberOfTypeInDatabase:db];
    return success;
}

@end
