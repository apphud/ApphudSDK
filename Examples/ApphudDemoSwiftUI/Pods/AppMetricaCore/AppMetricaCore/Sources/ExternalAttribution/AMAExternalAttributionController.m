#import "AMAExternalAttributionController.h"

#import <CommonCrypto/CommonCrypto.h>

#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>

#import "AMAExternalAttributionConfiguration.h"
#import "AMAMetricaConfiguration.h"
#import "AMAMetricaPersistentConfiguration.h"
#import "AMAStartupParametersConfiguration.h"
#import "AMATime.h"
#import "AMAReporter.h"

static NSTimeInterval const kAMAExternalAttributionDefaultCollectingInterval = AMA_DAYS * 10;

@interface AMAExternalAttributionController ()

@property (atomic, strong) AMAStartupParametersConfiguration *startupConfiguration;
@property (nonatomic, strong) AMAMetricaPersistentConfiguration *persistentConfiguration;
@property (nonatomic, strong) id<AMADateProviding> dateProvider;
@property (nonatomic, strong) AMAReporter *reporter;

@end

@implementation AMAExternalAttributionController

- (instancetype)initWithReporter:(AMAReporter *)reporter
{
    return [self initWithStartupConfiguration:[AMAMetricaConfiguration sharedInstance].startup
                      persistentConfiguration:[AMAMetricaConfiguration sharedInstance].persistent
                                 dateProvider:[[AMADateProvider alloc] init]
                                     reporter:reporter];
}

- (instancetype)initWithStartupConfiguration:(AMAStartupParametersConfiguration *)startupConfiguration
                     persistentConfiguration:(AMAMetricaPersistentConfiguration *)persistentConfiguration
                                dateProvider:(id<AMADateProviding>)dateProvider
                                    reporter:(AMAReporter *)reporter 
{
    self = [super init];
    if (self != nil) {
        _startupConfiguration = startupConfiguration;
        _persistentConfiguration = persistentConfiguration;
        _dateProvider = dateProvider;
        _reporter = reporter;
    }
    return self;
}

#pragma mark - Public -

- (void)processAttributionData:(NSDictionary *)data
                        source:(AMAAttributionSource)source
                     onFailure:(void(^)(NSError *))failure
{
    AMAExternalAttributionConfiguration *existingAttribution =
        self.persistentConfiguration.externalAttributionConfigurations[source];

    NSError *hashError = nil;
    NSString *newDataHash = [self hashForDictionary:data error:&hashError];
    
    if (hashError != nil) {
        if (failure != nil) {
            failure(hashError);
        }
        return;
    }

    if ([self shouldUpdateAttributionWithExistingAttribution:existingAttribution newDataHash:newDataHash]) {
        [self updateAttributionConfigurationWithHash:newDataHash source:source];
        [self.reporter reportExternalAttribution:data source:source onFailure:failure];
    }
}

# pragma mark - Private -

- (BOOL)shouldUpdateAttributionWithExistingAttribution:(AMAExternalAttributionConfiguration *)existingAttribution
                                           newDataHash:(NSString *)newDataHash
{
    if (existingAttribution == nil) { return YES; }
    
    NSDate *currentDate = [self.dateProvider currentDate];
    NSTimeInterval timeSinceLastUpdate = [currentDate timeIntervalSinceDate:existingAttribution.timestamp];
    BOOL isWithinCollectingInterval = timeSinceLastUpdate <= self.collectingInterval;
    
    if (isWithinCollectingInterval == NO) { return NO; }
    
    return [existingAttribution.contentsHash isEqualToString:newDataHash] == NO;
}

- (NSTimeInterval)collectingInterval
{
    NSNumber *interval = self.startupConfiguration.externalAttributionCollectingInterval;
    return interval ? [interval doubleValue] : kAMAExternalAttributionDefaultCollectingInterval;
}

- (void)updateAttributionConfigurationWithHash:(NSString *)dataHash source:(AMAAttributionSource)source
{
    NSDate *currentDate = [self.dateProvider currentDate];
    AMAExternalAttributionConfiguration *newAttribution =
        [[AMAExternalAttributionConfiguration alloc] initWithSource:source
                                                          timestamp:currentDate
                                                       contentsHash:dataHash];

    NSMutableDictionary *updatedConfigurations =
        [self.persistentConfiguration.externalAttributionConfigurations mutableCopy] ?: NSMutableDictionary.dictionary;
    updatedConfigurations[source] = newAttribution;

    self.persistentConfiguration.externalAttributionConfigurations = [updatedConfigurations copy];
}

- (NSString *)hashForDictionary:(NSDictionary *)dictionary error:(NSError **)error
{
    if ([NSJSONSerialization isValidJSONObject:dictionary] == NO) {
        [AMAErrorUtilities fillError:error withError:self.JSONError];
        return nil;
    }
    
    NSError *localError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dictionary options:0 error:&localError];
    
    if (jsonData == nil) {
        NSError *filledError = [AMAErrorUtilities errorByAddingUnderlyingError:localError toError:self.JSONError];
        [AMAErrorUtilities fillError:error withError:filledError];
        return nil;
    }
    
    return [self hashForData:jsonData];
}

- (NSError *)JSONError
{
    NSString *errorDescription = @"Failed to process external attribution data due to invalid contents. Ensure the "
                                  "data can be converted to JSON format.";
    NSError *appMetricaError =
        [AMAErrorUtilities errorWithCode:AMAAppMetricaEventErrorCodeInvalidExternalAttributionContents
                             description:errorDescription];
    return appMetricaError;
}

- (NSString *)hashForData:(NSData *)jsonData
{
    unsigned char hash[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(jsonData.bytes, (CC_LONG)jsonData.length, hash);
    NSMutableString *hashString = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
        [hashString appendFormat:@"%02x", hash[i]];
    }
    
    return [hashString copy];
}

#pragma mark - AMAStartupCompletionObserving

- (void)startupUpdateCompletedWithConfiguration:(AMAStartupParametersConfiguration *)configuration
{
    self.startupConfiguration = configuration;
}

@end
