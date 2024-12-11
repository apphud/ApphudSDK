
#import "AMACore.h"
#import "AMAStartupResponse.h"
#import "AMAStartupParametersConfiguration.h"
#import "AMAAttributionModelConfiguration.h"

@implementation AMAStartupResponse

- (instancetype)initWithStartupConfiguration:(AMAStartupParametersConfiguration *)configuration
{
    self = [super init];
    if (self != nil) {
        _configuration = configuration;
    }
    return self;
}

#if AMA_ALLOW_DESCRIPTIONS

- (NSString *)description
{
    NSMutableString *description = [NSMutableString stringWithFormat:@"<%@: ", super.description];
    [description appendFormat:@"self.deviceID=%@", self.deviceID];
    [description appendFormat:@", self.deviceIDHash=%@", self.deviceIDHash];
    [description appendFormat:@", self.attributionModelConfiguration=%@", self.attributionModelConfiguration];
    [description appendFormat:@", self.startupConfiguration=%@", self.configuration];
    [description appendString:@">"];
    return description;
}
#endif

@end
