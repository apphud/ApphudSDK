
#import "AMADataMigrationTo580.h"
#import "AMADatabaseConstants.h"
#import "AMAStorageKeys.h"
#import "AMADatabaseProtocol.h"
#import "AMAMigrationUtils.h"

@implementation AMADataMigrationTo580

- (NSString *)migrationKey
{
    return AMAStorageStringKeyDidApplyDataMigrationFor580;
}

- (void)applyMigrationToDatabase:(id<AMADatabaseProtocol>)database
{
    // Reset startup update date
    [database inDatabase:^(AMAFMDatabase *db) {
        [AMAMigrationUtils resetStartupUpdatedAtToDistantPastInDatabase:database db:db];
    }];
}

@end
