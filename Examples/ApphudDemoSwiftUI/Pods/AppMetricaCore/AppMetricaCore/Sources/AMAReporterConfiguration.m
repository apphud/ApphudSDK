
#import "AMACore.h"
#import "AMAReporterConfiguration+Internal.h"
#import "AMAErrorLogger.h"
#import "AMAMetricaInMemoryConfiguration.h"

@interface AMAReporterConfiguration ()

@property (nonatomic, copy, readwrite) NSString *APIKey;
@property (nonatomic, assign, readwrite) NSUInteger dispatchPeriod;
@property (nonatomic, assign, readwrite) NSUInteger maxReportsCount;
@property (nonatomic, assign, readwrite) NSUInteger sessionTimeout;
@property (nonatomic, assign, readwrite) NSUInteger maxReportsInDatabaseCount;
@property (nonatomic, assign, readwrite) BOOL logsEnabled;
@property (nonatomic, copy, readwrite) NSString *userProfileID;

@property (nonatomic, strong, nullable, readwrite) NSNumber *dataSendingEnabledState;

@end

@implementation AMAReporterConfiguration

- (instancetype)initWithoutAPIKey
{
    self = [super init];
    if (self != nil) {
        [self setDefaultValues];
    }
    return self;
}

- (instancetype)initWithAPIKey:(NSString *)APIKey
{
    self = [super init];
    if (self != nil) {
        BOOL isKeyValid = [AMAIdentifierValidator isValidUUIDKey:APIKey];
        if (isKeyValid) {
            _APIKey = [APIKey copy];
            [self setDefaultValues];
        }
        else {
            [AMAErrorLogger logInvalidApiKeyError:APIKey];
            self = nil;
        }
    }
    return self;
}

- (void)setDefaultValues
{
    _dataSendingEnabledState = nil;
    _sessionTimeout = kAMASessionValidIntervalInSecondsDefault;
    _dispatchPeriod = kAMADefaultDispatchPeriodSeconds;
    _maxReportsCount = kAMAManualReporterDefaultMaxReportsCount;
    _maxReportsInDatabaseCount = kAMAMaxReportsInDatabaseCount;
    _logsEnabled = NO;
    _userProfileID = nil;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
    AMAMutableReporterConfiguration *mutableConfiguration = [[AMAMutableReporterConfiguration alloc] initWithoutAPIKey];
    if (mutableConfiguration != nil) {
        mutableConfiguration.APIKey = self.APIKey;
        mutableConfiguration.sessionTimeout = self.sessionTimeout;
        mutableConfiguration.dispatchPeriod = self.dispatchPeriod;
        mutableConfiguration.maxReportsCount = self.maxReportsCount;
        mutableConfiguration.maxReportsInDatabaseCount = self.maxReportsInDatabaseCount;
        mutableConfiguration.logsEnabled = self.areLogsEnabled;
        mutableConfiguration.userProfileID = self.userProfileID;
        mutableConfiguration.dataSendingEnabledState = self.dataSendingEnabledState;
    }
    return mutableConfiguration;
}

- (BOOL)dataSendingEnabled
{
    return self.dataSendingEnabledState != nil ? [self.dataSendingEnabledState boolValue] : YES;
}

#if AMA_ALLOW_DESCRIPTIONS

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ apiKey=%@, sessionTimeout=%@, dispatchPeriod=%@, "
                                       "maxReportsCount=%@, maxReportsInDatabaseCount=%@, "
                                       "logs=%@, userProfileID=%@, dataSendingEnabledState=%@",
                                       [super description], self.APIKey, @(self.sessionTimeout),
                                       @(self.dispatchPeriod), @(self.maxReportsCount),
                                       @(self.maxReportsInDatabaseCount), @(self.logsEnabled), self.userProfileID,
                                       self.dataSendingEnabledState];
}

#endif

@end

@implementation AMAMutableReporterConfiguration

@dynamic dataSendingEnabled;
@dynamic sessionTimeout;
@dynamic maxReportsInDatabaseCount;
@dynamic maxReportsCount;
@dynamic logsEnabled;
@dynamic userProfileID;
@dynamic dispatchPeriod;

- (instancetype)initWithAPIKey:(NSString *)APIKey
{
    self = [super initWithAPIKey:APIKey];
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    AMAReporterConfiguration *configuration = [[AMAReporterConfiguration alloc] initWithoutAPIKey];
    if (configuration != nil) {
        configuration.APIKey = self.APIKey;
        configuration.sessionTimeout = self.sessionTimeout;
        configuration.dispatchPeriod = self.dispatchPeriod;
        configuration.maxReportsCount = self.maxReportsCount;
        configuration.maxReportsInDatabaseCount = self.maxReportsInDatabaseCount;
        configuration.logsEnabled = self.areLogsEnabled;
        configuration.userProfileID = self.userProfileID;
        configuration.dataSendingEnabledState = self.dataSendingEnabledState;
    }
    return configuration;
}

- (void)setDataSendingEnabled:(BOOL)enabled
{
    self.dataSendingEnabledState = @(enabled);
}

@end
