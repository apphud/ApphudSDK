
#import <AppMetricaEncodingUtils/AppMetricaEncodingUtils.h>

NSString *const kAMARSAKeyTagReporter = @"AMARSAKeyTagReporter";
NSString *const kAMARSAKeyTagUIS = @"AMARSAKeyTagUIS";

@implementation AMARSAKey

- (instancetype)initWithData:(NSData *)data keyType:(AMARSAKeyType)keyType uniqueTag:(NSString *)uniqueTag
{
    self = [super init];
    if (self != nil) {
        _data = [data copy];
        _keyType = keyType;
        _uniqueTag = [uniqueTag copy];
    }
    return self;
}

- (BOOL)isEqual:(AMARSAKey *)object
{
    if (self == object) {
        return YES;
    }
    if ([object isMemberOfClass:[self class]] == NO) {
        return NO;
    }
    BOOL isEqual = YES;
    isEqual = isEqual && (self.data == object.data || [self.data isEqual:object.data]);
    isEqual = isEqual && (self.keyType == object.keyType);
    isEqual = isEqual && (self.uniqueTag == object.uniqueTag || [self.uniqueTag isEqual:object.uniqueTag]);
    return isEqual;
}

- (NSUInteger)hash
{
    NSUInteger result = [self.data hash];
    result = result * 1993 + (NSUInteger)self.keyType;
    result = result * 1993 + [self.uniqueTag hash];
    return result;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

@end
