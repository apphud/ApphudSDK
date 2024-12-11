
#import "AMANamedMigration.h"

@protocol AMADatabaseProtocol;

@protocol AMAApiKeyMigration<AMANamedMigration>

- (void)applyMigrationWithApiKey:(NSString *)apiKey toDatabase:(id<AMADatabaseProtocol>)database;

@end
