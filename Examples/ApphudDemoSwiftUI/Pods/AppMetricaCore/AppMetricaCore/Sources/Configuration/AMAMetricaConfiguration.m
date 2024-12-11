
#import <AppMetricaStorageUtils/AppMetricaStorageUtils.h>
#import <AppMetricaPlatform/AppMetricaPlatform.h>
#import "AMAMetricaConfiguration.h"
#import "AMAMetricaInMemoryConfiguration.h"
#import "AMAInstantFeaturesConfiguration.h"
#import "AMAMetricaPersistentConfiguration.h"
#import "AMAStartupParametersConfiguration.h"
#import "AMAReporterConfiguration+Internal.h"
#import "AMADatabaseFactory.h"
#import "AMADatabaseProtocol.h"
#import "AMAFallbackKeychain.h"
#import "AMAKeychain.h"
#import "AMAKeychainBridge.h"

// Keychain identifiers
// Declared without `static` keywords (e.g. extern by default) in order to be used in Sample Application
NSString *const kAMAMetricaKeychainAccessGroup = @"io.appmetrica";
NSString *const kAMAMetricaKeychainAppServiceIdentifier = @"io.appmetrica.service.application";
NSString *const kAMAMetricaKeychainVendorServiceIdentifier = @"io.appmetrica.service.vendor";
//-----

@interface AMAMetricaConfiguration ()

@property (nonatomic, strong, readonly) AMAKeychainBridge *keychainBridge;
@property (nonatomic, strong, readonly) id<AMADatabaseProtocol> database;
@property (nonatomic, strong, readonly) NSMutableDictionary *apiConfigs;

@property (nonatomic, strong, readonly) NSObject *reporterConfigurationLock;
@property (nonatomic, strong, readonly) NSObject *startupConfigurationLock;
@property (nonatomic, strong, readonly) NSObject *persistentConfigurationLock;

@property (nonatomic, strong, readwrite) AMAStartupParametersConfiguration *startup;

@end

@implementation AMAMetricaConfiguration

@synthesize startup = _startup;
@synthesize persistent = _persistent;
@synthesize appConfiguration = _appConfiguration;

+ (instancetype)sharedInstance
{
    static dispatch_once_t pred;
    static AMAMetricaConfiguration *shared = nil;
    dispatch_once(&pred, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

- (instancetype)init
{
    return [self initWithKeychainBridge:[[AMAKeychainBridge alloc] init]
                               database:AMADatabaseFactory.configurationDatabase];
}

- (instancetype)initWithKeychainBridge:(AMAKeychainBridge *)keychainBridge
                              database:(id<AMADatabaseProtocol>)database
{
    self = [super init];
    if (self != nil) {
        _keychainBridge = keychainBridge;
        
        _database = database;
        [_database.storageProvider addBackingKeys:@[
            [AMAFallbackKeychain wrappedKey:kAMADeviceIDStorageKey],
            [AMAFallbackKeychain wrappedKey:kAMADeviceIDHashStorageKey],
        ]];
        
        _inMemory = [[AMAMetricaInMemoryConfiguration alloc] init];
        _apiConfigs = [[NSMutableDictionary alloc] init];

        _reporterConfigurationLock = [[NSObject alloc] init];
        _startupConfigurationLock = [[NSObject alloc] init];
        _persistentConfigurationLock = [[NSObject alloc] init];
    }
    return self;
}

#pragma mark - Public -

- (AMAMetricaPersistentConfiguration *)persistent
{
    if (_persistent == nil) {
        @synchronized (self.persistentConfigurationLock) {
            if (_persistent == nil) {
                id<AMAKeyValueStoring> storage = self.database.storageProvider.cachingStorage;
                AMAFallbackKeychain *keychain = [self keychainStorageWithKeyValueStorage:storage];
                _persistent = [[AMAMetricaPersistentConfiguration alloc] initWithStorage:storage
                                                                                keychain:keychain
                                                                   inMemoryConfiguration:self.inMemory];
            }
        }
    }
    return _persistent;
}

- (AMAInstantFeaturesConfiguration *)instant
{
    return [AMAInstantFeaturesConfiguration sharedInstance];
}

- (AMAStartupParametersConfiguration *)startup
{
    if (_startup == nil) {
        @synchronized (self.startupConfigurationLock) {
            if (_startup == nil) {
                NSError *__block error = nil;
                id<AMAKeyValueStoring> storage =
                    [self.database.storageProvider nonPersistentStorageForKeys:[AMAStartupParametersConfiguration allKeys]
                                                                         error:&error];
                if (error != nil) {
                    AMALogError(@"Failed to load startup parameters");
                    storage = self.database.storageProvider.emptyNonPersistentStorage;
                }
                _startup = [[AMAStartupParametersConfiguration alloc] initWithStorage:storage];
            }
        }
    }
    return _startup;
}

- (AMAStartupParametersConfiguration *)startupCopy
{
    NSError *error = nil;
    id<AMAKeyValueStoring> storage = [self.database.storageProvider nonPersistentStorageForStorage:self.startup.storage
                                                                                             error:&error];
    if (error != nil) {
        AMALogAssert(@"Failed to copy startup configuration: %@", error);
        storage = self.database.storageProvider.emptyNonPersistentStorage;
    }
    return [[AMAStartupParametersConfiguration alloc] initWithStorage:storage];
}

- (void)updateStartupConfiguration:(AMAStartupParametersConfiguration *)startup
{
    @synchronized (self.startupConfigurationLock) {
        self.startup = startup;
    }
}

- (void)synchronizeStartup
{
    @synchronized (self.startupConfigurationLock) {
        NSError *__block error = nil;
        [self.database.storageProvider saveStorage:self.startup.storage error:&error];
        if (error != nil) {
            AMALogError(@"Failed to save startup parameters");
        }
    }
}

- (BOOL)persistentConfigurationCreated
{
    return _persistent != nil;
}

- (NSString *)detectedInconsistencyDescription
{
    return self.database.detectedInconsistencyDescription;
}

- (void)resetDetectedInconsistencyDescription
{
    [self.database resetDetectedInconsistencyDescription];
}

- (void)setAppConfiguration:(AMAReporterConfiguration *)appConfiguration
{
    @synchronized (self.reporterConfigurationLock) {
        AMAReporterConfiguration *validConfiguration = [self validConfigurationForConfiguration:appConfiguration];
        AMALogBacktrace(@"Update app config '%@': old: %@, new: %@, validated: %@",
                                appConfiguration.APIKey, _appConfiguration, appConfiguration, validConfiguration);
        _appConfiguration = [validConfiguration copy];
    }
}

- (AMAReporterConfiguration *)configurationForApiKey:(NSString *)apiKey
{
    AMAReporterConfiguration *configuration = nil;
    @synchronized (self.reporterConfigurationLock) {
        if ([self.appConfiguration.APIKey isEqual:apiKey]) {
            configuration = self.appConfiguration;
        }
        else {
            configuration = [self manualConfigurationForApiKey:apiKey];
        }
    }
    return configuration;
}

- (void)setConfiguration:(AMAReporterConfiguration *)configuration
{
    if (configuration == nil) {
        return;
    }
    @synchronized (self.reporterConfigurationLock) {
        AMAReporterConfiguration *validConfiguration = [self validConfigurationForConfiguration:configuration];
        if ([self.appConfiguration.APIKey isEqual:configuration.APIKey]) {
            self.appConfiguration = [validConfiguration copy];
        }
        else {
            AMALogInfo(@"Update reporter config: old: %@, new: %@, validated: %@",
                               _apiConfigs[configuration.APIKey], configuration, validConfiguration);
            _apiConfigs[configuration.APIKey] = [validConfiguration copy];
        }
    }
}

- (AMAReporterConfiguration *)appConfiguration
{
    @synchronized (self.reporterConfigurationLock) {
        if (_appConfiguration == nil) {
            AMAMutableReporterConfiguration *newConfiguration =
                [[AMAMutableReporterConfiguration alloc] initWithoutAPIKey];
            newConfiguration.maxReportsCount = kAMAAutomaticReporterDefaultMaxReportsCount;
            newConfiguration.dispatchPeriod = kAMADefaultDispatchPeriodSeconds;
            newConfiguration.sessionTimeout = kAMASessionValidIntervalInSecondsDefault;
            AMALogInfo(@"Create new empty app config: %@", newConfiguration);
            _appConfiguration = [newConfiguration copy];
        }
        return _appConfiguration;
    }
}

- (void)handleMainApiKey:(NSString *)apiKey
{
    [self.database migrateToMainApiKey:apiKey];
}

- (void)ensureMigrated
{
    [self.database ensureMigrated];
}

- (id<AMAKeyValueStoring>)UUIDOldStorage
{
    [self ensureMigrated];
    return self.database.storageProvider.cachingStorage;
}

#pragma mark - Private -

- (id<AMAKeychainStoring>)keychainStorageWithKeyValueStorage:(id<AMAKeyValueStoring>)storage
{
    AMAKeychain *appKeychain = [[AMAKeychain alloc] initWithService:kAMAMetricaKeychainAppServiceIdentifier
                                                        accessGroup:@""
                                                             bridge:self.keychainBridge];
    id<AMAKeychainStoring> keychain = [[AMAFallbackKeychain alloc] initWithStorage:storage
                                                                      mainKeychain:appKeychain
                                                                  fallbackKeychain:self.vendorKeychain];
    return keychain;
}

- (AMAKeychain *)vendorKeychain
{
    NSString *appIdentifier = [AMAPlatformDescription appIdentifierPrefix];
    if (appIdentifier.length == 0) {
        return nil;
    }

    NSString *accessGroup = [appIdentifier stringByAppendingString:kAMAMetricaKeychainAccessGroup];
    AMAKeychain *vendorKeychain = [[AMAKeychain alloc] initWithService:kAMAMetricaKeychainVendorServiceIdentifier
                                                           accessGroup:accessGroup
                                                                bridge:self.keychainBridge];
    if (vendorKeychain.isAvailable == NO) {
        return nil;
    }

    return vendorKeychain;
}

- (AMAReporterConfiguration *)manualConfigurationForApiKey:(NSString *)apiKey
{
    if (apiKey == nil) {
        return nil;
    }

    if (_apiConfigs[apiKey] == nil) {
        _apiConfigs[apiKey] = [[AMAReporterConfiguration alloc] initWithAPIKey:apiKey];
        AMALogInfo(@"Create new empty reporter config: %@", _apiConfigs[apiKey]);
    }
    return [_apiConfigs[apiKey] copy];
}

- (AMAReporterConfiguration *)validConfigurationForConfiguration:(AMAReporterConfiguration *)configuration
{
    if (configuration == nil) {
        return nil;
    }
    AMAReporterConfiguration *validConfiguration = configuration;

    if (configuration.sessionTimeout < kAMAMinSessionTimeoutInSeconds) {
        AMALogWarn(@"Can't set session timeout to %lu seconds; Minimum session timeout %lu",
                           (unsigned long)configuration.sessionTimeout, (unsigned long)kAMAMinSessionTimeoutInSeconds);
        AMAMutableReporterConfiguration *mutableConfiguration = [configuration mutableCopy];
        mutableConfiguration.sessionTimeout = kAMAMinSessionTimeoutInSeconds;
        validConfiguration = [mutableConfiguration copy];
    }

    if (configuration.maxReportsInDatabaseCount < kAMAMinValueOfMaxReportsInDatabaseCount) {
        AMALogWarn(@"Can't set max reports in database count to %lu; Minimum allowed value is %lu",
                           (unsigned long)configuration.maxReportsInDatabaseCount,
                           (unsigned long)kAMAMinValueOfMaxReportsInDatabaseCount);
        AMAMutableReporterConfiguration *mutableConfiguration = [configuration mutableCopy];
        mutableConfiguration.maxReportsInDatabaseCount = kAMAMinValueOfMaxReportsInDatabaseCount;
        validConfiguration = [mutableConfiguration copy];
    }
    else if (configuration.maxReportsInDatabaseCount > kAMAMaxValueOfMaxReportsInDatabaseCount) {
        AMALogWarn(@"Can't set max reports in database count to %lu; Maximum allowed value is %lu",
                           (unsigned long)configuration.maxReportsInDatabaseCount,
                           (unsigned long)kAMAMaxValueOfMaxReportsInDatabaseCount);
        AMAMutableReporterConfiguration *mutableConfiguration = [configuration mutableCopy];
        mutableConfiguration.maxReportsInDatabaseCount = kAMAMaxValueOfMaxReportsInDatabaseCount;
        validConfiguration = [mutableConfiguration copy];
    }

    return validConfiguration;
}

@end
