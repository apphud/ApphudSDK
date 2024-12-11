
#import "AMAStringEventValue.h"

@implementation AMAStringEventValue

- (instancetype)initWithValue:(NSString *)value
{
    self = [super init];
    if (self != nil) {
        _value = [value copy];
    }
    return self;
}

- (AMAEventEncryptionType)encryptionType
{
    return AMAEventEncryptionTypeNoEncryption;
}

- (BOOL)empty
{
    return self.value.length == 0;
}

- (NSData *)dataWithError:(NSError **)error
{
    return [self.value dataUsingEncoding:NSUTF8StringEncoding];
}

@end
