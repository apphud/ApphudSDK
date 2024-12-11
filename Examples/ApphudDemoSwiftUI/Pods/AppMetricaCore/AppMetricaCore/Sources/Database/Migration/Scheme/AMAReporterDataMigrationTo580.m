
#import <AppMetricaLog/AppMetricaLog.h>
#import "AMAStorageKeys.h"
#import "AMAReporterDataMigrationTo580.h"
#import "AMADatabaseProtocol.h"
#import "AMADatabaseConstants.h"
#import <AppMetricaFMDB/AppMetricaFMDB.h>
#import "AMATableDescriptionProvider.h"
#import "AMAMigrationTo580Utils.h"
#import "AMADatabaseFactory.h"
#import "AMAEventNameHashesStorageFactory.h"

@interface AMAReporterDataMigrationTo580 ()

@property (nonatomic, strong) NSString *apiKey;
@property (nonatomic, assign) BOOL main;

@end

@implementation AMAReporterDataMigrationTo580

- (instancetype)initWithApiKey:(NSString *)apiKey main:(BOOL)main
{
    self = [super init];
    if (self != nil) {
        self.apiKey = apiKey;
        self.main = main;
    }
    return self;
}

- (NSString *)migrationKey
{
    return AMAStorageStringKeyDidApplyDataMigrationFor580;
}

- (void)applyMigrationToDatabase:(id<AMADatabaseProtocol>)database
{
    @synchronized (self) {
        if (self.main) {
            [self migrateReporterIfNeeded:database];
            [self migrateEventHashesIfNeeded:database];
            [self migrateBackupIfNeeded];
        }
    }
}

- (void)migrateReporterIfNeeded:(id<AMADatabaseProtocol>)database
{
    NSString *reporterPath = [[AMAFileUtility persistentPathForApiKey:self.apiKey]
                              stringByAppendingPathComponent:@"data.sqlite"];
    if ([AMAFileUtility fileExistsAtPath:reporterPath]) {
        [self migrateReporterData:reporterPath database:database];
    }
}

- (void)migrateEventHashesIfNeeded:(id<AMADatabaseProtocol>)database
{
    NSString *migrationEventHashesPath = [[AMAFileUtility persistentPathForApiKey:self.apiKey]
                                          stringByAppendingPathComponent:kAMAEventHashesFileName];
    if ([AMAFileUtility fileExistsAtPath:migrationEventHashesPath]) {
        [AMAMigrationTo580Utils migrateReporterEventHashes:self.apiKey];
    }
}

- (void)migrateReporterData:(NSString *)sourceDBPath
                   database:(id<AMADatabaseProtocol>)database
{
    AMAFMDatabase *sourceDB = [AMAFMDatabase databaseWithPath:sourceDBPath];
    
    if ([sourceDB open] == NO) {
        AMALogWarn(@"Failed to open database at path: %@", sourceDBPath);
        return;
    }
    
    NSDictionary *tables = @{
        kAMAKeyValueTableName : [AMATableDescriptionProvider binaryKVTableMetaInfo],
        kAMASessionTableName : [AMATableDescriptionProvider sessionsTableMetaInfo],
    };
    [database inDatabase:^(AMAFMDatabase *db) {
        for (NSString *table in tables) {
            [AMAMigrationTo580Utils migrateTable:table
                                     tableScheme:[tables objectForKey:table]
                                        sourceDB:sourceDB
                                   destinationDB:db];
        }
        [AMAMigrationTo580Utils migrateReporterEvents:sourceDB
                                        destinationDB:db
                                               apiKey:self.apiKey];
        
        [db close];
    }];
    [sourceDB close];
}

- (void)migrateBackupIfNeeded
{
    NSString *reporterBackPath = [[AMAFileUtility persistentPathForApiKey:self.apiKey] 
                                  stringByAppendingPathComponent:@"data.bak"];
    NSString *newDirPath = [[AMAFileUtility persistentPathForApiKey:kAMAMainReporterDBPath]
                            stringByAppendingPathComponent:@"data.bak"];

    if (![AMAFileUtility fileExistsAtPath:reporterBackPath]) {
        return;
    }
    if ([AMAFileUtility fileExistsAtPath:newDirPath]) {
        return;
    }
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;
    if (![fileManager copyItemAtPath:reporterBackPath toPath:newDirPath error:&error]) {
        AMALogWarn(@"Failed to copy reporter backup from %@ to %@: %@", reporterBackPath, newDirPath, error);
    } else {
        AMALogWarn(@"Successfully copied reporter backups from %@ to %@", reporterBackPath, newDirPath);
    }
}

@end
