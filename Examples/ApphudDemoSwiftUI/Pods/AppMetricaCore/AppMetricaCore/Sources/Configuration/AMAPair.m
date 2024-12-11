
#import "AMAPair.h"

@implementation AMAPair

- (instancetype)initWithKey:(NSString *)key value:(NSString *)value
{
    self = [super init];
    if (self != nil) {
        _key = key;
        _value = value;
    }
    return self;
}

@end
