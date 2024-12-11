
#import "AMAMigrationTo500Utils.h"
#import "AMATableDescriptionProvider.h"
#import "AMAStorageKeys.h"
#import "AMADatabaseProtocol.h"
#import "AMADatabaseConstants.h"
#import <AppMetricaFMDB/AppMetricaFMDB.h>
#import "AMADatabaseHelper.h"
#import "AMAReporterStoragesContainer.h"
#import "AMAReporterStorage.h"
#import "AMAEvent.h"
#import "AMALegacyEventExtrasProvider.h"
#import "AMAKeychainBridge.h"
#import "AMAKeychain.h"
#import "AMAMetricaConfiguration.h"
#import "AMAMetricaPersistentConfiguration.h"
#import "AMAEventNameHashesStorage.h"
#import "AMAEventStorage+Migration.h"
#import "AMAEventSerializer+Migration.h"
#import "AMAInstantFeaturesConfiguration+Migration.h"
#import "AMAEventNameHashesStorageFactory+Migration.h"
#import "AMAReporterDatabaseEncodersFactory+Migration.h"
#import "AMALocationEncoderFactory+Migration.h"
#import "AMAMetricaPersistentConfiguration.h"
#import "AMAFallbackKeychain.h"
#import <AppMetricaPlatform/AppMetricaPlatform.h>
#import "AMAKeyValueStorageProvidersFactory.h"
#import "AMADatabaseObjectProvider.h"
#import "AMAStringDatabaseKeyValueStorageConverter.h"
#import "AMAJSONFileKVSDataProvider.h"

NSString *const kAMAMigrationBundle = @"ru.yandex.mobile.YandexMobileMetrica";

NSString *const kAMAMigrationKeychainAccessGroup = @"com.yandex.mobile.appmetrica";
NSString *const kAMAMigrationKeychainAppServiceIdentifier = @"com.yandex.mobile.appmetrica.service.application";
NSString *const kAMAMigrationKeychainVendorServiceIdentifier = @"com.yandex.mobile.appmetrica.service.vendor";

NSString *const kAMAMigrationDeviceIDStorageKey = @"YMMMetricaPersistentConfigurationDeviceIDStorageKey";
NSString *const kAMAMigrationDeviceIDHashStorageKey = @"YMMMetricaPersistentConfigurationDeviceIDHashStorageKey";

@implementation AMAMigrationTo500Utils

+ (NSString *)migrationPath
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *basePath = [paths firstObject];
    NSString *path = [basePath stringByAppendingPathComponent:kAMAMigrationBundle];
    return path;
}

+ (void)migrateTable:(NSString *)tableName
         tableScheme:(NSArray *)tableScheme
            sourceDB:(AMAFMDatabase *)sourceDB
       destinationDB:(AMAFMDatabase *)destinationDB
{
    NSMutableArray *columns = [NSMutableArray array];
    NSMutableArray *valueQuestions = [NSMutableArray array];
    for (NSDictionary *field in tableScheme) {
        [columns addObject:field[kAMASQLName]];
        [valueQuestions addObject:@"?"];
    }
    NSString *joined = [columns componentsJoinedByString:@", "];
    NSString *selectQuery = [NSString stringWithFormat:@"SELECT %@ FROM %@;", joined, tableName];
    AMAFMResultSet *resultSet = [sourceDB executeQuery:selectQuery];
    
    NSString *insertQuery = [NSString stringWithFormat:@"INSERT INTO %@ (%@) VALUES (%@);",
                             tableName, joined, [valueQuestions componentsJoinedByString:@", "]];
    
    while ([resultSet next]) {
        NSNumber *encryptionValue = nil;
        
        NSMutableArray *columnValues = [NSMutableArray array];
        for (NSString *columnName in columns) {
            id columnValue = [resultSet objectForColumn:columnName];
            
            if ([columnName isEqual:kAMACommonTableFieldDataEncryptionType]) {
                encryptionValue = columnValue;
            }
            else if ([columnName isEqual:kAMACommonTableFieldData]) {
                columnValue = [self migrationDataForTable:tableName data:columnValue encryptionValue:encryptionValue];
            }
            
            columnValue = [self fallbackKeychainMapping][columnValue] ?: columnValue;
            
            [columnValues addObject:(columnValue ?: [NSNull null])];
        }
        
        BOOL insertSuccess = [destinationDB executeUpdate:insertQuery withArgumentsInArray:columnValues];
        if (insertSuccess == NO) {
            AMALogWarn(@"Failed to insert values into table at path: %@ error: %@",
                       destinationDB.databasePath, [destinationDB lastErrorMessage]);
        }
    }
    [resultSet close];
}

+ (void)migrateReporterEvents:(AMAFMDatabase *)sourceDB
                destinationDB:(AMAFMDatabase *)destinationDB
                       apiKey:(NSString *)apiKey
{
    AMAEventSerializer *migrationSerializer = [[AMAEventSerializer alloc] migrationInit];
    
    NSArray<AMAEvent*> *reporterEvents = [self getEventsInDB:sourceDB eventSerializer:migrationSerializer];
    
    NSString *legacyExtrasKey = @"ai";
    NSData *legacyExtras = [AMALegacyEventExtrasProvider legacyExtrasData:sourceDB];

    if (legacyExtras != nil) {
        [self addExtrasToEvents:reporterEvents extras:@{ legacyExtrasKey : legacyExtras }];

        id<AMAAppMetricaExtendedReporting> reporter = [AMAAppMetrica extendedReporterForApiKey:apiKey];
        [reporter setSessionExtras:legacyExtras forKey:legacyExtrasKey];
    }
    
    [self saveReporterEvents:reporterEvents apiKey:apiKey db:destinationDB];
}

+ (void)migrateReporterEventHashes:(NSString *)migrationPath apiKey:(NSString *)apiKey
{
    AMAEventNameHashesStorage *migrationStorage = [AMAEventNameHashesStorageFactory migrationStorageForPath:migrationPath];
    AMAEventNameHashesStorage *currentStorage = [AMAEventNameHashesStorageFactory storageForApiKey:apiKey main:NO];
    AMAEventNameHashesCollection *oldCollection = [migrationStorage loadCollection];
    BOOL result = [currentStorage saveCollection:oldCollection];
    if (result == NO) {
        AMALogError(@"Failed to save event hashes collection for apiKey: %@", apiKey);
    }
}

+ (void)migrateDeviceIDFromDB:(AMAFMDatabase *)db
{
    id<AMADatabaseKeyValueStorageProviding> storageProvider = [self dataStorageProviderForPath:[self migrationPath]];
    id<AMAKeyValueStoring> migrationStorage = [storageProvider storageForDB:db];
    AMAFallbackKeychain *keychain = [self migrationKeychainStorageWithKVStorage:migrationStorage];
    
    NSString *storageDeviceID = [keychain stringValueForKey:kAMAMigrationDeviceIDStorageKey error:nil];
    if (storageDeviceID.length > 0) {
        [[AMAMetricaConfiguration sharedInstance].persistent setDeviceID:storageDeviceID];
    }
    
    NSString *deviceIDHash = [keychain stringValueForKey:kAMAMigrationDeviceIDHashStorageKey error:nil];
    if (deviceIDHash.length != 0) {
        [[AMAMetricaConfiguration sharedInstance].persistent setDeviceIDHash:deviceIDHash];
    }
}

+ (void)migrateUUID
{
    AMAInstantFeaturesConfiguration *migrationConfiguration = [AMAInstantFeaturesConfiguration migrationInstance];
    AMAInstantFeaturesConfiguration *currentConfiguration = [AMAInstantFeaturesConfiguration sharedInstance];
    
    NSString *uuid = [migrationConfiguration UUID];
    
    if (uuid != nil) {
        [currentConfiguration setUUID:uuid];
    }
}

#pragma mark - Private -

+ (NSData *)migrationDataForTable:(NSString *)tableName
                             data:(NSData *)data
                  encryptionValue:(NSNumber *)encryptionValue
{
    NSData *encryptedData = nil;
    if ([tableName isEqual:kAMALocationsTableName] || [tableName isEqual:kAMALocationsVisitsTableName]) {
        encryptedData = [self locationMigrationData:data];
    }
    else {
        encryptedData = [self reporterMigrationData:data encryptionValue:encryptionValue];
    }
    return encryptedData;
}

+ (NSData *)reporterMigrationData:(NSData *)data encryptionValue:(NSNumber *)encryptionValue
{
    AMAReporterDatabaseEncryptionType encryptionType = (AMAReporterDatabaseEncryptionType)[encryptionValue unsignedIntegerValue];
    
    id<AMADataEncoding> migrationEncoder = [AMAReporterDatabaseEncodersFactory migrationEncoderForEncryptionType:encryptionType];
    NSData *decodedWithOldEncrypterData = [migrationEncoder decodeData:data error:nil];
    
    id<AMADataEncoding> encoder = [AMAReporterDatabaseEncodersFactory encoderForEncryptionType:encryptionType];
    NSData *encodedWithNewEncrypterData = [encoder encodeData:decodedWithOldEncrypterData error:nil];
    
    return encodedWithNewEncrypterData;
}

+ (NSData *)locationMigrationData:(NSData *)data
{
    id<AMADataEncoding> migrationEncoder = [AMALocationEncoderFactory migrationEncoder];
    NSData *decodedWithOldEncrypterData = [migrationEncoder decodeData:data error:nil];
    
    id<AMADataEncoding> encoder = [AMALocationEncoderFactory encoder];
    NSData *encodedWithNewEncrypterData = [encoder encodeData:decodedWithOldEncrypterData error:nil];
    
    return encodedWithNewEncrypterData;
}

#pragma mark - Events Migration -

+ (NSArray<AMAEvent*> *)getEventsInDB:(AMAFMDatabase *)db
                      eventSerializer:(AMAEventSerializer *)eventSerializer
{
    NSMutableArray *result = [NSMutableArray array];
    NSError *error = nil;
    [AMADatabaseHelper enumerateRowsWithFilter:nil
                                         order:nil
                                   valuesArray:@[]
                                     tableName:kAMAEventTableName
                                         limit:INT_MAX
                                            db:db
                                         error:&error
                                         block:^(NSDictionary *dictionary) {
        NSError *deserializationError = nil;
        AMAEvent *event = [eventSerializer eventForDictionary:dictionary error:&deserializationError];
        if (deserializationError != nil) {
            AMALogInfo(@"Deserialization error: %@", deserializationError);
        }
        else if (event != nil) {
            [result addObject:event];
        }
    }];
    if (error != nil) {
        AMALogInfo(@"Error: %@", error);
    }
    return [result copy];
}

+ (BOOL)saveReporterEvents:(NSArray<AMAEvent*> *)events
                    apiKey:(NSString *)apiKey
                        db:(AMAFMDatabase *)db
{
    AMAReporterStoragesContainer *container = [AMAReporterStoragesContainer sharedInstance];
    AMAReporterStorage *reporterStorage = [container storageForApiKey:apiKey];
    if (reporterStorage == nil) {
        AMALogError(@"Failed to create storage for apiKey: %@", apiKey);
        return NO;
    }
    BOOL __block result = NO;
    for (AMAEvent *event in events) {
        result = [reporterStorage.eventStorage addEvent:event db:db error:nil];
    }
    return result;
}

+ (void)addExtrasToEvents:(NSArray<AMAEvent*> *)events
                   extras:(NSDictionary *)extras
{
    if (extras == nil) {
        return;
    }
    for (AMAEvent *event in events) {
        NSMutableDictionary *eventExtras = [NSMutableDictionary dictionary];
        if (event.extras != nil) {
            [eventExtras addEntriesFromDictionary:event.extras];
        }
        [eventExtras addEntriesFromDictionary:extras];
        event.extras = eventExtras;
    }
}

#pragma mark - Keychain Migration -

+ (id<AMAKeychainStoring>)migrationKeychainStorageWithKVStorage:(id<AMAKeyValueStoring>)storage
{
    AMAKeychainBridge *keychainBridge = [[AMAKeychainBridge alloc] init];
    AMAKeychain *appKeychain = [[AMAKeychain alloc] initWithService:kAMAMigrationKeychainAppServiceIdentifier
                                                        accessGroup:@""
                                                             bridge:keychainBridge];
    AMAKeychain *vendorKeychain = [self vendorMigrationKeychainWithBridge:keychainBridge];
    
    id<AMAKeychainStoring> keychain = [[AMAFallbackKeychain alloc] initWithStorage:storage
                                                                      mainKeychain:appKeychain
                                                                  fallbackKeychain:vendorKeychain];
    return keychain;
}

+ (AMAKeychain *)vendorMigrationKeychainWithBridge:(AMAKeychainBridge *)keychainBridge
{
    NSString *appIdentifier = [AMAPlatformDescription appIdentifierPrefix];
    if (appIdentifier.length == 0) {
        return nil;
    }
    
    NSString *accessGroup = [appIdentifier stringByAppendingString:kAMAMigrationKeychainAccessGroup];
    AMAKeychain *migrationVendorKeychain = [[AMAKeychain alloc] initWithService:kAMAMigrationKeychainVendorServiceIdentifier
                                                                    accessGroup:accessGroup
                                                                         bridge:keychainBridge];
    if (migrationVendorKeychain.isAvailable == NO) {
        return nil;
    }

    return migrationVendorKeychain;
}

+ (id<AMADatabaseKeyValueStorageProviding>)dataStorageProviderForPath:(NSString *)path
{
    NSString *backupTag = @"storage.bak";
    id<AMAKeyValueStorageDataProviding> backingDataProvider =
#if TARGET_OS_TV
    [self backingDataProviderWithSuiteNamePostfix:backupTag];
#else
    [self backingDataProviderWithPath:[path stringByAppendingPathComponent:backupTag]];
#endif
    
    id<AMAKeyValueStorageConverting> keyValueStorageConverter =
        [[AMAStringDatabaseKeyValueStorageConverter alloc] init];
    
    id<AMADatabaseKeyValueStorageProviding> storageProvider =
        [AMAKeyValueStorageProvidersFactory databaseProviderForTableName:kAMAKeyValueTableName
                                                               converter:keyValueStorageConverter
                                                          objectProvider:[AMADatabaseObjectProvider blockForStrings]
                                                  backingKVSDataProvider:backingDataProvider];
    
    NSArray *const kCriticalKVKeys = @[ AMAStorageStringKeyUUID ];
    
    [storageProvider addBackingKeys:kCriticalKVKeys];
    
    return storageProvider;
}

#if TARGET_OS_TV

+ (id<AMAKeyValueStorageDataProviding>)backingDataProviderWithSuiteNamePostfix:(NSString *)suiteNamePostfix
{
    NSString *suiteName = [@"ru.yandex.mobile.YandexMobileMetrica." stringByAppendingString:suiteNamePostfix];
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

+ (NSDictionary *)fallbackKeychainMapping
{
    NSString *format = @"fallback-keychain-%@";
    return @{
        [NSString stringWithFormat:format, kAMAMigrationDeviceIDStorageKey]: [NSString stringWithFormat:format, kAMADeviceIDStorageKey],
        [NSString stringWithFormat:format, kAMAMigrationDeviceIDHashStorageKey]: [NSString stringWithFormat:format, kAMADeviceIDHashStorageKey]
    };
}

#pragma mark - Crash reports

+ (NSString *)crashReportsWithBundleName:(NSString *)bundleName
{
    NSArray *cachePaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cachePath = [cachePaths firstObject];
    NSString *directoryName = [bundleName stringByAppendingString:@".CrashReports"];
    return [cachePath stringByAppendingPathComponent:directoryName];
}

+ (void)migrateCrashReportsIfNeeded
{
    NSString *oldDirectoryPath = [self crashReportsWithBundleName:kAMAMigrationBundle];
    NSString *newDirectoryPath = [self crashReportsWithBundleName:[AMAPlatformDescription SDKBundleName]];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];

    if (![fileManager fileExistsAtPath:oldDirectoryPath]) {
        AMALogWarn(@"There are no migration crash reports found");
        return;
    }

    if ([fileManager fileExistsAtPath:newDirectoryPath]) {
        AMALogWarn(@"New crash reports directory already exists");
        return;
    }

    NSError *error;
    if (![fileManager moveItemAtPath:oldDirectoryPath toPath:newDirectoryPath error:&error]) {
        AMALogWarn(@"Failed to move crash reports from %@ to %@: %@", oldDirectoryPath, newDirectoryPath, error);
    } else {
        AMALogWarn(@"Successfully moved crash reports from %@ to %@", oldDirectoryPath, newDirectoryPath);
        [AMAFileUtility deleteFileAtPath:oldDirectoryPath];
    }
}

@end
