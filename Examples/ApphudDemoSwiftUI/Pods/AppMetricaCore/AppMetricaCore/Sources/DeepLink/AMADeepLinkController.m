
#import "AMADeepLinkController.h"
#import "AMADeepLinkPayloadFactory.h"
#import "AMAReporter.h"
#import "AMAPair.h"
#import "AMAMetricaConfiguration.h"
#import "AMAStartupParametersConfiguration.h"

NSString *const kAMADLControllerUrlTypeOpen = @"open";

@interface AMADeepLinkController ()

@property (nonatomic, strong, readonly) AMAReporter *reporter;
@property (nonatomic, strong, readonly) id<AMAAsyncExecuting> executor;
@property (nonatomic, strong, readonly) NSMutableSet<NSString *> *reportedURLs;

@end

@implementation AMADeepLinkController

- (instancetype)initWithReporter:(AMAReporter *)reporter executor:(id<AMAAsyncExecuting>)executor
{
    self = [super init];
    if (self != nil) {
        _reporter = reporter;
        _executor = executor;
        _reportedURLs = [NSMutableSet set];
    }
    return self;
}

#pragma mark - Public -

- (void)reportUrl:(NSURL *)url ofType:(NSString *)type isAuto:(BOOL)isAuto
{
    [self.executor execute:^{
        NSError *error = nil;
        NSDictionary *payload =
            [AMADeepLinkPayloadFactory deepLinkPayloadForURL:url ofType:type isAuto:isAuto error:&error];
        if (error != nil) {
            AMALogWarn(@"Failed to report URL: %@", error);
        }
        else {
            NSString *urlString = url.absoluteString ?: @"";
            if ([self.reportedURLs containsObject:urlString]) {
                AMALogWarn(@"URL has already been reported: %@", urlString);
            }
            else {
                [self.reportedURLs addObject:urlString];
                [self.reporter reportOpenEvent:payload reattribution:[self isReatributionURL:url] onFailure:nil];
                AMALogInfo(@"Reported %@ URL event: '%@'", type, url);
            }
        }
    }];
}

#pragma mark - Private -

- (BOOL)isReatributionURL:(NSURL *)url
{
    BOOL result = NO;
    NSDictionary *parameters = [AMAURLUtilities HTTPGetParametersForURL:url];
    NSString *referrer = parameters[@"referrer"];
    if (referrer.length != 0) {
        NSArray *referrerComponents = [referrer componentsSeparatedByString:@"&"];
        NSArray<AMAPair *> *conditions = [[AMAMetricaConfiguration sharedInstance].startup attributionDeeplinkConditions];
        for (NSString *component in referrerComponents) {
            NSArray *keyValuePair = [component componentsSeparatedByString:@"="];
            if ([self doesKeyValuePair:keyValuePair matchReattributionConditions:conditions]) {
                result = YES;
                break;
            }
        }
    }
    return result;
}

- (BOOL)doesKeyValuePair:(NSArray *)keyValuePair matchReattributionConditions:(NSArray<AMAPair *> *)conditions
{
    if (keyValuePair.count == 0 || keyValuePair.count > 2) {
        return NO;
    }
    NSString *name = [keyValuePair[0] stringByRemovingPercentEncoding];
    NSString *value = nil;
    if (keyValuePair.count == 2) {
        value = [keyValuePair[1] stringByRemovingPercentEncoding];
    }
    if ([name isEqualToString:@"reattribution"] && [value isEqualToString:@"1"]) {
        return YES;
    }
    for (AMAPair *condition in conditions) {
        if ([name isEqualToString:condition.key]) {
            if (condition.value == nil || [condition.value isEqualToString:value]) {
                return YES;
            }
        }
    }
    return NO;
}

@end
