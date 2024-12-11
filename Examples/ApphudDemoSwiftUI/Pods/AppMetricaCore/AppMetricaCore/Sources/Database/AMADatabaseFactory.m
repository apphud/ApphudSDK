
#import "AMADatabaseFactory.h"
#import "AMADatabase.h"
#import "AMADatabaseConstants.h"
#import "AMAStorageKeys.h"
#import "AMATableSchemeController.h"
#import "AMATableDescriptionProvider.h"
#import "AMADatabaseMigrationManager.h"
#import "AMAStorageTrimManager.h"
#import "AMAKeyValueStorageProvidersFactory.h"
#import "AMABinaryDatabaseKeyValueStorageConverter.h"
#import "AMAStringDatabaseKeyValueStorageConverter.h"
#import "AMADatabaseObjectProvider.h"
#import "AMAProxyDataToStringKVSDataProvider.h"
#import "AMAJSONFileKVSDataProvider.h"

#import "AMAConfigurationDatabaseSchemeMigrationTo2.h"
#import "AMAConfigurationDatabaseSchemeMigrationTo3.h"
#import "AMAConfigurationDatabaseSchemeMigrationTo4.h"
#import "AMAConfigurationDatabaseSchemeMigrationTo5.h"
#import "AMAConfigurationDatabaseSchemeMigrationTo6.h"
#import "AMAConfigurationDatabaseSchemeMigrationTo7.h"
#import "AMAConfigurationDatabaseSchemeMigrationTo8.h"
#import "AMAConfigurationDatabaseSchemeMigrationTo9.h"
#import "AMAConfigurationDatabaseSchemeMigrationTo10.h"
#import "AMAConfigurationDatabaseSchemeMigrationTo11.h"
#import "AMAConfigurationDatabaseSchemeMigrationTo12.h"
#import "AMAConfigurationDatabaseSchemeMigrationTo13.h"
#import "AMAConfigurationDatabaseSchemeMigrationTo14.h"
#import "AMAConfigurationDatabaseSchemeMigrationTo15.h"
#import "AMAConfigurationDatabaseSchemeMigrationTo16.h"
#import "AMAConfigurationDatabaseSchemeMigrationTo17.h"
#import "AMAConfigurationDatabaseSchemeMigrationTo18.h"
#import "AMAConfigurationDatabaseSchemeMigrationTo19.h"
#import "AMAConfigurationDatabaseSchemeMigrationTo20.h"
#import "AMAMigrationTo19FinalizationOnApiKeySpecified.h"
#import "AMALibraryMigration320.h"
#import "AMADataMigrationTo500.h"
#import "AMAReporterDataMigrationTo500.h"
#import "AMALocationDataMigrationTo500.h"
#import "AMADataMigrationTo580.h"
#import "AMAReporterDataMigrationTo580.h"

#import "AMALocationDatabaseSchemeMigrationTo2.h"

#import "AMAReporterDatabaseSchemeMigrationTo2.h"

//1 - initial
//2 - added api_key and type to sessions
//3 - added finished to sessions
//4 - moved location to events, removed from sessions
//5 - added location to errors table
//6 - added server_time_offset to session, event environment
//7 - change api_key type from INTEGER to STRING
//8 - change event environment to error_environment, add app_environment
//9 - change event is_truncated to bytes_truncated
//10 - change session updated_at to last_event_time and pause_time
//11 - move errors table to events table, remov errors table
//12 - move reportsURL into reportHosts
//13 - add location_enabled to events
//14 - add user_profile_id to events
//15 - add encryption_type to events
//16 - add session_id and attribution_id to sessions, add first_occurrence to events
//17 - add startup.had.first to kv
//18 - add global_number and number_of_type to events
//19 - separate storage into api-key specific storages (for reporters) and one shared (for global config)
//20 - change type of columns from STRING to TEXT
static NSUInteger const kAMAConfigurationDatabaseSchemaVersion = 20;

//1 - initial
//2 - change type of columns from STRING to TEXT
static NSUInteger const kAMAReporterDatabaseSchemaVersion = 2;

//1 - initial
//2 - change type of columns from STRING to TEXT
//~ - add `visit` table. No migration needed, because new tables are created automatically
static NSUInteger const kAMALocationDatabaseSchemaVersion = 2;

NSString *const kAMAMainReporterDBPath = @"main";

@implementation AMADatabaseFactory

+ (id<AMADatabaseProtocol>)configurationDatabase
{
    NSString *databasePath = [self configurationDatabasePath];
    AMATableSchemeController *tableSchemeController = [[AMATableSchemeController alloc] initWithTableSchemes:@{
        kAMAKeyValueTableName: [AMATableDescriptionProvider stringKVTableMetaInfo],
    }];
    NSArray *schemeMigrations = @[
        [AMAConfigurationDatabaseSchemeMigrationTo2 new],
        [AMAConfigurationDatabaseSchemeMigrationTo3 new],
        [AMAConfigurationDatabaseSchemeMigrationTo4 new],
        [AMAConfigurationDatabaseSchemeMigrationTo5 new],
        [AMAConfigurationDatabaseSchemeMigrationTo6 new],
        [AMAConfigurationDatabaseSchemeMigrationTo7 new],
        [AMAConfigurationDatabaseSchemeMigrationTo8 new],
        [AMAConfigurationDatabaseSchemeMigrationTo9 new],
        [AMAConfigurationDatabaseSchemeMigrationTo10 new],
        [AMAConfigurationDatabaseSchemeMigrationTo11 new],
        [AMAConfigurationDatabaseSchemeMigrationTo12 new],
        [AMAConfigurationDatabaseSchemeMigrationTo13 new],
        [AMAConfigurationDatabaseSchemeMigrationTo14 new],
        [AMAConfigurationDatabaseSchemeMigrationTo15 new],
        [AMAConfigurationDatabaseSchemeMigrationTo16 new],
        [AMAConfigurationDatabaseSchemeMigrationTo17 new],
        [AMAConfigurationDatabaseSchemeMigrationTo18 new],
        [AMAConfigurationDatabaseSchemeMigrationTo19 new],
        [AMAConfigurationDatabaseSchemeMigrationTo20 new],
    ];
    NSArray *apiKeyMigrations = @[
        [AMAMigrationTo19FinalizationOnApiKeySpecified new],
    ];
    NSArray *dataMigrations = @[
        [AMADataMigrationTo500 new],
        [AMADataMigrationTo580 new],
    ];
    NSArray *libraryMigrations = @[
        [AMALibraryMigration320 new],
    ];
    AMADatabaseMigrationManager *migrationManager =
        [[AMADatabaseMigrationManager alloc] initWithCurrentSchemeVersion:kAMAConfigurationDatabaseSchemaVersion
                                                         schemeMigrations:schemeMigrations
                                                         apiKeyMigrations:apiKeyMigrations
                                                           dataMigrations:dataMigrations
                                                        libraryMigrations:libraryMigrations];
   
    id<AMAKeyValueStorageConverting> keyValueStorageConverter =
        [[AMAStringDatabaseKeyValueStorageConverter alloc] init];

    NSString *backupTag = @"storage.bak";
    id<AMAKeyValueStorageDataProviding> backingDataProvider =
#if TARGET_OS_TV
        [self backingDataProviderWithSuiteNamePostfix:backupTag];
#else
        [self backingDataProviderWithPath:[AMAFileUtility.persistentPath stringByAppendingPathComponent:backupTag]];
#endif
    
    id<AMADatabaseKeyValueStorageProviding> storageProvider =
        [AMAKeyValueStorageProvidersFactory databaseProviderForTableName:kAMAKeyValueTableName
                                                               converter:keyValueStorageConverter
                                                          objectProvider:[AMADatabaseObjectProvider blockForStrings]
                                                  backingKVSDataProvider:backingDataProvider];
    
    NSArray *const kCriticalKVKeys = @[ AMAStorageStringKeyUUID ];
    
    [storageProvider addBackingKeys:kCriticalKVKeys];
    
    id<AMADatabaseProtocol> database = [[AMADatabase alloc] initWithTableSchemeController:tableSchemeController
                                                                             databasePath:databasePath
                                                                         migrationManager:migrationManager
                                                                              trimManager:nil
                                                                  keyValueStorageProvider:storageProvider
                                                                     criticalKeyValueKeys:kCriticalKVKeys];
    [storageProvider setDatabase:database];
    return database;
}

+ (NSString *)configurationDatabasePath
{
    NSString *basePath = AMAFileUtility.persistentPath;
    return [basePath stringByAppendingPathComponent:@"storage.sqlite"];
}

+ (id<AMADatabaseProtocol>)reporterDatabaseForApiKey:(NSString *)apiKey
                                                main:(BOOL)main
                                       eventsCleaner:(AMAEventsCleaner *)eventsCleaner
{
    NSString *dirPath = main ? kAMAMainReporterDBPath : apiKey;
    NSString *basePath = [AMAFileUtility persistentPathForApiKey:dirPath];
    NSString *databasePath = [basePath stringByAppendingPathComponent:@"data.sqlite"];
    AMATableSchemeController *tableSchemeController = [[AMATableSchemeController alloc] initWithTableSchemes:@{
        kAMAEventTableName: [AMATableDescriptionProvider eventsTableMetaInfo],
        kAMASessionTableName: [AMATableDescriptionProvider sessionsTableMetaInfo],
        kAMAKeyValueTableName: [AMATableDescriptionProvider binaryKVTableMetaInfo],
    }];
    NSArray *schemeMigrations = @[
        [AMAReporterDatabaseSchemeMigrationTo2 new],
    ];
    NSArray *apiKeyMigrations = @[
    ];
    NSArray *dataMigrations = @[
        [[AMAReporterDataMigrationTo500 alloc] initWithApiKey:apiKey],
        [[AMAReporterDataMigrationTo580 alloc] initWithApiKey:apiKey main:main],
    ];
    NSArray *libraryMigrations = @[
    ];
    AMADatabaseMigrationManager *migrationManager =
        [[AMADatabaseMigrationManager alloc] initWithCurrentSchemeVersion:kAMAReporterDatabaseSchemaVersion
                                                         schemeMigrations:schemeMigrations
                                                         apiKeyMigrations:apiKeyMigrations
                                                           dataMigrations:dataMigrations
                                                        libraryMigrations:libraryMigrations];
    AMAStorageTrimManager *trimManager = [[AMAStorageTrimManager alloc] initWithApiKey:apiKey
                                                                         eventsCleaner:eventsCleaner];
    id<AMAKeyValueStorageConverting> keyValueStorageConverter =
        [[AMABinaryDatabaseKeyValueStorageConverter alloc] init];

    id<AMAKeyValueStorageDataProviding> backingDataProvider =
#if TARGET_OS_TV
        [self backingDataProviderWithSuiteNamePostfix:[dirPath stringByAppendingString:@".bak"]];
#else
        [self backingDataProviderWithPath:[basePath stringByAppendingPathComponent:@"data.bak"]];
    backingDataProvider =
        [[AMAProxyDataToStringKVSDataProvider alloc] initWithUnderlyingDataProvider:backingDataProvider];
#endif

    id<AMADatabaseKeyValueStorageProviding> storageProvider =
        [AMAKeyValueStorageProvidersFactory databaseProviderForTableName:kAMAKeyValueTableName
                                                               converter:keyValueStorageConverter
                                                          objectProvider:[AMADatabaseObjectProvider blockForDataBlobs]
                                                  backingKVSDataProvider:backingDataProvider];
    id<AMADatabaseProtocol> database = [[AMADatabase alloc] initWithTableSchemeController:tableSchemeController
                                                                             databasePath:databasePath
                                                                         migrationManager:migrationManager
                                                                              trimManager:trimManager
                                                                  keyValueStorageProvider:storageProvider
                                                                     criticalKeyValueKeys:@[]];
    [storageProvider setDatabase:database];
    return database;
}

+ (id<AMADatabaseProtocol>)locationDatabase
{
    NSString *basePath = AMAFileUtility.persistentPath;
    NSString *databasePath = [basePath stringByAppendingPathComponent:@"l_data.sqlite"];
    AMATableSchemeController *tableSchemeController = [[AMATableSchemeController alloc] initWithTableSchemes:@{
        kAMALocationsTableName: [AMATableDescriptionProvider locationsTableMetaInfo],
        kAMALocationsVisitsTableName: [AMATableDescriptionProvider visitsTableMetaInfo],
        kAMAKeyValueTableName: [AMATableDescriptionProvider stringKVTableMetaInfo],
    }];
    NSArray *schemeMigrations = @[
        [AMALocationDatabaseSchemeMigrationTo2 new],
    ];
    NSArray *apiKeyMigrations = @[
    ];
    NSArray *dataMigrations = @[
        [AMALocationDataMigrationTo500 new],
    ];
    NSArray *libraryMigrations = @[
    ];
    AMADatabaseMigrationManager *migrationManager =
        [[AMADatabaseMigrationManager alloc] initWithCurrentSchemeVersion:kAMALocationDatabaseSchemaVersion
                                                         schemeMigrations:schemeMigrations
                                                         apiKeyMigrations:apiKeyMigrations
                                                           dataMigrations:dataMigrations
                                                        libraryMigrations:libraryMigrations];
    id<AMAKeyValueStorageConverting> keyValueStorageConverter =
        [[AMAStringDatabaseKeyValueStorageConverter alloc] init];

    NSString *backupTag = @"l_data.bak";
    id<AMAKeyValueStorageDataProviding> backingDataProvider =
#if TARGET_OS_TV
        [self backingDataProviderWithSuiteNamePostfix:backupTag];
#else
        [self backingDataProviderWithPath:[basePath stringByAppendingPathComponent:backupTag]];
#endif
    
    id<AMADatabaseKeyValueStorageProviding> storageProvider =
        [AMAKeyValueStorageProvidersFactory databaseProviderForTableName:kAMAKeyValueTableName
                                                               converter:keyValueStorageConverter
                                                          objectProvider:[AMADatabaseObjectProvider blockForStrings]
                                                  backingKVSDataProvider:backingDataProvider];
    id<AMADatabaseProtocol> database = [[AMADatabase alloc] initWithTableSchemeController:tableSchemeController
                                                                             databasePath:databasePath
                                                                         migrationManager:migrationManager
                                                                              trimManager:nil
                                                                  keyValueStorageProvider:storageProvider
                                                                     criticalKeyValueKeys:@[]];
    [storageProvider setDatabase:database];
    return database;
}

#if TARGET_OS_TV

+ (id<AMAKeyValueStorageDataProviding>)backingDataProviderWithSuiteNamePostfix:(NSString *)suiteNamePostfix
{
    NSString *suiteName = [@"io.appmetrica." stringByAppendingString:suiteNamePostfix];
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:suiteName];
    return [[AMAUserDefaultsKVSDataProvider alloc] initWithUserDefaults:defaults];
}

#else

+ (id<AMAKeyValueStorageDataProviding>)backingDataProviderWithPath:(NSString *)path
{
    AMADiskFileStorageOptions options = AMADiskFileStorageOptionCreateDirectory | AMADiskFileStorageOptionNoBackup;
    AMADiskFileStorage *fileStorage = [[AMADiskFileStorage alloc] initWithPath:path options:options];
    AMAJSONFileKVSDataProvider *jsonDataProvider = [[AMAJSONFileKVSDataProvider alloc] initWithFileStorage:fileStorage];
    return jsonDataProvider;
}

#endif

@end
