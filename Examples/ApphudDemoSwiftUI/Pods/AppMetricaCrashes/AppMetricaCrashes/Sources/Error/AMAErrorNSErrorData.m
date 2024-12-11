
#import "AMAErrorNSErrorData.h"

@implementation AMAErrorNSErrorData

- (instancetype)initWithDomain:(NSString *)domain code:(NSInteger)code
{
    self = [super init];
    if (self != nil) {
        _domain = [domain copy];
        _code = code;
    }
    return self;
}

@end
