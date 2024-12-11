
#import <Foundation/Foundation.h>

@class AMAFMDatabase;

NS_ASSUME_NONNULL_BEGIN

@interface AMADatabaseSchemeMigration : NSObject

- (NSUInteger)schemeVersion;
- (BOOL)applyTransactionalMigrationToDatabase:(AMAFMDatabase *)db;

@end

NS_ASSUME_NONNULL_END
