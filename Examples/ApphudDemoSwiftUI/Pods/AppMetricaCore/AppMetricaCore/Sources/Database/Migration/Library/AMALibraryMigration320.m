
#import "AMALibraryMigration320.h"
#import "AMAMigrationUtils.h"
#import "AMADatabaseProtocol.h"

@implementation AMALibraryMigration320

- (NSString *)version
{
    return @"3.2.0";
}

- (void)applyMigrationToDatabase:(id<AMADatabaseProtocol>)database db:(AMAFMDatabase *)db
{
    // We should update startup because of deviceIDHash and diagnostic hosts.
    [AMAMigrationUtils resetStartupUpdatedAtToDistantPastInDatabase:database db:db];
}

@end
