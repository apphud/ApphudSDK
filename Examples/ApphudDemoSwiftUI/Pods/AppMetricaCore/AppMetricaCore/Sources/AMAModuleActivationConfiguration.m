
#import "AMACore.h"

@interface AMAModuleActivationConfiguration ()

@property (nonatomic, copy, readwrite) NSString *apiKey;
@property (nonatomic, copy, nullable, readwrite) NSString *appVersion;
@property (nonatomic, copy, nullable, readwrite) NSString *appBuildNumber;

@end

@implementation AMAModuleActivationConfiguration

- (instancetype)initWithApiKey:(NSString *)apiKey
{
    return [self initWithApiKey:apiKey appVersion:nil appBuildNumber:nil];
}
- (instancetype)initWithApiKey:(NSString *)apiKey
                    appVersion:(NSString *)appVersion
                appBuildNumber:(NSString *)appBuildNumber
{
    self = [super init];
    if (self != nil) {
        _apiKey = [apiKey copy];
        _appVersion = [appVersion copy];
        _appBuildNumber = [appBuildNumber copy];
    }
    return self;
}

@end
