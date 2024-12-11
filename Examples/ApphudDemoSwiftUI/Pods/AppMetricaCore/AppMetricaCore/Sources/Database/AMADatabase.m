
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>
#import "AMADatabase.h"
#import "AMADatabaseConstants.h"
#import "AMATableSchemeController.h"
#import "AMADatabaseMigrationManager.h"
#import "AMAStorageTrimManager.h"
#import "AMADatabaseQueueProvider.h"
#import "AMADatabaseIntegrityManager.h"
#import "AMADatabaseHelper.h"
#import <AppMetricaFMDB/AppMetricaFMDB.h>

@interface AMADatabase () <AMADatabaseIntegrityManagerDelegate>

@property (nonatomic, strong, readonly) AMATableSchemeController *tableSchemeController;
@property (nonatomic, strong, readonly) AMADatabaseMigrationManager *migrationManager;
@property (nonatomic, strong, readonly) AMAStorageTrimManager *trimManager;
@property (nonatomic, strong, readonly) AMADatabaseIntegrityManager *integrityManager;
@property (nonatomic, copy, readonly) NSArray<NSString *> *criticalKeyValueKeys;
@property (nonatomic, strong, readonly) NSMutableArray *delayedBlocks;

@property (nonatomic, strong) AMAFMDatabaseQueue *dbQueue;
@property (nonatomic, assign) AMADatabaseType databaseType;

@end

@implementation AMADatabase

@synthesize databasePath = _databasePath;
@synthesize storageProvider = _storageProvider;

- (instancetype)initWithTableSchemeController:(AMATableSchemeController *)tableSchemeController
                                 databasePath:(NSString *)databasePath
                             migrationManager:(AMADatabaseMigrationManager *)migrationManager
                                  trimManager:(AMAStorageTrimManager *)trimManager
                      keyValueStorageProvider:(id<AMADatabaseKeyValueStorageProviding>)keyValueStorageProvider
                         criticalKeyValueKeys:(NSArray<NSString *> *)criticalKeyValueKeys
{
    self = [super init];
    if (self != nil) {
        _tableSchemeController = tableSchemeController;
        _databasePath = [databasePath copy];
        _migrationManager = migrationManager;
        _trimManager = trimManager;
        _storageProvider = keyValueStorageProvider;
        _criticalKeyValueKeys = criticalKeyValueKeys;
        _delayedBlocks = [NSMutableArray array];
        _integrityManager = [[AMADatabaseIntegrityManager alloc] initWithDatabasePath:databasePath];
        _integrityManager.delegate = self;
    }
    return self;
}

- (void)dealloc
{
    [_trimManager unsubscribeDatabase:self];
    [_dbQueue close];
}

#pragma mark - Public -

- (void)ensureMigrated
{
    [self inOpenedDatabase:^{
        AMALogInfo(@"Migration ensured: %@", self.databasePath);
    }];
}

- (void)migrateToMainApiKey:(NSString *)apiKey
{
    [self.migrationManager applyApiKeyMigrationsWithKey:apiKey toDatabase:self];
}

- (void)inDatabase:(void (^)(AMAFMDatabase *db))block
{
    [self inOpenedDatabase:^{
        [self.dbQueue inDatabase:block];
    }];
}

- (void)inTransaction:(void (^)(AMAFMDatabase *db, AMARollbackHolder *rollbackHolder))block
{
    [self inOpenedDatabase:^{
        [self.dbQueue inExclusiveTransaction:^(AMAFMDatabase *db, BOOL *rollback) {
            if (block != nil) {
                AMARollbackHolder *rollbackHolder = [[AMARollbackHolder alloc] init];
                block(db, rollbackHolder);
                if (rollbackHolder.rollback) {
                    *rollback = YES;
                }
                [rollbackHolder complete];
            }
        }];
    }];
}

- (void)executeWhenOpen:(dispatch_block_t)block
{
    if (block == nil) {
        return;
    }
    @synchronized (self) {
        if (self.dbQueue != nil) {
            block();
        }
        else {
            [self.delayedBlocks addObject:block];
        }
    }
}

- (NSString *)detectedInconsistencyDescription
{
    return [self.storageProvider.syncStorage stringForKey:kAMADatabaseKeyInconsistentDatabaseDetectedSchema
                                                    error:nil];
}

- (void)resetDetectedInconsistencyDescription
{
    [self.storageProvider.syncStorage saveString:nil
                                          forKey:kAMADatabaseKeyInconsistentDatabaseDetectedSchema
                                           error:nil];
}

#pragma mark - Private -

- (void)openDatabaseWithIsNew:(BOOL *)isNew
{
    self.dbQueue = [self.integrityManager databaseWithEnsuredIntegrityWithIsNew:isNew];

    if (self.dbQueue == nil) {
        self.dbQueue = [[AMADatabaseQueueProvider sharedInstance] inMemoryQueue];
        self.databaseType = AMADatabaseTypeInMemory;
    } else {
        self.databaseType = AMADatabaseTypePersistent;
    }

    [self.trimManager subscribeDatabase:self];

    if (self.dbQueue == nil) {
        AMALogAssert(@"Failed to open database");
    }
}

- (void)createSchema
{
    // No error checking so far.
    // Bad progammer, no cookie.
    [self.dbQueue inDatabase:^(AMAFMDatabase *db) {
        [self.tableSchemeController createSchemaInDB:db];
    }];
}

- (void)enforceDatabaseConsistency
{
    [self inDatabase:^(AMAFMDatabase *db) {
        [self.tableSchemeController enforceDatabaseConsistencyInDB:db onInconsistency:^(dispatch_block_t fix) {
            NSString *databaseSchemaDescription = [self extractDatabaseSchemaInfo:db];
            AMALogError(@"Dropping tables, database inconsistent %@", databaseSchemaDescription);
            id<AMAKeyValueStoring> savedStorage = [self criticalValuesStorageForDB:db];

            fix();

            [self restoreCriticalValuesFromStorage:savedStorage inDB:db];
            [[self.storageProvider storageForDB:db] saveString:databaseSchemaDescription
                                                        forKey:kAMADatabaseKeyInconsistentDatabaseDetectedSchema
                                                         error:nil];
        }];
    }];
}

- (id<AMAKeyValueStoring>)criticalValuesStorageForDB:(AMAFMDatabase *)db
{
    if (self.criticalKeyValueKeys.count == 0) {
        return nil;
    }
    return [self.storageProvider nonPersistentStorageForKeys:self.criticalKeyValueKeys
                                                          db:db
                                                       error:nil];
}

- (void)restoreCriticalValuesFromStorage:(id<AMAKeyValueStoring>)storage inDB:(AMAFMDatabase *)db
{
    if (storage == nil) {
        return;
    }
    [self.storageProvider saveStorage:storage db:db error:nil];
}

- (NSString *)extractDatabaseSchemaInfo:(AMAFMDatabase *)db
{
    NSArray *tablesDescription = [AMADatabaseHelper eachResultsDescription:[db getSchema]];

    NSArray *tablesNames = self.tableSchemeController.tableNames;
    NSArray *tablesSchemes = [AMACollectionUtilities mapArray:tablesNames withBlock:^(NSString *tableName) {
        NSArray *tableDescr = [AMADatabaseHelper eachResultsDescription:[db getTableSchema:tableName]];
        return @{ tableName : tableDescr };
    }];
    return [NSString stringWithFormat:@"db schema: %@, tables: %@", tablesDescription, tablesSchemes];
}

- (void)inOpenedDatabase:(dispatch_block_t)block
{
    NSArray *delayedBlocks = nil;
    if (block != nil) {
        @synchronized(self) {
            if (self.dbQueue == nil) {
                BOOL isNew = NO;
                [self openDatabaseWithIsNew:&isNew];
                [self createSchema];
                [self.migrationManager applySchemeMigrationsToDatabase:self isNew:isNew];
                [self.migrationManager applyDataMigrationsToDatabase:self];
                [self.migrationManager applyLibraryMigrationsToDatabase:self];
                [self enforceDatabaseConsistency];

                delayedBlocks = [self.delayedBlocks copy];
                [self.delayedBlocks removeAllObjects];
            }
            block();
        }
    }

    for (dispatch_block_t delayedBlock in delayedBlocks) {
        delayedBlock();
    }
}

#pragma mark - AMADatabaseIntegrityManagerDelegate -

- (id)contextForIntegrityManager:(AMADatabaseIntegrityManager *)manager
            thatWillDropDatabase:(AMAFMDatabaseQueue *)database
{
    id<AMAKeyValueStoring> __block savedStorage = nil;
    [database inDatabase:^(AMAFMDatabase *db) {
        savedStorage = [self criticalValuesStorageForDB:db];
    }];
    return savedStorage;
}

- (void)integrityManager:(AMADatabaseIntegrityManager *)manager
    didCreateNewDatabase:(AMAFMDatabaseQueue *)database
                 context:(id<AMAKeyValueStoring>)context
{
    if (context == nil) {
        return;
    }
    [database inDatabase:^(AMAFMDatabase *db) {
        [self restoreCriticalValuesFromStorage:context inDB:db];
    }];
}

@end
