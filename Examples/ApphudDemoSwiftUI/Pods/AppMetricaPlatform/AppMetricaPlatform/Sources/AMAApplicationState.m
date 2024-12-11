
#import <AppMetricaPlatform/AppMetricaPlatform.h>
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>

@interface AMAApplicationState ()

@property (nonatomic, copy, readwrite) NSString *appVersionName;
@property (nonatomic, assign, readwrite) BOOL appDebuggable;
@property (nonatomic, copy, readwrite) NSString *kitVersion;
@property (nonatomic, copy, readwrite) NSString *kitVersionName;
@property (nonatomic, assign, readwrite) NSUInteger kitBuildNumber;
@property (nonatomic, copy, readwrite) NSString *kitBuildType;
@property (nonatomic, copy, readwrite) NSString *OSVersion;
@property (nonatomic, assign, readwrite) NSInteger OSAPILevel;
@property (nonatomic, copy, readwrite) NSString *locale;
@property (nonatomic, assign, readwrite) BOOL isRooted;
@property (nonatomic, copy, readwrite) NSString *UUID;
@property (nonatomic, copy, readwrite) NSString *deviceID;
@property (nonatomic, copy, readwrite) NSString *IFV;
@property (nonatomic, copy, readwrite) NSString *IFA;
@property (nonatomic, assign, readwrite) BOOL LAT;
@property (nonatomic, copy, readwrite) NSString *appBuildNumber;

@end

@implementation AMAApplicationState

#pragma mark - Public -

- (instancetype)initWithAppVersionName:(NSString *)appVersionName
                         appDebuggable:(BOOL)appDebuggable
                            kitVersion:(NSString *)kitVersion
                        kitVersionName:(NSString *)kitVersionName
                        kitBuildNumber:(NSUInteger)kitBuildNumber
                          kitBuildType:(NSString *)kitBuildType
                             OSVersion:(NSString *)OSVersion
                            OSAPILevel:(NSInteger)OSAPILevel
                                locale:(NSString *)locale
                              isRooted:(BOOL)isRooted
                                  UUID:(NSString *)UUID
                              deviceID:(NSString *)deviceID
                                   IFV:(NSString *)IFV
                                   IFA:(NSString *)IFA
                                   LAT:(BOOL)LAT
                        appBuildNumber:(NSString *)appBuildNumber
{
    self = [super init];
    if (self) {
        _appVersionName = [appVersionName copy];
        _appDebuggable = appDebuggable;
        _kitVersion = [kitVersion copy];
        _kitVersionName = [kitVersionName copy];
        _kitBuildNumber = kitBuildNumber;
        _kitBuildType = [kitBuildType copy];
        _OSVersion = [OSVersion copy];
        _OSAPILevel = OSAPILevel;
        _locale = [locale copy];
        _isRooted = isRooted;
        _UUID = [UUID copy];
        _deviceID = [deviceID copy];
        _IFV = [IFV copy];
        _IFA = [IFA copy];
        _LAT = LAT;
        _appBuildNumber = [appBuildNumber copy];
    }
    return self;
}

- (instancetype)copyWithNewAppVersion:(NSString *)appVersion appBuildNumber:(NSString *)appBuildNumber
{
    AMAApplicationState *copy = self.copy;
    copy.appVersionName = appVersion;
    copy.appBuildNumber = appBuildNumber;

    return copy;
}

#pragma mark - Private -

- (BOOL)bothValuesAreNilOrValue:(id)value isEqualToValue:(id)anotherValue
{
    return (value == nil && anotherValue == nil) || [value isEqual:anotherValue];
}

- (void)updateStateWithDictionary:(NSDictionary<NSString *, NSString *> *)dictionary
{
    self.appVersionName = [dictionary[kAMAAppVersionNameKey] copy];
    self.appDebuggable = [dictionary[kAMAAppDebuggableKey] isEqualToString:@"1"];
    self.kitVersion = [dictionary[kAMAKitVersionKey] copy];
    self.kitVersionName = [dictionary[kAMAKitVersionNameKey] copy];
    self.kitBuildNumber = (NSUInteger)[dictionary[kAMAKitBuildNumberKey] integerValue];
    self.kitBuildType = [dictionary[kAMAKitBuildTypeKey] copy];
    self.OSVersion = [dictionary[kAMAOSVersionKey] copy];
    self.OSAPILevel = [dictionary[kAMAOSAPILevelKey] integerValue];
    self.locale = [dictionary[kAMALocaleKey] copy];
    self.isRooted = [dictionary[kAMAIsRootedKey] isEqualToString:@"1"];
    self.UUID = [dictionary[kAMAUUIDDictKey] copy];
    self.deviceID = [dictionary[kAMADeviceIDDictKey] copy];
    self.IFV = [dictionary[kAMAIFVKey] copy];
    self.IFA = [dictionary[kAMAIFAKey] copy];

    NSString *latString = dictionary[kAMALATKey];
    self.LAT = latString != nil ? [latString isEqualToString:@"1"] : (self.IFA == nil);
    
    self.appBuildNumber = [dictionary[kAMAAppBuildNumberKey] copy];
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object
{
    if ([object isKindOfClass:AMAApplicationState.class] == NO) {
        return NO;
    }
    AMAApplicationState *appState = (AMAApplicationState *)object;
    return ([self bothValuesAreNilOrValue:self.appVersionName isEqualToValue:appState.appVersionName] &&
            self.appDebuggable == appState.appDebuggable &&
            [self bothValuesAreNilOrValue:self.kitVersion isEqualToValue:appState.kitVersion] &&
            [self bothValuesAreNilOrValue:self.kitVersionName isEqualToValue:appState.kitVersionName] &&
            self.kitBuildNumber == appState.kitBuildNumber &&
            [self bothValuesAreNilOrValue:self.kitBuildType isEqualToValue:appState.kitBuildType] &&
            [self bothValuesAreNilOrValue:self.OSVersion isEqualToValue:appState.OSVersion] &&
            self.OSAPILevel == appState.OSAPILevel &&
            [self bothValuesAreNilOrValue:self.locale isEqualToValue:appState.locale] &&
            self.isRooted == appState.isRooted &&
            [self bothValuesAreNilOrValue:self.UUID isEqualToValue:appState.UUID] &&
            [self bothValuesAreNilOrValue:self.deviceID isEqualToValue:appState.deviceID] &&
            [self bothValuesAreNilOrValue:self.IFV isEqualToValue:appState.IFV] &&
            [self bothValuesAreNilOrValue:self.IFA isEqualToValue:appState.IFA] &&
            self.LAT == appState.LAT &&
            [self bothValuesAreNilOrValue:self.appBuildNumber isEqualToValue:appState.appBuildNumber]);
}

- (NSUInteger)hash
{
    NSUInteger prime = 31;
    NSUInteger result = 1;
    result = prime * result + [self.appVersionName hash];
    result = prime * result + (self.appDebuggable ? 1 : 0);
    result = prime * result + [self.kitVersion hash];
    result = prime * result + [self.kitVersionName hash];
    result = prime * result + self.kitBuildNumber;
    result = prime * result + [self.kitBuildType hash];
    result = prime * result + [self.OSVersion hash];
    result = prime * result + (NSUInteger)self.OSAPILevel;
    result = prime * result + [self.locale hash];
    result = prime * result + (self.isRooted ? 1 : 0);
    result = prime * result + [self.UUID hash];
    result = prime * result + [self.deviceID hash];
    result = prime * result + [self.IFV hash];
    result = prime * result + (self.LAT ? 1 : 0);
    result = prime * result + [self.appBuildNumber hash];
    return result;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    AMAApplicationState *copy = [[AMAApplicationState alloc] init];
    [self copyValuesTo:copy];
    return copy;
}

- (void)copyValuesTo:(AMAApplicationState *)copy
{
    copy.appVersionName = self.appVersionName;
    copy.appDebuggable = self.appDebuggable;
    copy.kitVersion = self.kitVersion;
    copy.kitVersionName = self.kitVersionName;
    copy.kitBuildNumber = self.kitBuildNumber;
    copy.kitBuildType = self.kitBuildType;
    copy.OSVersion = self.OSVersion;
    copy.OSAPILevel = self.OSAPILevel;
    copy.locale = self.locale;
    copy.isRooted = self.isRooted;
    copy.UUID = self.UUID;
    copy.deviceID = self.deviceID;
    copy.IFV = self.IFV;
    copy.IFA = self.IFA;
    copy.LAT = self.LAT;
    copy.appBuildNumber = self.appBuildNumber;
}

#pragma mark - NSMutableCopying

- (id)mutableCopyWithZone:(NSZone *)zone
{
    AMAMutableApplicationState *copy = [[AMAMutableApplicationState alloc] init];
    [self copyValuesTo:copy];
    return copy;
}

#pragma mark - AMADictionaryRepresentation

+ (instancetype)objectWithDictionaryRepresentation:(NSDictionary *)dictionary
{
    AMAApplicationState *appState = [[AMAApplicationState alloc] init];
    [appState updateStateWithDictionary:dictionary];
    return appState;
}

- (NSDictionary *)dictionaryRepresentation
{
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    dictionary[kAMAAppVersionNameKey] = self.appVersionName;
    dictionary[kAMAAppDebuggableKey] = self.appDebuggable ? @"1" : @"0";
    dictionary[kAMAKitVersionKey] = self.kitVersion;
    dictionary[kAMAKitVersionNameKey] = self.kitVersionName;
    dictionary[kAMAKitBuildNumberKey] = [@(self.kitBuildNumber) stringValue];
    dictionary[kAMAKitBuildTypeKey] = self.kitBuildType;
    dictionary[kAMAOSVersionKey] = self.OSVersion;
    dictionary[kAMAOSAPILevelKey] = [@(self.OSAPILevel) stringValue];
    dictionary[kAMALocaleKey] = self.locale;
    dictionary[kAMAIsRootedKey] = self.isRooted ? @"1" : @"0";
    dictionary[kAMAUUIDDictKey] = self.UUID;
    dictionary[kAMADeviceIDDictKey] = self.deviceID;
    dictionary[kAMAAppBuildNumberKey] = self.appBuildNumber;
    dictionary[kAMAIFVKey] = self.IFV;
    dictionary[kAMAIFAKey] = self.IFA;
    dictionary[kAMALATKey] = self.LAT ? @"1" : @"0";
    
    return [AMACollectionUtilities dictionaryByRemovingEmptyStringValuesForDictionary:dictionary];
}

@end

@implementation AMAMutableApplicationState

@dynamic appVersionName;
@dynamic appDebuggable;
@dynamic kitVersion;
@dynamic kitVersionName;
@dynamic kitBuildNumber;
@dynamic kitBuildType;
@dynamic OSVersion;
@dynamic OSAPILevel;
@dynamic locale;
@dynamic isRooted;
@dynamic UUID;
@dynamic deviceID;
@dynamic IFV;
@dynamic IFA;
@dynamic LAT;
@dynamic appBuildNumber;

@end
