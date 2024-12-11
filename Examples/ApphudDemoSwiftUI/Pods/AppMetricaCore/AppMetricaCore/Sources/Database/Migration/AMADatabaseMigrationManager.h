
#import <Foundation/Foundation.h>

@class AMADatabaseSchemeMigration;
@protocol AMADatabaseProtocol;

NS_ASSUME_NONNULL_BEGIN

@interface AMADatabaseMigrationManager : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithCurrentSchemeVersion:(NSUInteger)currentSchemeVersion
                            schemeMigrations:(NSArray *)schemeMigrations
                            apiKeyMigrations:(NSArray *)apiKeyMigrations
                              dataMigrations:(NSArray *)dataMigrations
                           libraryMigrations:(NSArray *)libraryMigrations NS_DESIGNATED_INITIALIZER;

- (void)applySchemeMigrationsToDatabase:(id<AMADatabaseProtocol>)database isNew:(BOOL)isNew;

- (void)applyDataMigrationsToDatabase:(id<AMADatabaseProtocol>)database;

- (void)applyApiKeyMigrationsWithKey:(NSString *)key toDatabase:(id<AMADatabaseProtocol>)database;

- (void)applyLibraryMigrationsToDatabase:(id<AMADatabaseProtocol>)database;

@end

NS_ASSUME_NONNULL_END
