
#import "AMADatabaseMigrationManager.h"
#import "AMADatabaseProtocol.h"
#import "AMADatabaseConstants.h"
#import "AMADatabaseSchemeMigration.h"
#import "AMADatabaseDataMigration.h"
#import "AMALibraryMigration.h"
#import "AMAApiKeyMigration.h"
#import <AppMetricaPlatform/AppMetricaPlatform.h>

static NSUInteger const kAMAInitialSchemeVersion = 1;

@interface AMADatabaseMigrationManager ()

@property (nonatomic, assign, readonly) NSUInteger currentSchemeVersion;
@property (nonatomic, copy, readonly) NSArray *schemeMigrations;
@property (nonatomic, copy, readonly) NSArray *apiKeyMigrations;
@property (nonatomic, copy, readonly) NSArray *dataMigrations;
@property (nonatomic, copy, readonly) NSArray *libraryMigrations;

@end

@implementation AMADatabaseMigrationManager

- (instancetype)initWithCurrentSchemeVersion:(NSUInteger)currentSchemeVersion
                            schemeMigrations:(NSArray *)schemeMigrations
                            apiKeyMigrations:(NSArray *)apiKeyMigrations
                              dataMigrations:(NSArray *)dataMigrations
                           libraryMigrations:(NSArray *)libraryMigrations
{
    self = [super init];
    if (self != nil) {
        _currentSchemeVersion = currentSchemeVersion;
        _schemeMigrations = [schemeMigrations copy];
        _apiKeyMigrations = [apiKeyMigrations copy];
        _dataMigrations = [dataMigrations copy];
        _libraryMigrations = [libraryMigrations copy];
    }
    return self;
}

- (void)applySchemeMigrationsToDatabase:(id<AMADatabaseProtocol>)database isNew:(BOOL)isNew
{
    [database inTransaction:^(AMAFMDatabase *db, AMARollbackHolder *rollbackHolder) {
        id<AMAKeyValueStoring> storage = [database.storageProvider storageForDB:db];
        if (isNew) {
            [storage saveLongLongNumber:@(self.currentSchemeVersion) forKey:kAMADatabaseKeySchemaVersion error:nil];
        }
        else {
            NSNumber *versionNumber = [storage longLongNumberForKey:kAMADatabaseKeySchemaVersion error:nil];
            NSUInteger initialStorageScheme = versionNumber == nil
                ? kAMAInitialSchemeVersion
                : versionNumber.unsignedIntegerValue;
            [self migrateSchemeInDB:db
               initialStorageScheme:initialStorageScheme
                            storage:storage
                           rollback:rollbackHolder];
        }
    }];
}

- (void)migrateSchemeInDB:(AMAFMDatabase *)db
     initialStorageScheme:(NSUInteger)initialStorageScheme
                  storage:(id<AMAKeyValueStoring>)storage
                 rollback:(AMARollbackHolder *)rollbackHolder
{
    if (initialStorageScheme >= self.currentSchemeVersion) {
        AMALogInfo(@"No scheme migration is needed");
        return;
    }

    BOOL result = YES;
    NSUInteger updatedScheme = initialStorageScheme;
    for (AMADatabaseSchemeMigration *migration in self.schemeMigrations) {
        NSParameterAssert(migration.schemeVersion <= self.currentSchemeVersion);

        BOOL shouldMigrate = migration.schemeVersion > initialStorageScheme;

        if (shouldMigrate) {
            result = [migration applyTransactionalMigrationToDatabase:db];
            updatedScheme = migration.schemeVersion;
        }

        if (result == NO) {
            rollbackHolder.rollback = YES;
            AMALogAssert(@"Failed to apply migration: %@", migration);
            return;
        }
    }

    if (updatedScheme != initialStorageScheme) {
        [storage saveLongLongNumber:@(updatedScheme) forKey:kAMADatabaseKeySchemaVersion error:nil];
    }
}

- (void)applyApiKeyMigrationsWithKey:(NSString *)key toDatabase:(id<AMADatabaseProtocol>)database
{
    if (self.apiKeyMigrations.count == 0) {
        AMALogInfo(@"No apiKey migrations for database: %@", database.databasePath);
        return;
    }

    for (id<AMAApiKeyMigration> migration in self.apiKeyMigrations) {
        if ([self shouldPerformSingleRunMigration:migration database:database]) {
            [migration applyMigrationWithApiKey:key toDatabase:database];
            [self finishMigration:migration database:database];
        }
    }
}

- (void)applyDataMigrationsToDatabase:(id<AMADatabaseProtocol>)database
{
    if (self.dataMigrations.count == 0) {
        AMALogInfo(@"No data migrations for database: %@", database.databasePath);
        return;
    }

    for (id<AMADatabaseDataMigration> migration in self.dataMigrations) {
        if ([self shouldPerformSingleRunMigration:migration database:database]) {
            [migration applyMigrationToDatabase:database];
            [self finishMigration:migration database:database];
        }
    }
}

- (void)applyLibraryMigrationsToDatabase:(id<AMADatabaseProtocol>)database
{
    if (self.libraryMigrations.count == 0) {
        AMALogInfo(@"No library migrations for database: %@", database.databasePath);
        return;
    }

    [database inDatabase:^(AMAFMDatabase *db) {
        id<AMAKeyValueStoring> storage = [database.storageProvider storageForDB:db];
        NSString *initialVersion = [storage stringForKey:kAMADatabaseKeyLibraryVersion error:nil];
        NSString *currentVersion = [AMAPlatformDescription SDKVersionName];
        if ([currentVersion isEqualToString:initialVersion]) {
            return;
        }

        for (id<AMALibraryMigration> migration in self.libraryMigrations) {
            if (initialVersion == nil || [initialVersion compare:migration.version options:NSNumericSearch] == NSOrderedAscending) {
                AMALogInfo(@"Migrating library from '%@' to '%@'", initialVersion, migration.version);
                [migration applyMigrationToDatabase:database db:db];
            }
        }
        [storage saveString:currentVersion forKey:kAMADatabaseKeyLibraryVersion error:nil];
    }];
}

- (BOOL)shouldPerformSingleRunMigration:(id<AMANamedMigration>)migration database:(id<AMADatabaseProtocol>)database
{
    NSString *migrationKey = [migration migrationKey];
    BOOL result = migrationKey == nil;
    if (result == NO) {
        result = [database.storageProvider.syncStorage boolNumberForKey:migrationKey error:nil].boolValue == NO;
    }
    return result;
}

- (void)finishMigration:(id<AMANamedMigration>)migration database:(id<AMADatabaseProtocol>)database
{
    NSString *migrationKey = [migration migrationKey];
    if (migrationKey != nil) {
        [database.storageProvider.syncStorage saveBoolNumber:@YES forKey:migrationKey error:nil];
    }
}

#if AMA_ALLOW_DESCRIPTIONS
- (NSString *)description
{
    NSMutableString *description = [NSMutableString stringWithFormat:@"<%@: ", super.description];
    [description appendFormat:@"self.schemeMigrations=%@", self.schemeMigrations];
    [description appendFormat:@", self.apiKeyMigrations=%@", self.apiKeyMigrations];
    [description appendString:@">"];
    return description;
}
#endif

@end
