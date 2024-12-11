#import "AMACore.h"
#import <UIKit/UIKit.h>
#import <AppMetricaStorageUtils/AppMetricaStorageUtils.h>
#import "AMAMetricaPersistentConfiguration.h"
#import "AMAStorageKeys.h"
#import "AMAKeychainStoring.h"
#import "AMAPersistentTimeoutConfiguration.h"
#import "AMAAttributionModelConfiguration.h"
#import "AMAExternalAttributionConfiguration.h"
#import "AMAAppMetricaConfiguration+JSONSerializable.h"

NSString *const kAMADeviceIDStorageKey = @"AMAMetricaPersistentConfigurationDeviceIDStorageKey";
NSString *const kAMADeviceIDHashStorageKey = @"AMAMetricaPersistentConfigurationDeviceIDHashStorageKey";
static NSString *const kAMADeviceIDDefaultValue = @"";

@interface AMAMetricaPersistentConfiguration ()

@property (nonatomic, strong, readonly) id<AMAKeyValueStoring> storage;
@property (nonatomic, strong, readonly) id<AMAKeychainStoring> keychain;
@property (nonatomic, strong, readonly) AMAMetricaInMemoryConfiguration *inMemoryConfiguration;

@property (nonatomic, strong, readonly) NSObject *keychainLock;

@end

@implementation AMAMetricaPersistentConfiguration

@synthesize deviceID = _deviceID;
@synthesize deviceIDHash = _deviceIDHash;

- (instancetype)initWithStorage:(id<AMAKeyValueStoring>)storage
                       keychain:(id<AMAKeychainStoring>)keychain
          inMemoryConfiguration:(AMAMetricaInMemoryConfiguration *)inMemoryConfiguration
{
    self = [super init];
    if (self != nil) {
        _storage = storage;
        _keychain = keychain;
        _inMemoryConfiguration = inMemoryConfiguration;

        _keychainLock = [[NSObject alloc] init];
        _timeoutConfiguration = [[AMAPersistentTimeoutConfiguration alloc] initWithStorage:_storage];
    }
    return self;
}

- (NSString *)deviceID
{
    if (_deviceID.length == 0) {
        @synchronized (self.keychainLock) {
            if (_deviceID.length == 0) {
                _deviceID = [self loadDeviceID];
            }
        }
    }
    return _deviceID;
}

- (NSString *)loadDeviceID
{
    NSError *error = nil;
    NSString *storageDeviceID = [self.keychain stringValueForKey:kAMADeviceIDStorageKey error:&error];
    BOOL isValidDeviceID = storageDeviceID.length != 0 && [storageDeviceID isEqual:kAMADeviceIDDefaultValue] == NO;
    if (isValidDeviceID) {
        return storageDeviceID;
    }
    
    if (error == nil) {
        NSString *ifv = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
        BOOL isValidIFV = [AMAIdentifierValidator isValidVendorIdentifier:ifv];
        if (isValidIFV) {
            [self setDeviceID:ifv];
            return ifv;
        }
    }

    return kAMADeviceIDDefaultValue;
}

- (void)setDeviceID:(NSString *)deviceID
{
    if (deviceID != _deviceID && [deviceID isEqual:_deviceID] == NO) {
        @synchronized (self.keychainLock) {
            if (deviceID != _deviceID && [deviceID isEqual:_deviceID] == NO) {
                _deviceID = [deviceID copy];
                [self.keychain setStringValue:deviceID forKey:kAMADeviceIDStorageKey error:nil];
            }
        }
    }
}

- (NSString *)deviceIDHash
{
    if (_deviceIDHash == nil) {
        @synchronized (self.keychainLock) {
            if (_deviceIDHash == nil) {
                _deviceIDHash = [self.keychain stringValueForKey:kAMADeviceIDHashStorageKey error:nil];
            }
        }
    }
    return _deviceIDHash;
}

- (void)setDeviceIDHash:(NSString *)deviceIDHash
{
    if (deviceIDHash != _deviceIDHash && [deviceIDHash isEqual:_deviceIDHash] == NO) {
        @synchronized (self.keychainLock) {
            if (deviceIDHash != _deviceIDHash && [deviceIDHash isEqual:_deviceIDHash] == NO) {
                _deviceIDHash = [deviceIDHash copy];
                [self.keychain setStringValue:deviceIDHash forKey:kAMADeviceIDHashStorageKey error:nil];
            }
        }
    }
}

- (NSArray *)userStartupHosts
{
    // If this logic is needed here more than once, unify it with
    // `- [AMAStartupParametersConfiguration jsonArrayForKey:valueClass:onError]`
    NSArray *hosts = [self.storage jsonArrayForKey:AMAStorageStringKeyUserStartupHosts error:nil];
    for (NSString *host in hosts) {
        if ([host isKindOfClass:[NSString class]] == NO) {
            return nil;
        }
    }
    return hosts;
}

- (void)setUserStartupHosts:(NSArray *)value
{
    [self.storage saveJSONArray:value forKey:AMAStorageStringKeyUserStartupHosts error:nil];
}

#define PROPERTY_FOR_TYPE(returnType, getter, setter, key, storageGetter, storageSetter, setOnce) \
- (returnType *)getter { \
    return [self.storage storageGetter:key error:NULL]; \
} \
- (void)setter:(returnType *)value { \
    if (setOnce && self.getter != nil) return; \
    [self.storage storageSetter:value forKey:key error:NULL]; \
}

#define BOOL_PROPERTY(getter, setter, key) \
- (BOOL)getter { \
    return [self.storage boolNumberForKey:key error:NULL].boolValue; \
} \
- (void)setter:(BOOL)value { \
    [self.storage saveBoolNumber:@(value) forKey:key error:nil]; \
}

#define DATE_PROPERTY(getter, setter, key) PROPERTY_FOR_TYPE(NSDate, getter, setter, key, dateForKey, saveDate, NO)
#define LONG_PROPERTY(getter, setter, key) PROPERTY_FOR_TYPE(NSNumber, getter, setter, key, longLongNumberForKey, saveLongLongNumber, NO)

#define DATE_SET_ONCE_PROPERTY(getter, setter, key) PROPERTY_FOR_TYPE(NSDate, getter, setter, key, dateForKey, saveDate, YES)

BOOL_PROPERTY(hadFirstStartup, setHadFirstStartup, AMAStorageStringKeyHadFirstStartup);
BOOL_PROPERTY(checkedInitialAttribution, setCheckedInitialAttribution, AMAStorageStringKeyCheckedInitialAttribution);

DATE_SET_ONCE_PROPERTY(firstStartupUpdateDate, setFirstStartupUpdateDate, AMAStorageStringKeyFirstStartupUpdateDate);
DATE_PROPERTY(startupUpdatedAt, setStartupUpdatedAt, AMAStorageStringKeyStartupUpdatedAt);
DATE_PROPERTY(extensionsLastReportDate, setExtensionsLastReportDate, AMAStorageStringKeyExtensionsLastReportDate);
DATE_PROPERTY(lastPermissionsUpdateDate, setLastPermissionsUpdateDate, AMAStorageStringKeyPermissionsLastUpdateDate);
DATE_PROPERTY(registerForAttributionTime, setRegisterForAttributionTime, AMAStorageStringKeyRegisterForAttributionTime);

LONG_PROPERTY(conversionValue, setConversionValue, AMAStorageStringKeyConversionValue);

- (NSDictionary<NSString *, NSNumber *> *)eventCountsByKey
{
    return [self.storage jsonDictionaryForKey:AMAStorageStringKeyEventCountsByKey error:nil];
}

- (void)setEventCountsByKey:(NSDictionary<NSString *, NSNumber *> *)value
{
    [self.storage saveJSONDictionary:value forKey:AMAStorageStringKeyEventCountsByKey error:nil];
}

- (NSDecimalNumber *)eventSum
{
    return [AMADecimalUtils decimalNumberWithString:[self.storage stringForKey:AMAStorageStringKeyEventsSum error:nil]
                                                 or:[NSDecimalNumber zero]];
}

- (void)setEventSum:(NSDecimalNumber *)value
{
    [self.storage saveString:value.stringValue forKey:AMAStorageStringKeyEventsSum error:nil];
}

- (NSArray<NSString *> *)revenueTransactionIds
{
    NSArray *ids = [self.storage jsonArrayForKey:AMAStorageStringKeyRevenueTransactionIds error:nil];
    for (id transactionID in ids) {
        if ([transactionID isKindOfClass:NSString.class] == NO) {
            return nil;
        }
    }
    return ids;
}

- (void)setRevenueTransactionIds:(NSArray<NSString *> *)revenueTransactionIds
{
    [self.storage saveJSONArray:revenueTransactionIds forKey:AMAStorageStringKeyRevenueTransactionIds error:nil];
}

- (AMAAttributionModelConfiguration *)attributionModelConfiguration
{
    NSDictionary *json = [self.storage jsonDictionaryForKey:AMAStorageStringKeyAttributionModel error:NULL];
    return [[AMAAttributionModelConfiguration alloc] initWithJSON:json];
}

- (void)setAttributionModelConfiguration:(AMAAttributionModelConfiguration *)attributionModel
{
    [self.storage saveJSONDictionary:[attributionModel JSON] forKey:AMAStorageStringKeyAttributionModel error:NULL];
}

- (AMAExternalAttributionConfigurationMap *)externalAttributionConfigurations
{
    NSDictionary *allConfigurationsJSON =
        [self.storage jsonDictionaryForKey:AMAStorageStringKeyExternalAttributionConfiguration error:NULL];
    
    if (allConfigurationsJSON.count == 0) {
        return nil;
    }

    NSDictionary *configurations =
        [AMACollectionUtilities compactMapValuesOfDictionary:allConfigurationsJSON
                                                   withBlock:^id(AMAAttributionSource key, NSDictionary *json) {
        AMAExternalAttributionConfiguration *attribution = [[AMAExternalAttributionConfiguration alloc] initWithJSON:json];
        return attribution;
    }];
    
    return configurations;
}

- (void)setExternalAttributionConfigurations:(AMAExternalAttributionConfigurationMap *)configurations
{
    NSDictionary *allConfigurationsJSON =
        [AMACollectionUtilities compactMapValuesOfDictionary:configurations
                                                   withBlock:^id(AMAAttributionSource key, AMAExternalAttributionConfiguration *attribution) {
        return [attribution JSON];
    }];

    allConfigurationsJSON = allConfigurationsJSON.count == 0 ? nil : allConfigurationsJSON;

    [self.storage saveJSONDictionary:allConfigurationsJSON
                              forKey:AMAStorageStringKeyExternalAttributionConfiguration
                               error:NULL];
}

- (AMAAppMetricaConfiguration *)appMetricaClientConfiguration
{
    NSDictionary *json = [self.storage jsonDictionaryForKey:AMAStorageStringKeyAppMetricaClientConfiguration error:NULL];
    return [[AMAAppMetricaConfiguration alloc] initWithJSON:json];
}

- (void)setAppMetricaClientConfiguration:(AMAAppMetricaConfiguration *)appMetricaClientConfiguration
{
    [self.storage saveJSONDictionary:[appMetricaClientConfiguration JSON]
                              forKey:AMAStorageStringKeyAppMetricaClientConfiguration
                               error:NULL];
}

- (NSString *)recentMainApiKey
{
    return [self.storage stringForKey:AMAStorageStringKeyRecentMainApiKey error:NULL];
}

- (void)setRecentMainApiKey:(NSString *)recentMainApiKey
{
    [self.storage saveString:recentMainApiKey
                      forKey:AMAStorageStringKeyRecentMainApiKey
                       error:NULL];
}

@end
