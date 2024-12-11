
#import "AMANamedMigration.h"

@protocol AMADatabaseProtocol;

@protocol AMADatabaseDataMigration <AMANamedMigration>

- (void)applyMigrationToDatabase:(id<AMADatabaseProtocol>)database;

@end
