
#import "AMAAppMetrica.h"
#import "AMASharedReporterProvider.h"

@interface AMASharedReporterProvider ()

@property (nonatomic, copy, readonly) NSString *apiKey;

@end

@implementation AMASharedReporterProvider

- (instancetype)initWithApiKey:(NSString *)apiKey
{
    self = [super init];
    if (self != nil) {
        _apiKey = [apiKey copy];
    }
    return self;
}

- (id<AMAAppMetricaReporting>)reporter
{
    return [AMAAppMetrica reporterForAPIKey:self.apiKey];
}

@end
