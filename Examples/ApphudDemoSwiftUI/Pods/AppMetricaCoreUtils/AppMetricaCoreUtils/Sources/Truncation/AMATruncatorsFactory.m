
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>

static NSUInteger const kAMAProtobufEventValueMaxSize = 230 * 1024;
static NSUInteger const kAMAProtobufEventNameMaxLength = 1000;
static NSUInteger const kAMAProtobufUserInfoMaxLength = 10000;
static NSUInteger const kAMAUserProfileIDMaxLength = 200;

@implementation AMATruncatorsFactory

+ (id<AMAStringTruncating>)eventNameTruncator
{
    return [[AMALengthStringTruncator alloc] initWithMaxLength:kAMAProtobufEventNameMaxLength];
}

+ (id<AMAStringTruncating>)eventStringValueTruncator
{
    return [[AMABytesStringTruncator alloc] initWithMaxBytesLength:kAMAProtobufEventValueMaxSize];
}

+ (id<AMADataTruncating>)eventBinaryValueTruncator
{
    return [[AMADataTruncator alloc] initWithMaxLength:kAMAProtobufEventValueMaxSize];
}

+ (id<AMADataTruncating>)fullValueTruncator
{
    return [[AMAFullDataTruncator alloc] initWithMaxLength:kAMAProtobufEventValueMaxSize];
}

+ (id<AMAStringTruncating>)extrasMigrationTruncator
{
    return [[AMALengthStringTruncator alloc] initWithMaxLength:kAMAProtobufUserInfoMaxLength];
}

+ (id<AMAStringTruncating>)profileIDTruncator
{
    return [[AMALengthStringTruncator alloc] initWithMaxLength:kAMAUserProfileIDMaxLength];
}

@end
