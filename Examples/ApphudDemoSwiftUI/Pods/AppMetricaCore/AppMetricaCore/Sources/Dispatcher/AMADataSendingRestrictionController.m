
#import "AMACore.h"
#import "AMADataSendingRestrictionController.h"
#import "AMAMetricaInMemoryConfiguration.h"

typedef BOOL(^kAMARestrictionMatchBlock)(NSString *apiKey, AMADataSendingRestriction restriction);

@interface AMADataSendingRestrictionController ()

@property (nonatomic, copy) NSString *mainApiKey;
@property (nonatomic, assign) AMADataSendingRestriction mainRestriction;
@property (nonatomic, strong, readonly) NSMutableDictionary<NSString *, NSNumber *> *reporterRestrictions;

@end

@implementation AMADataSendingRestrictionController

- (instancetype)init
{
    self = [super init];
    if (self != nil) {
        _mainRestriction = AMADataSendingRestrictionNotActivated;
        _reporterRestrictions = [NSMutableDictionary dictionary];
    }
    return self;
}

#pragma mark - Public -

+ (instancetype)sharedInstance
{
    static AMADataSendingRestrictionController *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[AMADataSendingRestrictionController alloc] init];
    });
    return instance;
}

- (void)setMainApiKeyRestriction:(AMADataSendingRestriction)restriction
{
    @synchronized (self) {
        if ([self shouldUpdateRestriction:self.mainRestriction withNewRestriction:restriction]) {
            AMALogInfo(@"Set statistic restriction to '%lu' for main apiKey",
                       (unsigned long)restriction);
            self.mainRestriction = restriction;
        }
    }
}

- (BOOL)shouldEnableLocationSending
{
    BOOL shouldEnable = [self shouldEnableGenericRequestsSending];
    [self logResult:shouldEnable forAction:@"enable location sending"];
    return shouldEnable;
}

- (BOOL)shouldReportToApiKey:(NSString *)apiKey
{
    if (apiKey == nil) {
        return NO;
    }
    @synchronized (self) {
        BOOL shouldReport = YES;
        AMADataSendingRestriction apiKeyRestriction =
            (AMADataSendingRestriction)[self.reporterRestrictions[apiKey] unsignedIntegerValue];

        if (self.mainRestriction == AMADataSendingRestrictionForbidden) {
            shouldReport = NO;
        }
        else {
            shouldReport = shouldReport && apiKeyRestriction != AMADataSendingRestrictionForbidden;
            shouldReport = shouldReport && [self anyIsActivated];

            if (shouldReport && [apiKey isEqualToString:kAMAMetricaLibraryApiKey]) {
                shouldReport = [self anyOtherIsAllowedOrUndefinedForApiKey:kAMAMetricaLibraryApiKey];
            }
        }
        [self logResult:shouldReport forAction:@"report"];
        return shouldReport;
    }
}

- (AMADataSendingRestriction)restrictionForApiKey:(NSString *)apiKey
{
    if (apiKey == nil) {
        return AMADataSendingRestrictionNotActivated;
    }
    @synchronized (self) {
        return [apiKey isEqualToString:self.mainApiKey]
            ? self.mainRestriction
            : (AMADataSendingRestriction)[self.reporterRestrictions[apiKey] unsignedIntegerValue];
    }
}

- (void)setReporterRestriction:(AMADataSendingRestriction)restriction forApiKey:(NSString *)apiKey
{
    if (apiKey == nil) {
        return;
    }
    @synchronized (self) {
        BOOL shouldUpdate = [self shouldUpdateRestriction:[self.reporterRestrictions[apiKey] unsignedIntegerValue]
                                       withNewRestriction:restriction];
        if (shouldUpdate) {
            AMALogInfo(@"Set statistic restriction to '%lu' for apiKey %@",
                       (unsigned long)restriction, apiKey);
            self.reporterRestrictions[apiKey] = @(restriction);
        }
    }
}

#pragma mark - Private -

- (BOOL)shouldUpdateRestriction:(AMADataSendingRestriction)restriction
             withNewRestriction:(AMADataSendingRestriction)newRestriction
{
    return restriction == AMADataSendingRestrictionNotActivated
            || newRestriction != AMADataSendingRestrictionUndefined;
}


- (BOOL)allRestrictionsMatch:(kAMARestrictionMatchBlock)matcher
{
    BOOL __block result = matcher(nil, self.mainRestriction);
    if (result) {
        [self.reporterRestrictions enumerateKeysAndObjectsUsingBlock:^(NSString *apiKey, NSNumber *flag, BOOL *stop) {
            AMADataSendingRestriction restriction = (AMADataSendingRestriction)[flag unsignedIntegerValue];
            if (matcher(apiKey, restriction) == NO) {
                result = NO;
                *stop = YES;
            }
        }];
    }
    return result;
}

- (BOOL)anyOtherIsAllowedOrUndefinedForApiKey:(NSString *)apiKey
{
    BOOL invertedStatement =
        [self allRestrictionsMatch:^BOOL(NSString *restrictionApiKey, AMADataSendingRestriction restriction) {
            if ([restrictionApiKey isEqualToString:apiKey]) {
                return YES;
            }
            return restriction != AMADataSendingRestrictionAllowed
                && restriction != AMADataSendingRestrictionUndefined;
        }];
    return invertedStatement == NO;
}

- (BOOL)anyIsActivated
{
    BOOL invertedStatement = [self allRestrictionsMatch:^BOOL(NSString *apiKey, AMADataSendingRestriction restriction) {
        return restriction == AMADataSendingRestrictionNotActivated;
    }];
    return invertedStatement == NO;
}

- (BOOL)allAreNotForbidden
{
    return [self allRestrictionsMatch:^BOOL(NSString *apiKey, AMADataSendingRestriction restriction) {
        return restriction != AMADataSendingRestrictionForbidden;
    }];
}

- (void)logResult:(BOOL)result forAction:(NSString *)action
{
    AMALogInfo(@"Should %@: %@ (main: %lu, reporters: %@)",
               action, result ? @"YES": @"NO", (unsigned long)self.mainRestriction, self.reporterRestrictions);
}

- (BOOL)shouldEnableGenericRequestsSending
{
    @synchronized (self) {
        BOOL __block shouldEnable = YES;
        if (self.mainRestriction != AMADataSendingRestrictionNotActivated) {
            shouldEnable = shouldEnable && self.mainRestriction != AMADataSendingRestrictionForbidden;
        }
        else {
            shouldEnable = shouldEnable && [self allAreNotForbidden];
            shouldEnable = shouldEnable && [self anyIsActivated];
        }
        return shouldEnable;
    }
}

@end
