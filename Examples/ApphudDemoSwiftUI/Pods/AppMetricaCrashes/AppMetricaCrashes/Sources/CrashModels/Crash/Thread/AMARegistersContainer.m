
#import "AMARegistersContainer.h"

@implementation AMARegistersContainer

- (instancetype)initWithBasic:(NSArray<AMARegister *> *)basic exception:(NSArray<AMARegister *> *)exception
{
    self = [super init];
    if (self != nil) {
        _basic = [basic copy];
        _exception = [exception copy];
    }

    return self;
}

@end
