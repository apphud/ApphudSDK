
#import <AppMetricaStorageUtils/AppMetricaStorageUtils.h>
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>
#import "AMAStartupParametersConfiguration.h"
#import "AMAStorageKeys.h"
#import "AMAPair.h"
#import "AMAAttributionSerializer.h"

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

#define ARRAY_PROPERTY(getter, setter, key, valueType) \
- (NSArray *)getter { \
    return [self jsonArrayForKey:key valueClass:valueType]; \
} \
- (void)setter:(NSArray *)value { \
    [self.storage saveJSONArray:value forKey:key error:NULL]; \
}

#define DATE_PROPERTY(getter, setter, key) PROPERTY_FOR_TYPE(NSDate, getter, setter, key, dateForKey, saveDate, NO)
#define STRING_PROPERTY(getter, setter, key) PROPERTY_FOR_TYPE(NSString, getter, setter, key, stringForKey, saveString, NO)
#define NS_NUMBER_BOOL_PROPERTY(getter, setter, key) PROPERTY_FOR_TYPE(NSNumber, getter, setter, key, boolNumberForKey, saveBoolNumber, NO)
#define NS_NUMBER_DOUBLE_PROPERTY(getter, setter, key) PROPERTY_FOR_TYPE(NSNumber, getter, setter, key, doubleNumberForKey, saveDoubleNumber, NO)
#define NS_NUMBER_LONG_PROPERTY(getter, setter, key) PROPERTY_FOR_TYPE(NSNumber, getter, setter, key, longLongNumberForKey, saveLongLongNumber, NO)

#define STRING_SET_ONCE_PROPERTY(getter, setter, key) PROPERTY_FOR_TYPE(NSString, getter, setter, key, stringForKey, saveString, YES)

@implementation AMAStartupParametersConfiguration

- (instancetype)initWithStorage:(id<AMAKeyValueStoring>)storage
{
    self = [super init];
    if (self != nil) {
        _storage = storage;
    }
    return self;
}

+ (NSArray<NSString *> *)allKeys
{
    return @[
        AMAStorageStringKeyASATokenEndReportingInterval,
        AMAStorageStringKeyASATokenFirstDelay,
        AMAStorageStringKeyASATokenReportingInterval,
        AMAStorageStringKeyAttributionDeeplinkConditions,
        AMAStorageStringKeyExtensionsReportingEnabled,
        AMAStorageStringKeyExtensionsReportingInterval,
        AMAStorageStringKeyExtensionsReportingLaunchDelay,
        AMAStorageStringKeyInitialCountry,
        AMAStorageStringKeyLibsDynamicCrashHookEnabled,
        AMAStorageStringKeyLocationAccurateDesiredAccuracy,
        AMAStorageStringKeyLocationAccurateDistanceFilter,
        AMAStorageStringKeyLocationCollectingEnabled,
        AMAStorageStringKeyLocationDefaultDesiredAccuracy,
        AMAStorageStringKeyLocationDefaultDistanceFilter,
        AMAStorageStringKeyLocationHosts,
        AMAStorageStringKeyLocationMaxAgeToForceFlush,
        AMAStorageStringKeyLocationMaxRecordsCountInBatch,
        AMAStorageStringKeyLocationMaxRecordsToStoreLocally,
        AMAStorageStringKeyLocationMinUpdateDistance,
        AMAStorageStringKeyLocationMinUpdateInterval,
        AMAStorageStringKeyLocationPausesLocationUpdatesAutomatically,
        AMAStorageStringKeyLocationRecordsCountToForceFlush,
        AMAStorageStringKeyLocationVisitsCollectingEnabled,
        AMAStorageStringKeyPermissionsEnabled,
        AMAStorageStringKeyPermissionsForceSendInterval,
        AMAStorageStringKeyPermissionsList,
        AMAStorageStringKeyRedirectHost,
        AMAStorageStringKeyReportHosts,
        AMAStorageStringKeyRetryPolicyExponentialMultiplier,
        AMAStorageStringKeyRetryPolicyMaxIntervalSeconds,
        AMAStorageStringKeyServerTimeOffset,
        AMAStorageStringKeyStartupHosts,
        AMAStorageStringKeyStartupPermissions,
        AMAStorageStringKeyStatSendingDisabledReportingInterval,
        AMAStorageStringKeySDKsCustomHosts,
        AMAStorageStringKeyStartupUpdateInterval,
        AMAStorageStringKeyExtendedParameters,
        AMAStorageStringKeyAppleTrackingHosts,
        AMAStorageStringKeyApplePrivacyResendPeriod,
        AMAStorageStringKeyAppleRetryPeriods,
        AMAStorageStringKeyExternalAttributionCollectingIntervalSeconds,
    ];
}

#pragma mark - Generated Properties

NS_NUMBER_BOOL_PROPERTY(locationPausesLocationUpdatesAutomatically,
                        setLocationPausesLocationUpdatesAutomatically,
                        AMAStorageStringKeyLocationPausesLocationUpdatesAutomatically);

NS_NUMBER_LONG_PROPERTY(retryPolicyMaxIntervalSeconds,
                        setRetryPolicyMaxIntervalSeconds, AMAStorageStringKeyRetryPolicyMaxIntervalSeconds);
NS_NUMBER_LONG_PROPERTY(retryPolicyExponentialMultiplier,
                        setRetryPolicyExponentialMultiplier, AMAStorageStringKeyRetryPolicyExponentialMultiplier);
NS_NUMBER_LONG_PROPERTY(permissionsCollectingForceSendInterval,
                        setPermissionsCollectingForceSendInterval, AMAStorageStringKeyPermissionsForceSendInterval);
NS_NUMBER_LONG_PROPERTY(locationRecordsCountToForceFlush,
                        setLocationRecordsCountToForceFlush, AMAStorageStringKeyLocationRecordsCountToForceFlush);
NS_NUMBER_LONG_PROPERTY(locationMaxRecordsCountInBatch,
                        setLocationMaxRecordsCountInBatch, AMAStorageStringKeyLocationMaxRecordsCountInBatch);
NS_NUMBER_LONG_PROPERTY(locationMaxRecordsToStoreLocally,
                        setLocationMaxRecordsToStoreLocally, AMAStorageStringKeyLocationMaxRecordsToStoreLocally);
NS_NUMBER_LONG_PROPERTY(applePrivacyResendPeriod,
                        setApplePrivacyResendPeriod, AMAStorageStringKeyApplePrivacyResendPeriod);

NS_NUMBER_DOUBLE_PROPERTY(externalAttributionCollectingInterval,
                          setExternalAttributionCollectingInterval,
                          AMAStorageStringKeyExternalAttributionCollectingIntervalSeconds);
NS_NUMBER_DOUBLE_PROPERTY(startupUpdateInterval,
                          setStartupUpdateInterval, AMAStorageStringKeyStartupUpdateInterval);
NS_NUMBER_DOUBLE_PROPERTY(serverTimeOffset,
                          setServerTimeOffset, AMAStorageStringKeyServerTimeOffset);
NS_NUMBER_DOUBLE_PROPERTY(statSendingDisabledReportingInterval,
                          setStatSendingDisabledReportingInterval, 
                          AMAStorageStringKeyStatSendingDisabledReportingInterval);
NS_NUMBER_DOUBLE_PROPERTY(extensionsCollectingInterval,
                          setExtensionsCollectingInterval, AMAStorageStringKeyExtensionsReportingInterval);
NS_NUMBER_DOUBLE_PROPERTY(extensionsCollectingLaunchDelay,
                          setExtensionsCollectingLaunchDelay, AMAStorageStringKeyExtensionsReportingLaunchDelay);
NS_NUMBER_DOUBLE_PROPERTY(locationMinUpdateInterval,
                          setLocationMinUpdateInterval, AMAStorageStringKeyLocationMinUpdateInterval);
NS_NUMBER_DOUBLE_PROPERTY(locationMinUpdateDistance,
                          setLocationMinUpdateDistance, AMAStorageStringKeyLocationMinUpdateDistance);
NS_NUMBER_DOUBLE_PROPERTY(locationMaxAgeToForceFlush,
                          setLocationMaxAgeToForceFlush, AMAStorageStringKeyLocationMaxAgeToForceFlush);
NS_NUMBER_DOUBLE_PROPERTY(locationDefaultDesiredAccuracy,
                          setLocationDefaultDesiredAccuracy, AMAStorageStringKeyLocationDefaultDesiredAccuracy);
NS_NUMBER_DOUBLE_PROPERTY(locationDefaultDistanceFilter,
                          setLocationDefaultDistanceFilter, AMAStorageStringKeyLocationDefaultDistanceFilter);
NS_NUMBER_DOUBLE_PROPERTY(locationAccurateDesiredAccuracy,
                          setLocationAccurateDesiredAccuracy, AMAStorageStringKeyLocationAccurateDesiredAccuracy);
NS_NUMBER_DOUBLE_PROPERTY(locationAccurateDistanceFilter,
                          setLocationAccurateDistanceFilter, AMAStorageStringKeyLocationAccurateDistanceFilter);
NS_NUMBER_DOUBLE_PROPERTY(ASATokenFirstDelay,
                          setASATokenFirstDelay, AMAStorageStringKeyASATokenFirstDelay);
NS_NUMBER_DOUBLE_PROPERTY(ASATokenReportingInterval,
                          setASATokenReportingInterval, AMAStorageStringKeyASATokenReportingInterval);
NS_NUMBER_DOUBLE_PROPERTY(ASATokenEndReportingInterval,
                          setASATokenEndReportingInterval, AMAStorageStringKeyASATokenEndReportingInterval);

STRING_SET_ONCE_PROPERTY(initialCountry,
                         setInitialCountry, AMAStorageStringKeyInitialCountry);
STRING_PROPERTY(permissionsString,
                setPermissionsString, AMAStorageStringKeyStartupPermissions);
STRING_PROPERTY(redirectHost,
                setRedirectHost, AMAStorageStringKeyRedirectHost);

ARRAY_PROPERTY(startupHosts,
               setStartupHosts, AMAStorageStringKeyStartupHosts, [NSString class]);
ARRAY_PROPERTY(reportHosts,
               setReportHosts, AMAStorageStringKeyReportHosts, [NSString class]);
ARRAY_PROPERTY(permissionsCollectingList,
               setPermissionsCollectingList, AMAStorageStringKeyPermissionsList, [NSString class]);
ARRAY_PROPERTY(locationHosts,
               setLocationHosts, AMAStorageStringKeyLocationHosts, [NSString class]);
ARRAY_PROPERTY(appleTrackingHosts,
               setAppleTrackingHosts, AMAStorageStringKeyAppleTrackingHosts, [NSString class]);
ARRAY_PROPERTY(applePrivacyRetryPeriod,
               setApplePrivacyRetryPeriod, AMAStorageStringKeyAppleRetryPeriods, [NSNumber class]);

BOOL_PROPERTY(permissionsCollectingEnabled,
              setPermissionsCollectingEnabled, AMAStorageStringKeyPermissionsEnabled);
BOOL_PROPERTY(extensionsCollectingEnabled,
              setExtensionsCollectingEnabled, AMAStorageStringKeyExtensionsReportingEnabled);
BOOL_PROPERTY(locationCollectingEnabled,
              setLocationCollectingEnabled, AMAStorageStringKeyLocationCollectingEnabled);
BOOL_PROPERTY(locationVisitsCollectingEnabled,
              setLocationVisitsCollectingEnabled, AMAStorageStringKeyLocationVisitsCollectingEnabled);

#pragma mark - Custom Processing Properties

- (NSArray<AMAPair *> *)attributionDeeplinkConditions
{
    NSArray *jsonArray = [self jsonArrayForKey:AMAStorageStringKeyAttributionDeeplinkConditions
                                    valueClass:[NSDictionary class]];
    return [AMAAttributionSerializer fromJsonArray:jsonArray];
}

- (void)setAttributionDeeplinkConditions:(NSArray<AMAPair *> *)value
{
    NSArray *jsonArray = [AMAAttributionSerializer toJsonArray:value];
    [self.storage saveJSONArray:jsonArray forKey:AMAStorageStringKeyAttributionDeeplinkConditions error:NULL];
}

- (NSDictionary<NSString *,NSArray<NSString *> *> *)SDKsCustomHosts
{
    __auto_type validator = ^BOOL(NSArray<NSString *> *obj) {
        return [obj indexOfObjectPassingTest:^BOOL(NSString *obj, NSUInteger idx, BOOL *stop) {
            return *stop = [obj isKindOfClass:NSString.class] == NO;
        }] == NSNotFound;
    };
    
    return [self jsonDictionaryForKey:AMAStorageStringKeySDKsCustomHosts
                           valueClass:NSArray.class
              valueStructureValidator:validator];
}

- (void)setSDKsCustomHosts:(NSDictionary<NSString *,NSArray<NSString *> *> *)value
{
    [self.storage saveJSONDictionary:value
                              forKey:AMAStorageStringKeySDKsCustomHosts
                               error:NULL];
}

- (NSDictionary<NSString *,NSString *> *)extendedParameters
{
    __auto_type validator = ^BOOL(NSString *obj) {
        return YES;
    };
    
    return [self jsonDictionaryForKey:AMAStorageStringKeyExtendedParameters
                           valueClass:NSString.class
              valueStructureValidator:validator];
}

- (void)setExtendedParameters:(NSDictionary<NSString *,NSString *> *)extendedParameters
{
    [self.storage saveJSONDictionary:extendedParameters
                              forKey:AMAStorageStringKeyExtendedParameters
                               error:NULL];
}

#pragma mark - Helpers

- (NSDictionary *)jsonDictionaryForKey:(NSString *)key
                            valueClass:(Class)valueClass
               valueStructureValidator:(BOOL (^)(id))validator
{
    NSDictionary *dictionary = [self.storage jsonDictionaryForKey:key error:NULL];
    BOOL isValid = [AMAValidationUtilities validateJSONDictionary:dictionary
                                                       valueClass:valueClass
                                          valueStructureValidator:validator];
    
    if (isValid == NO) {
        return nil;
    }
    return dictionary;
}

- (NSArray *)jsonArrayForKey:(NSString *)key
                  valueClass:(Class)valueClass
{
    NSArray *array = [self.storage jsonArrayForKey:key error:NULL];
    BOOL isValid = [AMAValidationUtilities validateJSONArray:array
                                                  valueClass:valueClass];
    
    if (isValid == NO) {
        return nil;
    }
    return array;
}

#if AMA_ALLOW_DESCRIPTIONS

- (NSString *)description
{
    NSMutableString *description = [NSMutableString stringWithFormat:@"<%@: ", super.description];
    [description appendFormat:@", self.redirectHost=%@", self.redirectHost];
    [description appendFormat:@", self.serverTimeOffset=%@", self.serverTimeOffset];
    [description appendFormat:@", self.startupHosts=%@", self.startupHosts];
    [description appendFormat:@", self.reportHosts=%@", self.reportHosts];
    [description appendFormat:@", self.initialCountry=%@", self.initialCountry];
    [description appendFormat:@", self.statSendingDisabledReportingInterval=%@", self.statSendingDisabledReportingInterval];
    [description appendFormat:@", self.permissionsString=%@", self.permissionsString];
    [description appendFormat:@", self.extensionsCollectingEnabled=%@", self.extensionsCollectingEnabled ? @"YES": @"NO"];
    [description appendFormat:@", self.extensionsCollectingInterval=%@", self.extensionsCollectingInterval];
    [description appendFormat:@", self.extensionsCollectingLaunchDelay=%@", self.extensionsCollectingLaunchDelay];
    [description appendFormat:@", self.locationCollectingEnabled=%@", self.locationCollectingEnabled ? @"YES": @"NO"];
    [description appendFormat:@", self.locationHosts=%@", self.locationHosts];
    [description appendFormat:@", self.locationMinUpdateInterval=%@", self.locationMinUpdateInterval];
    [description appendFormat:@", self.locationMinUpdateDistance=%@", self.locationMinUpdateDistance];
    [description appendFormat:@", self.locationRecordsCountToForceFlush=%@", self.locationRecordsCountToForceFlush];
    [description appendFormat:@", self.locationMaxRecordsCountInBatch=%@", self.locationMaxRecordsCountInBatch];
    [description appendFormat:@", self.locationMaxAgeToForceFlush=%@", self.locationMaxAgeToForceFlush];
    [description appendFormat:@", self.locationMaxRecordsToStoreLocally=%@", self.locationMaxRecordsToStoreLocally];
    [description appendFormat:@", self.extendedParameters=%@", self.extendedParameters];
    [description appendString:@">"];
    return description;
}
#endif

@end
